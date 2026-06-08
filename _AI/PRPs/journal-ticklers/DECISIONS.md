## Language: Python (not Ruby)
**Decision:** Script will be written in Python
**Why:** User is actively learning Python and wants to use this as practice; the rest of the repo is Ruby but there is no requirement for consistency
**Alternatives:** Ruby (fits the existing repo pattern but offers no learning value)

## Prompt storage: vault file, path as argument
**Decision:** Prompts are stored in a plain markdown file inside the Obsidian vault; the script takes the file path as a CLI argument
**Why:** Keeps prompts editable in Obsidian; follows the established pattern of other tools in this repo (e.g. `retire_log_files.rb`, `get_date_nav.rb`)
**Alternatives:** Bundling prompts inside the repo alongside the script (simpler but prompts become harder to edit day-to-day)
