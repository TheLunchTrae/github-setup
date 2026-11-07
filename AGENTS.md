# AGENTS.md

Exportable GitHub repo setup applied to new repos with `apply.sh`.

## Layout

- `rulesets/*.json`: repository ruleset bodies for `POST /repos/{owner}/{repo}/rulesets`, applied to every repo.
- `rulesets/npm/*.json`: tag rulesets for npm package repos, applied only with `--npm`.
- `settings/*.json`: request bodies for the repo, Actions permissions and workflow permissions endpoints.
- `apply.sh`: applies everything to `OWNER/REPO` with `gh api`.

## Conventions

- Ruleset names are `<Protected target>: <What it does>`, e.g. `Main: Require PR`. File names are the kebab-case name.
- One rule per ruleset so each can be bypassed separately; the exceptions are `Main: Block Creation and Deletion` and `Tags: Block Updates and Deletion`. Branch rulesets target `~DEFAULT_BRANCH`.
- Keep `"name"` on its own line at two-space indent; `apply.sh` reads it with `sed` to update rulesets by name.
- The status checks ruleset keeps `"required_status_checks": []` exactly; `apply.sh` fills it from `--check`.
- `apply.sh` must run in Git Bash on Windows and stock macOS bash: no `jq`, no bash 4+ only features.
- Check field names against the current GitHub REST docs before adding or changing a setting.
- Update `README.md` when a ruleset or setting changes.
