# Architecture

## Shape

A single-file Bash program invoked as `bash get-vmwarefusion.sh [flags]`. No modules, no sourced files, no compiled artifacts. State is a plain text file; all knowledge of "latest" is derived on every run by scraping HTML.

```text
argv ──► getopts ──► requirements_check
                          │
              ┌───────────┴────────────┐
        (-t given)                (default path)
              │                        │
   install_vmware_fusion        setup_sort, DOWNLOAD_DIR
   (local DMG)                       │
                       get_archive_major_versions   ── HTTP GET /Fusion/
                                     │                  → 13.x, 25H2, 26H1 …
                       get_archive_full_versions    ── HTTP GET /Fusion/<major>/
                        (per major, N requests)         → version filename major
                                     │
                          normalize_version / version_greater_than
                                     │
                            find_latest_version  ──► "ver|file|major"
                                     │
                          check_update_needed
                        (defaults read vs state file)
                                     │
                   download_vmware_fusion ── curl -C - --max-time 300 (3 attempts)
                                     │
                          install_vmware_fusion
                    hdiutil attach → find .app → rm -rf → cp -R → xattr
```

## Components

| Function | Responsibility |
| --- | --- |
| `usage` | Flag help; exits `1` |
| `requirements_check` | Verifies `curl grep awk sed sort` (plus `hdiutil cp` for install) |
| `setup_sort` | Selects GNU vs BSD sort flags; result is never consumed |
| `normalize_version` | Maps `13.6.4`→`13.6.4.0`, `25H2`→`25.2.0.0`, `26H1u1`→`26.1.0.1`, unknown→`0.0.0.0` |
| `version_greater_than` | 4-field numeric comparison of normalized tuples |
| `get_archive_major_versions` | Scrapes `<a href="13.x/">`-style folder links from the index page |
| `get_archive_full_versions` | Scrapes `.dmg` links inside one folder and emits `version filename major` |
| `find_latest_version` | Aggregates all folders and returns the maximum by normalized version |
| `get_installed_version` | `defaults read` on the installed bundle; empty if absent |
| `get_stored_version` / `store_version` | Reads/writes `~/.local/.vmwarefusion_last_version` |
| `extract_build_from_filename` | Pulls the 7+ digit build number out of the DMG name |
| `check_update_needed` | Decides install / update / up-to-date; returns non-zero when current |
| `download_vmware_fusion` | `curl` with resume and 3 attempts; exits the process on failure |
| `install_vmware_fusion` | Mount, locate `.app`, delete, copy, clear quarantine, detach |
| `show_license_info` | Prints a third-party license-key link |
| `main` | Orchestrates the above and owns all user prompts |

## Data flow and state

- **Remote truth:** the archive.org HTML listings. No API, no cache, no manifest. N+1 requests per run (1 index + one per major folder; 7 folders observed on 2026-10-27: `8.x 10.x 11.x 12.x 13.x 25H2 26H1`).
- **Local truth:** two independent sources that can disagree — the app bundle's `Info.plist` (via `defaults`) and the state file. `check_update_needed` trusts the state file first (`version-build` equality) and the bundle second.
- **Artifacts:** the DMG in `~/Downloads` is both the download target and the install input; it is never deleted, and it is reused if a file with the expected name already exists.
- **Privileges:** everything runs as the invoking user. `/Applications` must already be writable; there is no `sudo` escalation anywhere.

## External dependencies

| Dependency | Role | Failure mode |
| --- | --- | --- |
| `archive.org` (`vmwareworkstationarchive`) | Sole source of installers | Scraping breaks on any HTML change; no fallback mirror |
| `curl` | Listing fetch and download | 5-minute per-attempt cap truncates large files on slow links |
| `hdiutil` | Mount/detach DMG | Mount-point parsing is heuristic |
| `defaults` | Read bundle version | Fails silently to empty string |
| `xattr` | Removes Gatekeeper quarantine | Removes the only malware check on the payload |

## Absent by design or omission

No tests, no CI, no lint configuration, no logging, no `trap`-based cleanup, no dry-run mode, no checksum/signature verification, no atomic install, no uninstall. There is no IaC, container, or deployment layer to document.

## Architectural risks

- **Trust boundary:** an unauthenticated third-party mirror feeds a script that runs `rm -rf` in `/Applications` and neutralizes Gatekeeper. This is the dominant risk in the design, not an implementation detail.
- **Non-atomic mutation:** the install is a destructive in-place replacement with no staging area, so any failure leaves the user worse off than before.
- **Single scraping contract:** version discovery depends on undocumented HTML structure; there is no schema, retry on parse failure, or pinned snapshot.
- **Implicit globals:** `DOWNLOAD_DIR` is created in `main` and read by `download_vmware_fusion` without being passed as an argument.
