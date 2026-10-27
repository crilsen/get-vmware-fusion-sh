# Conventions

## Annotation language (standing preference)

- **English**, declared by the repository owner on 2026-10-27 as a standing preference for this repository: code comments and every relay `.md` file (`AGENTS.md`, `.ai/`, `docs/`, `README.md`, PRD/spec/decision records).
- Do not re-ask in later sessions; re-confirm only if the owner asks for a different language.
- Chat replies follow the language the owner writes in (pt-BR observed), independent of the annotation language.

## Observed shell conventions (as the script actually is)

- Bash, single file, `#!/usr/bin/env bash`. Bash 3.2 compatibility is required on this machine (`/bin/bash` is 3.2.57); `[[ ]]`, `<<<`, `{a..b}`, arrays and `local` are all in use and are 3.2-safe.
- Constants and mutable globals in `UPPER_SNAKE_CASE` at the top of the file (`ARCHIVE_BASE_URL`, `SKIP_CONFIRMATION`, `VERSION_FILE`).
- Functions in `snake_case`, named `verb_noun` (`get_installed_version`, `install_vmware_fusion`, `find_latest_version`).
- Function-internal variables declared with `local`; one leaked global exists (`entry`, line 193).
- Two-space indentation; comments at column 1 with `# `; block comments above functions explain intent (e.g. the version-normalization mapping).
- All variables expanded inside `[[ ]]` and in command arguments are double-quoted (`"$dmg_file"`, `"$ARCHIVE_BASE_URL/$major_version/"`).
- User-facing progress goes to `stdout` via `echo`; errors go to `stderr` with an explicit prefix: `Error: ...`, `Warning: ...`, then `exit 1` for fatal conditions.
- Success messages use past tense (`Download successful!`, `Installation completed successfully!`); section headers are printable banners (`=== Version Check ===`).
- Return-code conventions are mixed: helpers `return 1` and callers decide, but `download_vmware_fusion` and `get_archive_major_versions` call `exit 1` from inside helpers.
- No `set -euo pipefail`; no `trap`; exit codes are checked ad hoc with `if [[ $? -ne 0 ]]`.
- Version strings are handled as `MAJOR.MINOR.PATCH.UPDATE` tuples; every comparison goes through `normalize_version` + `version_greater_than` rather than string comparison.

## Standing rules for future changes

- Keep the script a single self-contained file; it is installed by copying, not by a package manager.
- Never regress Bash 3.2 / BSD-userland compatibility: no `sort -V`, no `mapfile`, no `${var,,}`, no GNU-only flags without a capability check.
- Keep the shebang on line 1 and keep the file executable (`0755`).
- Every download or install path must be verifiable before it mutates `/Applications`; prefer staging plus an atomic swap over in-place deletion.
- Do not add a new external host without recording it here and in `.ai/ARCHITECTURE.md`.
- Preserve the observed CLI contract (`-y -i -d -f -t`); additive flags only.
- User-facing output stays in English, matching the existing messages.

## Documentation

- `AGENTS.md` stays short and routing-only; facts live in `.ai/`.
- `TASKS.md` reflects only current work; `HANDOFF.md` holds the rolling resume checkpoint and is not a chat log.
- `LEARNINGS.md` is a bounded, append-only buffer; promote durable rules here instead of letting them pile up.
- Only the primary agent writes `HANDOFF.md`, `TASKS.md`, and `LEARNINGS.md`.
- Context is maintained **automatically** (owner preference, 2026-10-27): update `.ai/` as work happens without asking each time.
