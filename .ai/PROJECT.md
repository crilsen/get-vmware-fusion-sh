# Project

## Identity

- **Name:** repository `get-vmware-fusion-sh` (formerly `get-vmwarefusion`); the tool itself is `get-vmwarefusion.sh`. Not a published package. The local working directory is still `get-vmwarefusion`.
- **Deliverable:** a single Bash script, `get-vmwarefusion.sh`.
- **Objective:** find the newest VMware Fusion build mirrored on archive.org, download it to `~/Downloads`, and optionally install or replace it in `/Applications`.
- **Status:** working utility in use, but currently broken as shipped (see Known defects). No version tag, no changelog, no git repository.
- **Owner / audience:** the repository owner, on macOS. No distribution, packaging, or installer metadata exists.

## Observed

- Repository contents: `AGENTS.md`, `README.md`, `.ai/` (this context layer), `.gitignore`, `get-vmwarefusion.sh`, and macOS `.DS_Store` artifacts (ignored by git). No `docs/`, tests, CI/CD, IaC, or packaging.
- Git repository on branch `main`, remote `origin` = `https://github.com/crilsen/get-vmware-fusion-sh` (**public** since 2026-10-27), created from the working tree on the same day. The repository was initially `get-vmwarefusion` and private; renamed and published by the owner, who accepted the licence-key trade-off recorded in `.ai/HANDOFF.md`. Conventional Commits are used for subjects (`chore:`, `docs:`, `feat:`, `fix:`), matching the owner's other repositories.
- `get-vmwarefusion.sh`: 642 lines, 18,886 bytes, mode `0755` (directly executable), shebang `#!/usr/bin/env bash` on line 1.
- Language: Bash, invoked directly (`./get-vmwarefusion.sh`). `sh get-vmwarefusion.sh` fails at parse time; `bash get-vmwarefusion.sh` also works.
- The only `bash` on the current machine is `/bin/bash` 3.2.57; `sort -V` (GNU) is absent. Anything added must stay Bash 3.2 / BSD-userland compatible.
- Runtime platform observed: macOS 26.2 (build 25C56), arm64.
- Install support is macOS-only; the download path is platform-agnostic.
- External network dependency: exactly one host, `archive.org` (`ARCHIVE_BASE_URL`), scraped over HTML.
- Persistent local state: `~/.local/.vmwarefusion_last_version`, holding `version-build`.

## CLI surface (observed)

| Flag | Behavior |
| --- | --- |
| `-y` | Skip confirmation prompts |
| `-i` | Download and install; implies `-y` |
| `-d` | Download only; overrides `-i` |
| `-f` | Force install even if the same version is installed |
| `-t <dmg>` | Install an existing local DMG, skipping version discovery and download |

No `-h`, `--help`, `--version`, `--dry-run`, version selection, or download-directory override. `usage()` exits `1`.

## Known defects (analysis 2026-10-27)

Ordered by impact; details and line references in `.ai/TASKS.md`.

1. **Runnability:** fixed 2026-10-27 — the shebang is on line 1, the file is `0755`, and `-h` prints usage and exits `0`. Previously the prose on line 1 displaced the shebang and the file was `0400`, so direct execution failed (`exit 126`) and `sh` fallback broke on Bash-only syntax. `bash -n` passed even then, so syntax checks never caught it.
2. **Security:** DMGs come from a third-party archive mirror with no signature, hash, or size verification, while `xattr` strips `com.apple.quarantine` from the DMG and the installed app.
3. **Data loss risk:** the existing `/Applications/VMware Fusion.app` is deleted before the new copy succeeds; no staging, backup, or rollback.
4. **Logic:** possible permanent update loop when the bundle version omits the `uN` suffix that the archive filename carries (e.g. `26H1u1` vs `26H1`).
5. **Correctness:** a truncated DMG left by a failed download is reused and installed on the next run; no size or checksum check.
6. **Legal:** the success path advertises a GitHub repository of VMware license keys. The repository is now public, so this is the most visible outstanding issue.

## Not applicable

The optional infrastructure workflows shipped with the template (`terraform-change`, `kubernetes-change`, `cloud-port`) do not apply: no Terraform/OpenTofu, Kubernetes, Helm, or cloud provider is used. They are left in `.ai/workflows/` unused rather than deleted; the initial commit is the recovery point if they are ever removed.

## Not determinable from the repository

- Supported VMware Fusion versions and whether year-half naming (`25H2`, `26H1` + `uN`) is the permanent scheme.
- Whether the installed app's `CFBundleShortVersionString` includes the `uN` suffix (decides defect 4).
- Target audience and any license for the script itself.
