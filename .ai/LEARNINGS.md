# Learnings

Append-only buffer of reusable, non-obvious learnings captured while working, so future sessions and tools do not rediscover them. This is not task state (`TASKS.md`), not a session handoff (`HANDOFF.md`), and not a durable decision record (`DECISIONS.md`).

## How to use

- Append one entry per learning. Do not rewrite or delete entries; to correct one, mark it `superseded` and add a new entry.
- Capture only learnings that are non-obvious and likely to recur. Skip anything already stated in `CONVENTIONS.md`, `DECISIONS.md`, `TOOLS.md`, or `VALIDATION.md`.
- Keep each entry short and evidence-based. Prefer `observed` facts over speculation.
- This file is a buffer, not a permanent home: promote durable learnings and keep the entry as a breadcrumb.

## Entry format

```text
### L-001 — <short title>
Date: YYYY-MM-DD
Status: active | superseded | promoted
Confidence: observed | inferred
Scope: repo | <path-or-glob> | <technology>
Context: <what was being done>
Evidence: <file:line, command output, or concrete observation>
Pattern / rule: <the reusable takeaway>
Promotion: none | CONVENTIONS.md | DECISIONS.md#ADR-nnn | TOOLS.md | VALIDATION.md
```

## Promotion rules

- Recurring pattern → `CONVENTIONS.md`
- Durable architectural choice → `DECISIONS.md` (ADR), cross-referenced here
- Safe or restricted command rule → `TOOLS.md`
- Completion or validation check → `VALIDATION.md`

After promotion, set the entry to `Status: promoted` and keep it as a breadcrumb; do not duplicate the rule body.

## Compaction

- Keep at most 40 active entries. When exceeded, consolidate related entries, promote what is durable, and mark the rest `superseded`.
- Compaction means summarizing and promoting, not erasing history. Record the compaction in `HANDOFF.md`.

## Entries

### L-001 — `bash -n` does not catch a displaced shebang
Date: 2026-10-27
Status: promoted
Confidence: observed
Scope: get-vmwarefusion.sh
Context: Reviewing a script whose first line was prose and whose `#!/usr/bin/env bash` sat on line 3.
Evidence: `bash -n get-vmwarefusion.sh` exits 0; `bash get-vmwarefusion.sh -h` prints `line 1: Direct: command not found`; `./get-vmwarefusion.sh` gives `zsh: permission denied` (exit 126, mode 0400); `sh -n` fails at line 182.
Pattern / rule: A shebang check is a separate gate from a syntax check. Always inspect `head -1` **and** the execute bit; a syntax checker will happily pass a file that cannot be executed.
Promotion: VALIDATION.md

### L-002 — macOS ships only Bash 3.2 and BSD sort
Date: 2026-10-27
Status: promoted
Confidence: observed
Scope: get-vmwarefusion.sh, macOS 26.2
Context: Assessing whether the version-sorting logic could rely on `sort -V`.
Evidence: `/bin/bash --version` → `3.2.57`; no other `bash` on the machine; `sort -V` is GNU-only, so `setup_sort` fallback flags are the only portable option — and they are currently unused dead code (shellcheck SC2034).
Pattern / rule: Assume Bash 3.2 and BSD userland on this project. Verify a GNU flag's availability before using it, and delete capability-detection code that nothing consumes.
Promotion: CONVENTIONS.md

### L-003 — The archive.org scraping contract still holds, but only by luck
Date: 2026-10-27
Status: active
Confidence: observed
Scope: get-vmwarefusion.sh
Context: Checking whether the HTML regexes still match the live mirror.
Evidence: `GET /Fusion/` yields `<a href="8.x/"> … <a href="26H1/">`; folder pages yield `VMware-Fusion-13.6.4-24832108_universal.dmg`, `VMware-Fusion-25H2u1-25219963_universal.dmg`, `VMware-Fusion-26H1u1-25689522_universal.dmg`; `26H1u1` is 521,403,629 bytes so `--max-time 300` truncates slow downloads.
Pattern / rule: The parser depends on undocumented HTML, so re-run the `curl | grep -oE '<a href="([0-9]+\.x|[0-9]+H[12])/"'` probe before blaming the script for "no versions found". Version names changed scheme mid-project (`13.x` → `25H2`/`26H1` + `uN`), so any comparison logic must stay scheme-agnostic.
Promotion: none
