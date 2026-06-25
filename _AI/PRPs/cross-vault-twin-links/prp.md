# PRP: cross-vault-twin-links

**Goal** — A Python script that validates and repairs bidirectional `twins:` links between notes across multiple Obsidian vaults.

**Why** — Notes in different vaults can be intellectually equivalent ("twins"). Without automated validation, links drift: one side declares the relationship but the other doesn't reciprocate, or a file moves and the URL goes stale.

**Success criteria**
- Running `python twin_links.py` scans all Obsidian-registered vaults, finds all notes with a `twins:` frontmatter field, adds any missing reciprocal links, and prints a report of broken links with filename-match candidates.
- Running with `--dry-run` prints what would change without modifying any files.
- All tests pass.

---

## Context

**Key files**
- `twin_links.py` — new script (create)
- `twin_links_test.py` — new test file (create)
- `~/Library/Application Support/obsidian/obsidian.json` — Obsidian's vault registry (read-only)
- `_AI/PRPs/cross-vault-twin-links/DECISIONS.md` — all design decisions for this feature
- `_AI/CODEX.md` — coding conventions to follow

**Twin URL format**
```
obsidian://open?vault=<vault-name>&file=<url-encoded-path-relative-to-vault-root>
```
Example: `obsidian://open?vault=permaculture-projects&file=projects%2Fsome-note.md`

The `file` parameter is the path relative to the vault root, URL-encoded. The `.md` extension may or may not be present — the script must handle both.

---

## Architecture notes

Follow CODEX: deep modules (simple interface, substantial hidden behaviour), flat file structure, fail loudly, no silent error swallowing. One function per concern. No external dependencies beyond stdlib — `json`, `pathlib`, `urllib.parse`, `yaml` (PyYAML, already common; fall back to a minimal frontmatter parser if unavailable).

**Frontmatter handling** — Use PyYAML to parse YAML frontmatter delimited by `---`. If a note has no frontmatter or no `twins:` key, skip it silently. The `twins:` value must always be treated as a list (guard against a scalar value written by hand).

**Writing back** — When adding a reciprocal, preserve the rest of the note exactly. Read the file, parse frontmatter, append to `twins:`, re-serialise frontmatter, write back. Do not reformat unrelated frontmatter keys.

**`obsidian.json` structure** — vaults are stored under a top-level `vaults` key as an object keyed by an opaque ID. Each entry has a `path` field (absolute) and optionally a `display` or `id` field. The vault name as used in `obsidian://` URLs matches the directory basename of `path`, not any display name. Verify this assumption in the implementation.

---

## Implementation blueprint

1. **Write tests first** — create `twin_links_test.py` with pytest covering:
   - `parse_twin_url`: valid URL → correct `(vault_name, rel_path)`; malformed URL → raises `ValueError`
   - `build_obsidian_url`: round-trips with `parse_twin_url`
   - `has_reciprocal`: returns `True` when origin URL is present in target's `twins:`, `False` otherwise
   - `find_candidates`: returns matching filenames from a mocked vault tree
   - Frontmatter read/write round-trip: adding a twin preserves existing content

