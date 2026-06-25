#!/usr/bin/env python3
import pytest
from pathlib import Path
import twin_links


# --- parse_twin_url ---

def test_parse_twin_url_valid():
    url = "obsidian://open?vault=permaculture-projects&file=projects%2Fsome-note.md"
    vault, rel_path = twin_links.parse_twin_url(url)
    assert vault == "permaculture-projects"
    assert rel_path == "projects/some-note.md"


def test_parse_twin_url_no_extension():
    url = "obsidian://open?vault=my-vault&file=folder%2Fnote"
    vault, rel_path = twin_links.parse_twin_url(url)
    assert vault == "my-vault"
    assert rel_path == "folder/note"


def test_parse_twin_url_malformed_scheme():
    with pytest.raises(ValueError):
        twin_links.parse_twin_url("https://obsidian.md/open?vault=v&file=f")


def test_parse_twin_url_not_a_url():
    with pytest.raises(ValueError):
        twin_links.parse_twin_url("not-a-url-at-all")


def test_parse_twin_url_missing_vault_param():
    with pytest.raises(ValueError):
        twin_links.parse_twin_url("obsidian://open?file=note.md")


def test_parse_twin_url_missing_file_param():
    with pytest.raises(ValueError):
        twin_links.parse_twin_url("obsidian://open?vault=my-vault")


# --- build_obsidian_url / round-trip ---

def test_build_obsidian_url_roundtrip(tmp_path):
    vault_root = tmp_path / "my-vault"
    vault_root.mkdir()
    note = vault_root / "folder" / "note.md"
    note.parent.mkdir()
    note.touch()

    url = twin_links.build_obsidian_url("my-vault", note, vault_root)
    vault, rel_path = twin_links.parse_twin_url(url)

    assert vault == "my-vault"
    assert Path(rel_path) == Path("folder/note")


def test_build_obsidian_url_encodes_spaces(tmp_path):
    vault_root = tmp_path / "my vault"
    vault_root.mkdir()
    note = vault_root / "some note.md"
    note.touch()

    url = twin_links.build_obsidian_url("my vault", note, vault_root)
    assert " " not in url
    vault, rel_path = twin_links.parse_twin_url(url)
    assert vault == "my vault"
    assert rel_path == "some note"


# --- has_reciprocal ---

def test_has_reciprocal_true(tmp_path):
    origin_url = "obsidian://open?vault=other-vault&file=other-note.md"
    note = tmp_path / "note.md"
    note.write_text(f'---\ntwins:\n  - "{origin_url}"\n---\nBody\n')
    assert twin_links.has_reciprocal(note, origin_url) is True


def test_has_reciprocal_false(tmp_path):
    note = tmp_path / "note.md"
    note.write_text('---\ntwins:\n  - "obsidian://open?vault=other&file=other.md"\n---\nBody\n')
    assert twin_links.has_reciprocal(note, "obsidian://open?vault=other&file=different.md") is False


def test_has_reciprocal_no_twins_key(tmp_path):
    note = tmp_path / "note.md"
    note.write_text("---\ntitle: Test\n---\nBody\n")
    assert twin_links.has_reciprocal(note, "obsidian://open?vault=v&file=f.md") is False


def test_has_reciprocal_null_twins(tmp_path):
    # twins: present but null (e.g. "twins:" with no value)
    note = tmp_path / "note.md"
    note.write_text("---\ntwins:\n---\nBody\n")
    assert twin_links.has_reciprocal(note, "obsidian://open?vault=v&file=f") is False


def test_has_reciprocal_no_frontmatter(tmp_path):
    note = tmp_path / "note.md"
    note.write_text("Just plain text, no frontmatter.\n")
    assert twin_links.has_reciprocal(note, "obsidian://open?vault=v&file=f.md") is False


def test_has_reciprocal_scalar_twins(tmp_path):
    # Guard against user writing twins: "url" instead of a list
    origin_url = "obsidian://open?vault=v&file=f.md"
    note = tmp_path / "note.md"
    note.write_text(f'---\ntwins: "{origin_url}"\n---\nBody\n')
    assert twin_links.has_reciprocal(note, origin_url) is True


# --- find_candidates ---

def test_find_candidates_returns_matching_files(tmp_path):
    vault = tmp_path / "vault"
    (vault / "folder1").mkdir(parents=True)
    (vault / "folder2").mkdir(parents=True)
    (vault / "folder1" / "note.md").touch()
    (vault / "folder2" / "note.md").touch()
    (vault / "other.md").touch()

    candidates = twin_links.find_candidates(vault, "note")
    assert len(candidates) == 2
    assert all(c.stem == "note" for c in candidates)


