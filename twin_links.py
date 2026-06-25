#!/usr/bin/env python3
"""Validate and repair bidirectional twins: links across Obsidian vaults."""

import json
import sys
import yaml
from pathlib import Path
from urllib.parse import urlparse, parse_qs, quote
from typing import Iterator

OBSIDIAN_CONFIG = (
    Path.home() / "Library" / "Application Support" / "obsidian" / "obsidian.json"
)


def load_vaults() -> dict[str, Path]:
    """Read Obsidian's vault registry and return {vault_name: absolute_path}.

    Derives vault name from the basename of each vault's path — this matches
    how obsidian:// URLs refer to vaults. Raises FileNotFoundError if the
    config is absent (e.g. Obsidian not installed).
    """
    if not OBSIDIAN_CONFIG.exists():
        raise FileNotFoundError(
            f"Obsidian config not found at {OBSIDIAN_CONFIG}. Is Obsidian installed?"
        )
    data = json.loads(OBSIDIAN_CONFIG.read_text(encoding="utf-8"))
    return {
        Path(entry["path"]).name: Path(entry["path"])
        for entry in data.get("vaults", {}).values()
    }


def scan_vaults(vaults: dict[str, Path]) -> Iterator[tuple[Path, list[str]]]:
    """Walk every .md file in every vault; yield (file_path, twins_list) for files with twins:.

    Skips files with no frontmatter silently. Warns to stderr for parse
    errors (bad YAML, encoding issues) but continues scanning.
    """
    for vault_path in vaults.values():
        for md_file in vault_path.rglob("*.md"):
            if "templates" in md_file.parts:
                continue
            try:
                fm, _ = read_frontmatter(md_file)
            except ValueError:
                continue  # no frontmatter or malformed — skip silently
            except Exception as e:
                print(f"Warning: could not parse {md_file}: {e}", file=sys.stderr)
                continue

            twins = fm.get("twins") or []
            if not twins:
                continue

            if isinstance(twins, str):
                twins = [twins]

            yield md_file, twins


def parse_twin_url(url: str) -> tuple[str, str]:
    """Parse an obsidian://open?vault=X&file=Y URL.

    Returns (vault_name, rel_path) where rel_path is URL-decoded.
    Raises ValueError for malformed or non-obsidian URLs.
    """
    parsed = urlparse(url)
    if parsed.scheme != "obsidian" or parsed.netloc != "open":
        raise ValueError(f"Not a valid obsidian://open URL: {url!r}")

    params = parse_qs(parsed.query)
    if "vault" not in params or "file" not in params:
        raise ValueError(f"Missing vault or file parameter in URL: {url!r}")

    return params["vault"][0], params["file"][0]


def resolve_twin(
    vault_name: str, rel_path: str, vaults: dict[str, Path]
) -> Path | None:
    """Resolve a twin reference to an absolute filesystem path.

    Returns None if the vault name is unknown (caller prints broken-vault
    message). Raises FileNotFoundError if the vault exists but the file
    doesn't — caller treats this as a broken link and calls find_candidates.
    Tries rel_path as-is, then with .md appended if extension is absent.
    """
    vault_root = vaults.get(vault_name)
    if vault_root is None:
        return None

    candidate = vault_root / rel_path
    if candidate.exists():
        return candidate

    if not rel_path.endswith(".md"):
        with_ext = vault_root / (rel_path + ".md")
        if with_ext.exists():
            return with_ext

    raise FileNotFoundError(f"{rel_path!r} not found in vault {vault_name!r}")


def find_candidates(vault_path: Path, filename: str) -> list[Path]:
    """Walk vault_path recursively; return all .md files whose stem matches filename.

    Comparison is case-insensitive and ignores .md extension in filename.
    Used to suggest relocation candidates when a twin link is broken.
    """
    target = filename.lower()
    if target.endswith(".md"):
        target = target[:-3]

    return [
        p for p in vault_path.rglob("*.md")
        if p.stem.lower() == target and "templates" not in p.parts
    ]


def build_obsidian_url(vault_name: str, note_path: Path, vault_root: Path) -> str:
    """Construct an obsidian://open?vault=<name>&file=<encoded-rel-path> URL.

    rel_path uses forward slashes regardless of OS. Both vault name and
    file path are percent-encoded for correctness with special characters.
    """
    rel_path = note_path.relative_to(vault_root).as_posix()
    if rel_path.endswith(".md"):
        rel_path = rel_path[:-3]
    return (
        f"obsidian://open?vault={quote(vault_name, safe='')}"
        f"&file={quote(rel_path, safe='')}"
    )


