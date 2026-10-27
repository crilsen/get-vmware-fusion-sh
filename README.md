# get-vmwarefusion

Direct download, install, and update of **VMware Fusion** on macOS from the command line, using the Internet Archive mirror of the Broadcom/VMware installers — no browser, no login, no hunting for the latest build.

It finds the newest build available in the mirror, compares it against what is installed, downloads it to `~/Downloads`, and — optionally — replaces the app in `/Applications`.

> **Status: usable, but not safe to install with.** The script now runs directly (`./get-vmwarefusion.sh`), but the install path still deletes `/Applications/VMware Fusion.app` before copying the new build and removes the Gatekeeper quarantine flag. Read [Known issues](#known-issues) before using `-i`.

## Requirements

- macOS (installation is macOS-only; the download path is platform-agnostic).
- Bash — the system `/bin/bash` 3.2 is enough.
- `curl`, `grep`, `sed`, `awk`, `sort`, `find`, `hdiutil`, `xattr`, `defaults` (all shipped with macOS).
- Network access to `archive.org`.

## Usage

```bash
./get-vmwarefusion.sh                    # find latest, ask, download to ~/Downloads
./get-vmwarefusion.sh -i                 # download + install/update, no prompts
./get-vmwarefusion.sh -i -f              # force reinstall even if already current
./get-vmwarefusion.sh -d                 # download only, even if -i is given
./get-vmwarefusion.sh -h                 # usage
./get-vmwarefusion.sh -t ~/Downloads/VMware-Fusion-26H1u1-25689522_universal.dmg
```

Invoking it as `bash get-vmwarefusion.sh …` also works; `sh get-vmwarefusion.sh` does **not** (the script uses Bash-only constructs and will fail at parse time).

| Flag | Meaning |
| --- | --- |
| `-y` | Skip the download confirmation prompt |
| `-i` | Install after download; implies `-y` |
| `-d` | Download only; wins over `-i` |
| `-f` | Force install even when the same version is installed |
| `-t <dmg>` | Install an existing local DMG, skipping discovery and download |
| `-h` | Print usage and exit `0` |

`-t` is named "test" but performs a real installation. There is no `--version` or dry-run mode yet; unknown flags print the usage block and exit `1`.

### If you get `permission denied`

```text
zsh: permission denied: ./get-vmwarefusion.sh
```

The file is missing its execute bit. A `git clone` keeps it (`100755` in the index), but copies made by download, `zip`, AirDrop, or some sync clients drop the mode. Fix it once:

```bash
chmod +x get-vmwarefusion.sh
```

`chmod 755` is equivalent. Then run it as `./get-vmwarefusion.sh` — or skip the mode entirely with `bash get-vmwarefusion.sh`, which never needs the execute bit.

Other symptoms and their cause:

| Error | Cause | Fix |
| --- | --- | --- |
| `permission denied` | No execute bit | `chmod +x get-vmwarefusion.sh` |
| `Direct: command not found` (old copies only) | A line of prose sat above the shebang, so `sh` was used as fallback | Update to a current checkout — fixed in `3f2edf6` |
| `syntax error near unexpected token '<'` | Ran through `sh` or `dash` | Use `./get-vmwarefusion.sh` or `bash get-vmwarefusion.sh` |
| `curl: (33) … 416` (older copies) | Resuming an already-complete file | Delete the partial `.dmg` in `~/Downloads` and run again |

## How the version is chosen

1. `GET https://archive.org/download/vmwareworkstationarchive/Fusion/` and collect the major-version folders (`8.x`, `10.x`, `11.x`, `12.x`, `13.x`, `25H2`, `26H1` as of 2026-10-27).
2. Fetch each folder and parse the `.dmg` links, extracting the version from both naming schemes:
   - semver: `VMware-Fusion-13.6.4-24832108_universal.dmg`
   - year-half: `VMware-Fusion-25H2u1-25219963_universal.dmg`, `VMware-Fusion-26H1u1-25689522_universal.dmg`
3. Normalize every version to a four-field tuple and take the maximum:

   | Raw | Normalized |
   | --- | --- |
   | `13.6.4` | `13.6.4.0` |
   | `13.6` | `13.6.0.0` |
   | `25H2` | `25.2.0.0` |
   | `26H1u1` | `26.1.0.1` |

4. Compare with the installed bundle (`defaults read … CFBundleShortVersionString`) and with the recorded state (below), then decide: install, update, update-same-version-new-build, or up to date.

## Files it touches

| Path | Purpose |
| --- | --- |
| `~/Downloads/VMware-Fusion-<version>-<build>_universal.dmg` | Download target; reused if the file already exists, never deleted |
| `~/.local/.vmwarefusion_last_version` | Records `version-build` of the last install performed by this script |
| `/Applications/VMware Fusion.app` | Replaced in place when installing |

The DMG is mounted read-write for the duration of the install, the `.app` is copied out, and the image is detached.

## Known issues

Documented in detail, with line references and an ordered remediation plan, in [`.ai/TASKS.md`](.ai/TASKS.md).

- **Cannot run:** ~~the shebang was displaced by a line of prose and the file was not executable~~ — fixed 2026-10-27; the shebang is on line 1 and the file is `0755`.
- **Install is destructive before it is safe:** `/Applications/VMware Fusion.app` is removed *before* the new copy is attempted, with no staging, backup, or rollback.
- **No payload verification:** the DMG is fetched from a third-party mirror without signature, hash, or size check, and `com.apple.quarantine` is stripped from both the DMG and the installed app — that removes Gatekeeper from the equation.
- **Possible reinstall loop:** the archive names builds `26H1u1` while the app bundle may report `26H1`; if so, the version comparison never converges and every run triggers an "update".
- **Truncated downloads are reusable:** a partial DMG left by a failed attempt is treated as a valid existing file on the next run.
- **Licence-key link in the output:** the success message points at a third-party repository of VMware licence keys. It should point at the official Broadcom download page instead.

## Security notes

Treat this as a convenience wrapper around an **untrusted** mirror, not as a supply-chain-safe installer. Before using it against a real `/Applications`:

- verify the vendor signature yourself — `codesign --verify --deep --strict …` and `spctl --assess --type execute …` on the mounted bundle;
- prefer the official Broadcom download portal or `brew install --cask vmware-fusion`, which verifies the vendor's signature during install;
- never run it with elevated privileges, and keep a copy of your current app before replacing it.

VMware Fusion is proprietary software. Downloading its installers from a mirror is your responsibility; Broadcom has offered Fusion Pro free for personal use since late 2024 — check the current terms for your case.

## Repository layout

```text
get-vmwarefusion.sh   the script (single self-contained Bash file)
README.md             this file
AGENTS.md             entry point for coding agents
.ai/                  portable agent context: architecture, conventions, tasks, handoff
```

`.ai/` exists so any agent — or any person returning later — can resume without chat history. It records observed facts, decisions, and what is still unknown; it is kept current automatically. Start with [`.ai/PROJECT.md`](.ai/PROJECT.md), then [`.ai/HANDOFF.md`](.ai/HANDOFF.md).

## Credits

- **Original idea:** [jetfir3's gist](https://gist.github.com/jetfir3/6b28fd279bbcadbae70980bd711a844f) — this script is a rewrite and extension of that approach.
- **Installer mirror:** the [Internet Archive `vmwareworkstationarchive`](https://archive.org/details/vmwareworkstationarchive) collection, which hosts the Fusion disk images used here. All binaries belong to Broadcom Inc. (formerly VMware, Inc.); this repository redistributes none of them.
- **VMware Fusion** is a trademark of Broadcom Inc. This project is unofficial and not affiliated with, endorsed by, or supported by Broadcom or VMware.
- **Author and maintainer:** Cristiano Nilsen ([@crilsen](https://github.com/crilsen)).

## License

No license file is present yet, so the default applies: all rights reserved. If this script is meant to be reusable, add an explicit license (MIT is the usual choice for a utility like this) — that decision is the maintainer's, not something to assume.
