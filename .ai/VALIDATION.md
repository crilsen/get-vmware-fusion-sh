# Validation

## Completion rule

Before completion, run every applicable check below and report each as **Validated**, **Partially validated**, or **Not validated**, with the reason. Never claim a check that did not run. Installing, replacing, or removing anything under `/Applications` is **not** part of routine validation and requires explicit user authorization.

## Available checks

No test suite, linter configuration, or CI exists. The checks that do exist, in order of cost:

### 1. Shebang and mode (cheap; both currently pass)

```bash
head -1 get-vmwarefusion.sh          # must be the shebang, not prose
ls -l get-vmwarefusion.sh            # must be executable for direct use
```

`bash -n` does **not** catch a displaced shebang; line 1 is a syntactically valid simple command. This is why the original defect survived a syntax check. Fixed 2026-10-27 — keep both checks green.

### 2. Bash syntax

```bash
bash -n get-vmwarefusion.sh
```

Expected: silent success. `sh -n get-vmwarefusion.sh` intentionally **fails** on the process substitution at line 183 — that is the signal that the script is Bash-only and must never be executed through `sh`.

### 3. Static analysis

```bash
shellcheck -S warning get-vmwarefusion.sh
```

ShellCheck 0.11.0 is installed. Baseline at 2026-10-27 after the shebang fix: `SC2034` twice (`SORT_CMD`, `SORT_UNIQUE_CMD` unused, lines 76–77) and `SC2010` (`ls /Volumes | grep`, line 381). `SC2148` (missing shebang) is resolved. Any **new** finding is a regression.

### 4. CLI smoke test (no network, no install)

```bash
./get-vmwarefusion.sh -h     # usage, exit 0
./get-vmwarefusion.sh -z     # usage, exit 1
```

Both must print the usage block with `$0` in the examples and no stray error from line 1.

### 5. Version logic (offline, pure functions)

No harness exists; validate by sourcing the script's functions in a scratch shell or by reproducing the mapping table:

| Input | Expected `normalize_version` |
| --- | --- |
| `13.6.4` | `13.6.4.0` |
| `13.6` | `13.6.0.0` |
| `25H2` | `25.2.0.0` |
| `26H1u1` | `26.1.0.1` |
| `garbage` | `0.0.0.0` |

And `version_greater_than "26H1u1" "25H2u1"` → true, `version_greater_than "13.6.4" "13.6.4"` → false.

### 6. Source discovery (network, read-only)

```bash
curl -s -f -L --max-time 25 \
  "https://archive.org/download/vmwareworkstationarchive/Fusion/" \
  | grep -oE '<a href="([0-9]+\.x|[0-9]+H[12])/"' | sort -u
```

Last verified 2026-10-27: returns `8.x 10.x 11.x 12.x 13.x 25H2 26H1`. A different shape means the scraper is broken.

### 7. Integrity and install-path review (authorization required)

Changes to `install_vmware_fusion` must be reviewed statically and, if executed at all, only with an explicit go-ahead and a known-good DMG. Required properties of any future version:

- `codesign --verify --deep --strict` and `spctl --assess --type execute` pass before `/Applications` is touched.
- The existing app is preserved until the new copy is verified; rollback exists for every failure branch.
- A truncated or mismatched DMG (size/checksum) is rejected, not installed.
- The DMG is detached on every exit path (`trap ... EXIT INT TERM`).

## Not validated

- Actual download of a ~500 MB DMG and a real install/upgrade cycle (would mutate `/Applications`; not authorized).
- Whether the installed bundle version string includes the `uN` suffix (`defaults read "/Applications/VMware Fusion.app/Contents/Info.plist" CFBundleShortVersionString` on a 26H1u1 install would settle it).
- Behavior on Intel Macs and on macOS versions older than 26.2.
