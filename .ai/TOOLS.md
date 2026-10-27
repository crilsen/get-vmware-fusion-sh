# Tools

The rules behind these lists live in `.ai/GUARDRAILS.md`.

## Current environment

- Host: macOS 26.2 (build 25C56), arm64.
- Shell: `/bin/bash` 3.2.57 (only `bash` on the machine), `zsh` is the login shell.
- Available and used: `curl`, `grep`, `sed`, `awk`, `sort`, `find`, `hdiutil`, `xattr`, `defaults`, `cp`, `mv`, `mkdir`, `basename`, `dirname`, `head`, `open`, `uname`.
- Available and recommended to add: `codesign`, `spctl`, `shasum`/`sha256sum` (all present in `/usr/bin` / `/usr/sbin`).
- Installed for validation: `shellcheck` 0.11.0.
- No package manager, task runner, CI, or container tooling is used by this project.
- No credentials are required by the script or by these checks. Never store secrets in this file.

## Allowed without additional authorization

- Read and search repository files.
- `bash -n get-vmwarefusion.sh`, `shellcheck -S warning get-vmwarefusion.sh`.
- `bash get-vmwarefusion.sh -h` (help path only).
- Read-only inspection: `defaults read` on an installed bundle, `hdiutil info`, `ls -l`, `git status` once the repo exists.
- Public, read-only HTTP GETs of `archive.org` listing pages to verify the scraper contract.
- Scoped edits to `get-vmwarefusion.sh` and `.ai/` context files.

## Requires explicit authorization

- Running the script end to end, in any mode that mounts a DMG, writes to `~/Downloads`, or executes `rm -rf` / `cp -R` under `/Applications`.
- Installing, upgrading, downgrading, or removing `/Applications/VMware Fusion.app`.
- `xattr -d`/`-dr` on any downloaded file or installed app.
- Downloading multi-hundred-megabyte DMGs (bandwidth), or changing the download directory.
- Adding a new download mirror, or pointing the script at anything other than the recorded `archive.org` path.
- Deleting files in `.ai/` (notably the unused infra workflows) — history exists only from the initial commit of 2026-10-27, so treat deletions as permanent and confirm first.

## Network egress

One host: `archive.org` (redirects to `ia######.us.archive.org`). No telemetry, no analytics, no other endpoints are contacted by the script or by the validation flow.

## MCP servers and external tools

| Tool or MCP server | Purpose | Allowed | Restricted |
| --- | --- | --- | --- |
| `opencode` (resources/skills/models) | Harness introspection | read-only | session mutation |

MCP servers are configured by the harness, not by this repository. Record only what exists; never record endpoints, tokens, or credentials.

## Technology-specific guidance

| Technology | Safe | Restricted |
| --- | --- | --- |
| Bash scripts | `bash -n`, `shellcheck`, `-h` smoke test | executing install paths |
| DMG handling | `hdiutil info`, `hdiutil attach` in a scratch mount point with an explicit `-mountpoint` | `rm -rf` of installed apps, `xattr` quarantine removal |
| macOS apps | `defaults read`, `codesign -dv` | replacing bundles in `/Applications` |
