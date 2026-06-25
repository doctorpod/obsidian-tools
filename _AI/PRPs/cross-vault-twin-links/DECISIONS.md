## Frontmatter field: `twins` array

**Decision:** Twin relationships are declared in YAML frontmatter using a `twins` key holding an array of `obsidian://` URLs. Example:
```yaml
twins:
  - "obsidian://open?vault=permaculture-projects&file=projects%2Fsome-note"
```
**Why:** Frontmatter is machine-readable, doesn't pollute note content, and an array supports multiple twins per note.
**Alternatives:** A dedicated body section (more visible/clickable but pollutes content); a single scalar value (rejected because a note can have more than one twin).

## Cross-vault link format: `obsidian://` URL scheme

**Decision:** Each entry in the `twins` array is a full `obsidian://open?vault=<name>&file=<encoded-path>` URL.
**Why:** The URL encodes both the vault name and the file path within the vault, making it unambiguous and parseable by the script without additional config.
**Alternatives:** Relative file paths (not vault-aware, fragile across moves); vault-prefixed wikilinks (invented syntax, Obsidian won't render them).

## Vault discovery: read Obsidian's own config

**Decision:** The script resolves vault names to filesystem paths by reading `~/Library/Application Support/obsidian/obsidian.json`.
**Why:** This is the authoritative, always-current source — no separate config file to maintain or drift.
**Alternatives:** A hand-maintained `vaults.yaml`; scanning a parent directory by convention.

## Script scope: validation only, not discovery

**Decision:** The script validates existing `twins` declarations — it does not attempt to discover notes that *should* be twins but aren't linked yet.
**Why:** Intellectual equivalence can't be inferred programmatically; twin relationships are declared manually by the author.
**Script behaviour:**
- For each note with a `twins:` field, check that every listed target exists and has a reciprocal entry pointing back.
- Also validate existing two-way links in case files have moved or been deleted.
**Alternatives:** AI-assisted discovery (deferred; separate problem).

## Script behaviour: auto-fix reciprocals, report broken links

**Decision:** When a note declares a twin but the target has no reciprocal entry, the script writes the backlink automatically. When a target file cannot be found, the script reports it and searches the target vault for a note with the same filename (path-agnostic) to suggest a candidate.
**Why:** Missing reciprocals are mechanical errors the script can fix safely. Broken links (moved/deleted files) require human judgement — the filename-fallback turns the report into an actionable fix rather than a dead end.
**Alternatives:** Report-only for everything (too passive); auto-fix broken links (too risky without human confirmation).

## Invocation: scan all vaults, no config, manual run

**Decision:** The script reads all registered vaults from `obsidian.json` and scans every `.md` file in every vault for a `twins:` field. No config file, no arguments needed for a normal run. Invoked manually as needed.
**Why:** Self-discovering — adding a new vault to Obsidian automatically includes it. Personal vault sizes make a full scan practical.
**Alternatives:** Config file listing vault pairs (more control, more maintenance); CLI vault arguments (flexible but nothing persisted).

## Safety: `--dry-run` flag

**Decision:** The script supports a `--dry-run` flag that reports all changes it would make without writing anything.
**Why:** Since the script auto-modifies notes across multiple vaults, dry-run provides a safe inspection mode for first runs and after script changes.