def has_reciprocal(twin_path: Path, origin_url: str) -> bool:
    """Return True if origin_url appears in twin_path's twins: frontmatter list.

    Returns False (not raises) if twin_path has no frontmatter or no twins key.
    """
    try:
        fm, _ = read_frontmatter(twin_path)
    except ValueError:
        return False

    twins = fm.get("twins") or []
    if isinstance(twins, str):
        twins = [twins]

    return origin_url in twins


def read_frontmatter(path: Path) -> tuple[dict, str]:
    """Parse YAML frontmatter delimited by --- from path.

    Returns (frontmatter_dict, body) where body is everything after the
    closing --- (including the leading newline). Raises ValueError if
    no valid frontmatter block is found.
    """
    text = path.read_text(encoding="utf-8")

    if not text.startswith("---"):
        raise ValueError(f"No frontmatter in {path}")

    end = text.find("\n---", 3)
    if end == -1:
        raise ValueError(f"Unclosed frontmatter block in {path}")

    yaml_text = text[3:end].strip()
    body = text[end + 4:]  # skip the \n--- closing marker

    fm = yaml.safe_load(yaml_text) or {}
    if not isinstance(fm, dict):
        raise ValueError(f"Frontmatter is not a YAML mapping in {path}")

    return fm, body


def write_frontmatter(path: Path, fm: dict, body: str, dry_run: bool) -> None:
    """Serialise fm back to YAML and reconstruct the file as ---\\n<yaml>---<body>.

    body from read_frontmatter starts with \\n (the line break after the
    closing ---), so no extra separator is needed. Does not write if dry_run.
    """
    yaml_text = yaml.dump(
        fm, default_flow_style=False, allow_unicode=True, sort_keys=False
    )
    content = f"---\n{yaml_text}---{body}"

    if not dry_run:
        path.write_text(content, encoding="utf-8")


def add_reciprocal(twin_path: Path, origin_url: str, dry_run: bool) -> None:
    """Append origin_url to twin_path's twins: list (creating the key if absent).

    Idempotent: skips if origin_url is already present. Preserves all other
    frontmatter keys and body text. If twin_path has no frontmatter, creates
    a minimal frontmatter block prepended to the file.
    """
    try:
        fm, body = read_frontmatter(twin_path)
    except ValueError:
        body = "\n" + twin_path.read_text(encoding="utf-8")
        fm = {}

    twins = fm.get("twins") or []
    if isinstance(twins, str):
        twins = [twins]

    if origin_url in twins:
        return  # already present — idempotent

    twins.append(origin_url)
    fm["twins"] = twins

    write_frontmatter(twin_path, fm, body, dry_run)


def _vault_for(note_path: Path, vaults: dict[str, Path]) -> tuple[str, Path] | None:
    """Return (vault_name, vault_root) for the vault that contains note_path.

    Returns None if note_path does not fall under any known vault.
    """
    for name, root in vaults.items():
        try:
            note_path.relative_to(root)
            return name, root
        except ValueError:
            continue
    return None


def main() -> None:
    """Scan all vaults, fix missing reciprocals, and report broken links.

    Reads --dry-run flag from sys.argv. Prints [FIXED] / [BROKEN] lines
    and a summary count at the end.
    """
    dry_run = "--dry-run" in sys.argv

    try:
        vaults = load_vaults()
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    fixed = 0
    broken = 0

    for note_path, twins in scan_vaults(vaults):
        vault_info = _vault_for(note_path, vaults)
        if vault_info is None:
            print(f"Warning: could not determine vault for {note_path}", file=sys.stderr)
            continue

        note_vault_name, note_vault_root = vault_info
        origin_url = build_obsidian_url(note_vault_name, note_path, note_vault_root)

        for twin_url in twins:
            try:
                vault_name, rel_path = parse_twin_url(twin_url)
            except ValueError as e:
                print(f"[BROKEN] {note_path.name} → malformed URL: {e}", file=sys.stderr)
                broken += 1
                continue

            try:
                twin_path = resolve_twin(vault_name, rel_path, vaults)
            except FileNotFoundError:
                candidates = (
                    find_candidates(vaults[vault_name], Path(rel_path).stem)
                    if vault_name in vaults
                    else []
                )
                print(f"[BROKEN] {note_path.name} → {twin_url}")
                for c in candidates:
                    print(f"  Candidate: {c}")
                broken += 1
                continue

            if twin_path is None:
                print(f'[BROKEN] {note_path.name} → unknown vault "{vault_name}"')
                broken += 1
                continue

            if not has_reciprocal(twin_path, origin_url):
                add_reciprocal(twin_path, origin_url, dry_run)
                suffix = " (dry run)" if dry_run else ""
                print(f"[FIXED] added reciprocal in {twin_path.name}{suffix}")
                fixed += 1

    print(f"\n{fixed} fixed, {broken} broken")


if __name__ == "__main__":
    main()
