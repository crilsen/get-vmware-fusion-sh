# Current Work

## Active

- None. The script is runnable again; the remaining P0 items (payload verification and atomic install) are still unauthorized.

## Planned

Remediation for `get-vmwarefusion.sh`. Line references are from the 2026-10-27 HEAD snapshot (642 lines); re-check them if the file changes again.

1. ~~**P0 — make it runnable.**~~ **Done 2026-10-27:** prose removed from line 1, shebang now on line 1, mode `0755`, `-h` added (usage exits `0`, unknown flag exits `1`). `set -euo pipefail` is still **pending** and belongs with item 3, since enabling it changes every error path.
2. **P0 — stop de-fanging Gatekeeper.** Remove `xattr` at line 434 (installed app) and line 607 (DMG); add `codesign --verify --deep --strict` + `spctl --assess --type execute` on the mounted bundle (line 401, where the app is located) before anything else happens.
3. **P0 — remove the data-loss window.** Replace `rm -rf` (line 417) + `cp -R` (line 426) with a staged copy plus an atomic `mv` swap, keep a rollback path, abort if VMware Fusion is running, and check free space. Add `set -euo pipefail` and a `trap` in the same change.
4. **P1 — fix update detection.** Decide by build number first; confirm whether `CFBundleShortVersionString` carries the `uN` suffix before changing the comparison at lines 276–288.
5. **P1 — reject bad artifacts.** Validate DMG size (compare against `Content-Length`) before install; treat `HTTP 416` from `curl -C -` as "already complete"; delete or quarantine partial files; prefer `--speed-limit`/`--speed-time` over `--max-time 300` (line 312).
6. **P1 — remove the piracy link.** Replace `show_license_info` (lines 463–466) and the duplicated literal at line 503 with the official Broadcom download page; the Free Personal Use entitlement makes key lists unnecessary. This is now the most visible issue in a public repository.
7. **P2 — robustness.** Replace the three `hdiutil` output heuristics (lines 366–383) with `-mountpoint` on a `mktemp -d`; add `trap 'hdiutil detach …' EXIT INT TERM`; extend `requirements_check` to `find basename defaults xattr`; drop `setup_sort`/`SORT_CMD`/`SORT_UNIQUE_CMD` (dead code, lines 69–77); declare `local entry` (line 194); remove the debug dump at lines 361–363; move the state file out of `~/.local/.` to `~/Library/Application Support/`.

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
- 2026-10-27 — Made the script runnable: removed the prose from line 1 (shebang now line 1), `chmod 755`, added `-h` (exit `0`) and explicit `exit 1` for unknown flags. Validated with `bash -n`, `shellcheck`, `./get-vmwarefusion.sh -h` and `-z`.
