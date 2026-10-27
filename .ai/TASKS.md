# Current Work

## Active

- None. Context adoption is complete; the script analysis was delivered on 2026-10-27 and no code change has been started or authorized yet.

## Planned

Remediation for `get-vmwarefusion.sh`, in the order agreed as safe to batch. Line references are from the 2026-10-27 snapshot of the file.

1. **P0 — make it runnable.** Delete the prose on line 1, move `#!/usr/bin/env bash` to line 1, `chmod 755`, add `set -euo pipefail`, add `-h/--help` returning `0`, and stop `getopts` from printing `illegal option`.
2. **P0 — stop de-fanging Gatekeeper.** Remove `xattr` at lines 433 and 606; add `codesign --verify --deep --strict` + `spctl --assess --type execute` on the mounted bundle before anything else happens.
3. **P0 — remove the data-loss window.** Replace `rm -rf` (line 416) + `cp -R` (line 425) with a staged copy plus an atomic `mv` swap, keep a rollback path, abort if VMware Fusion is running, and check free space.
4. **P1 — fix update detection.** Decide by build number first; confirm whether `CFBundleShortVersionString` carries the `uN` suffix before changing the comparison at lines 275–287.
5. **P1 — reject bad artifacts.** Validate DMG size (compare against `Content-Length`) before install; treat `HTTP 416` from `curl -C -` as "already complete"; delete or quarantine partial files; prefer `--speed-limit`/`--speed-time` over `--max-time 300` (line 311).
6. **P1 — remove the piracy link.** Replace `show_license_info` (lines 462–465) and the duplicated literal at line 502 with the official Broadcom download page; the Free Personal Use entitlement makes key lists unnecessary.
7. **P2 — robustness.** Replace the three `hdiutil` output heuristics (lines 367–384) with `-mountpoint` on a `mktemp -d`; add `trap 'hdiutil detach …' EXIT INT TERM`; extend `requirements_check` to `find basename defaults xattr`; drop `setup_sort`/`SORT_CMD`/`SORT_UNIQUE_CMD` (dead code, lines 70–78); declare `local entry` (line 193); remove the debug dump at lines 362–364; move the state file out of `~/.local/.` to `~/Library/Application Support/`.

### Separate, optional

8. ~~Introduce git for this repository~~ — done 2026-10-27 (initial commit, remote `crilsen/get-vmware-fusion-sh`, public).
9. Add a `shellcheck` baseline to the repository once the script is fixed; `README.md` is done.
10. Consider an official-source path (Broadcom portal or the `vmware-fusion` Homebrew cask, which verifies the vendor signature) alongside, or instead of, the archive.org mirror.
11. Decide the repository license (none declared yet; `README.md` states this explicitly). The visibility question is closed: the owner published the repository on 2026-10-27 despite the licence-key URL, which stays open as P1 item 6.

## Blocked

- Any change that ends with an actual install/upgrade cannot be validated here: it mutates `/Applications` and requires explicit authorization (see `.ai/TOOLS.md`).
- Item 4 depends on an observed `CFBundleShortVersionString` from a 26H1u1 install, which is not present on this machine.

## Completed

- 2026-10-27 — Read the repository and analyzed `get-vmwarefusion.sh` (line-level review, 10 findings by severity).
- 2026-10-27 — Adopted the context layer: `PROJECT.md`, `ARCHITECTURE.md`, `CONVENTIONS.md`, `VALIDATION.md`, `TOOLS.md`, `TASKS.md`, `HANDOFF.md`, `LEARNINGS.md` populated from observed facts.
- 2026-10-27 — Wrote `README.md` (usage, flag table, version-selection logic, touched paths, known issues, security notes, credits) and `.gitignore` (`.DS_Store`, `*.dmg`, `.env*`).
- 2026-10-27 — `git init` on `main`; two commits (script + context layer, then README); repository renamed `get-vmware-fusion-sh`, made public, and pushed to `https://github.com/crilsen/get-vmware-fusion-sh`.