2. **Create `twin_links.py`** with these functions in order:

   ```
   load_vaults() -> dict[str, Path]
   ```
   Read `~/Library/Application Support/obsidian/obsidian.json`. Return `{vault_name: absolute_path}`. Raise `FileNotFoundError` with a clear message if the config is absent. Derive vault name as `Path(entry["path"]).name`.

   ```
   scan_vaults(vaults: dict[str, Path]) -> Iterator[tuple[Path, list[str]]]
   ```
   Walk every `.md` file in every vault. For each file, parse frontmatter; if `twins:` key exists and is non-empty, yield `(file_path, twins_list)`. Skip files that fail to parse (warn to stderr).

   ```
   parse_twin_url(url: str) -> tuple[str, str]
   ```
   Parse an `obsidian://open?vault=X&file=Y` URL. Return `(vault_name, rel_path)` where `rel_path` is URL-decoded. Raise `ValueError` for malformed URLs.

   ```
   resolve_twin(vault_name: str, rel_path: str, vaults: dict[str, Path]) -> Path | None
   ```
   Return the absolute path to the twin note. Try the path as-is, then with `.md` appended if not already present. Return `None` if the vault is unknown; raise `FileNotFoundError` if the vault exists but the file doesn't (caller handles this as a broken link).

   ```
   find_candidates(vault_path: Path, filename: str) -> list[Path]
   ```
   Walk `vault_path` recursively; return all `.md` files whose stem matches `filename` (case-insensitive, ignoring extension).

   ```
   build_obsidian_url(vault_name: str, note_path: Path, vault_root: Path) -> str
   ```
   Construct `obsidian://open?vault=<name>&file=<encoded-rel-path>`. `rel_path` is `note_path` relative to `vault_root`, with path separators as `/`.

   ```
   has_reciprocal(twin_path: Path, origin_url: str) -> bool
   ```
   Parse frontmatter of `twin_path`; return `True` if `origin_url` appears in its `twins:` list.

   ```
   read_frontmatter(path: Path) -> tuple[dict, str]
   ```
   Return `(frontmatter_dict, body)` where `body` is everything after the closing `---`. Raises `ValueError` if no frontmatter block found.

   ```
   write_frontmatter(path: Path, fm: dict, body: str, dry_run: bool) -> None
   ```
   Serialise `fm` back to YAML, reconstruct the file as `---\n<yaml>---\n<body>`, write unless `dry_run`.

   ```
   add_reciprocal(twin_path: Path, origin_url: str, dry_run: bool) -> None
   ```
   Read frontmatter, append `origin_url` to `twins:` (create the key if absent), write back via `write_frontmatter`.

   ```
   main() -> None
   ```
   Parse `--dry-run` flag from `sys.argv`. Call `load_vaults()`. Iterate `scan_vaults()`. For each `(note_path, twins)`:
   - For each twin URL, call `parse_twin_url` → `resolve_twin`:
     - If vault unknown: print `[BROKEN] <note> → unknown vault "<name>"`
     - If file not found: call `find_candidates`; print `[BROKEN] <note> → <url>` with candidates listed
     - If file found and no reciprocal: call `add_reciprocal`; print `[FIXED] added reciprocal in <twin>`
     - If file found and reciprocal exists: silent (no output)
   - Print summary line: `N fixed, M broken` at the end.

3. **Make the script executable**
   Add shebang `#!/usr/bin/env python3` and set `chmod +x`.

---

## Validation gates

Run in order; fix failures before moving on.

```bash
# 1. Tests pass
pytest twin_links_test.py -v

# 2. Dry-run against real vaults (no writes, no crash)
python twin_links.py --dry-run

# 3. Smoke test: manually add a twins: entry in one vault note pointing
#    to a note in another vault (no reciprocal). Run the script. Confirm
#    the reciprocal was written. Run again — confirm it is idempotent
#    (no duplicate entries, output shows 0 fixed).
```

---

## Anti-patterns for this ticket

- **Silent failures** — never swallow a parse error or missing vault silently; warn to stderr and continue.
- **Rewriting frontmatter carelessly** — preserve key order and unrelated keys exactly; only touch the `twins:` array.
- **Assuming `.md` extension** — the `file` param in `obsidian://` URLs may or may not include it; handle both.
- **Single-value `twins:`** — a user might write `twins: "url"` instead of a list; coerce to list before processing.
- **Over-engineering** — one flat script file; no classes; no plugin architecture.

---

## Confidence score

**7/10** — The core logic is straightforward. The main risk is `obsidian.json` structure varying across OS versions or Obsidian releases (the vault-name derivation from `path` basename is an assumption worth verifying early). YAML frontmatter round-tripping without clobbering unrelated keys requires care.