def test_find_candidates_case_insensitive(tmp_path):
    vault = tmp_path / "vault"
    vault.mkdir()
    (vault / "MyNote.md").touch()

    candidates = twin_links.find_candidates(vault, "mynote")
    assert len(candidates) == 1


def test_find_candidates_no_match(tmp_path):
    vault = tmp_path / "vault"
    vault.mkdir()
    (vault / "other.md").touch()

    assert twin_links.find_candidates(vault, "ghost") == []


def test_find_candidates_skips_templates_folder(tmp_path):
    vault = tmp_path / "vault"
    (vault / "templates").mkdir(parents=True)
    (vault / "templates" / "note.md").touch()
    (vault / "note.md").touch()

    candidates = twin_links.find_candidates(vault, "note")
    assert len(candidates) == 1
    assert "templates" not in str(candidates[0])


def test_find_candidates_strips_md_extension(tmp_path):
    # Should match even if caller passes filename with .md
    vault = tmp_path / "vault"
    vault.mkdir()
    (vault / "note.md").touch()

    candidates = twin_links.find_candidates(vault, "note.md")
    assert len(candidates) == 1


# --- read_frontmatter / write_frontmatter round-trip ---

def test_read_frontmatter_basic(tmp_path):
    note = tmp_path / "note.md"
    note.write_text("---\ntitle: My Note\n---\nBody content here\n")

    fm, body = twin_links.read_frontmatter(note)

    assert fm["title"] == "My Note"
    assert "Body content here" in body


def test_read_frontmatter_no_frontmatter(tmp_path):
    note = tmp_path / "note.md"
    note.write_text("Just body text, no frontmatter.\n")

    with pytest.raises(ValueError):
        twin_links.read_frontmatter(note)


def test_write_frontmatter_roundtrip(tmp_path):
    note = tmp_path / "note.md"
    note.write_text("---\ntitle: My Note\n---\nBody content here\n")

    fm, body = twin_links.read_frontmatter(note)
    fm["twins"] = ["obsidian://open?vault=v&file=f.md"]
    twin_links.write_frontmatter(note, fm, body, dry_run=False)

    result = note.read_text()
    assert "title: My Note" in result
    assert "Body content here" in result
    assert "obsidian://open?vault=v&file=f.md" in result


def test_write_frontmatter_dry_run_does_not_write(tmp_path):
    note = tmp_path / "note.md"
    original = "---\ntitle: My Note\n---\nBody\n"
    note.write_text(original)

    fm, body = twin_links.read_frontmatter(note)
    fm["twins"] = ["obsidian://open?vault=v&file=f.md"]
    twin_links.write_frontmatter(note, fm, body, dry_run=True)

    assert note.read_text() == original


# --- add_reciprocal ---

def test_add_reciprocal_creates_twins_key(tmp_path):
    note = tmp_path / "note.md"
    note.write_text("---\ntitle: Existing\n---\nBody\n")

    origin_url = "obsidian://open?vault=v&file=origin.md"
    twin_links.add_reciprocal(note, origin_url, dry_run=False)

    fm, body = twin_links.read_frontmatter(note)
    assert fm["title"] == "Existing"
    assert origin_url in fm["twins"]
    assert "Body" in body


def test_add_reciprocal_appends_to_existing_twins(tmp_path):
    note = tmp_path / "note.md"
    existing_url = "obsidian://open?vault=v&file=existing.md"
    note.write_text(f'---\ntwins:\n  - "{existing_url}"\n---\nBody\n')

    new_url = "obsidian://open?vault=v&file=new.md"
    twin_links.add_reciprocal(note, new_url, dry_run=False)

    fm, _ = twin_links.read_frontmatter(note)
    assert existing_url in fm["twins"]
    assert new_url in fm["twins"]


def test_add_reciprocal_idempotent(tmp_path):
    # Calling add_reciprocal twice should not create duplicates
    note = tmp_path / "note.md"
    note.write_text("---\ntitle: Test\n---\nBody\n")

    url = "obsidian://open?vault=v&file=f.md"
    twin_links.add_reciprocal(note, url, dry_run=False)
    twin_links.add_reciprocal(note, url, dry_run=False)

    fm, _ = twin_links.read_frontmatter(note)
    assert fm["twins"].count(url) == 1


def test_add_reciprocal_dry_run_no_change(tmp_path):
    note = tmp_path / "note.md"
    original = "---\ntitle: Existing\n---\nBody\n"
    note.write_text(original)

    twin_links.add_reciprocal(note, "obsidian://open?vault=v&file=f.md", dry_run=True)

    assert note.read_text() == original
