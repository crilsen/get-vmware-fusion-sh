# Decision Records

Durable, meaningful choices. Two types:

- **ADR** — architecture decision: how the system is structured.
- **TDR** — technology decision: stack, library, provider, protocol, or tooling.

Status lifecycle: `Proposed → Accepted → Superseded | Deprecated`. ADR and TDR use separate ID sequences.

## Modes

Choose one mode per project and record the choice at adoption. The index below is used in both modes.

**Chosen mode: simple** (2026-10-27). This repository holds one shell script, so records stay inline in this file. `docs/decisions/` is not created.

- **Simple (default):** entries live inline in this file. Best for small projects and up to roughly 15–20 active records.
- **Scale:** one file per record under `docs/decisions/`, named `ADR-NNN-<slug>.md` or `TDR-NNN-<slug>.md`. This file stays as the index only.

Migrate from simple to scale when the inline log gets unwieldy. Keep IDs stable during migration.

## Entry format

```text
## ADR-NNN / TDR-NNN — Title
Type: ADR | TDR
Status: Proposed | Accepted | Superseded | Deprecated
Date: YYYY-MM-DD
Owners: <who>
Supersedes: <ID or none>

Context:
...

Decision:
...

Reasoning:
...

Consequences:
...
```

## Index

| ID | Type | Title | Status | Date | File |
| --- | --- | --- | --- | --- | --- |
| - | - | - | - | - | - |

## Records

In simple mode, add entries inline here. In scale mode, keep only the index above and create files under `docs/decisions/`.

_None yet._

This repository predates the context layer and has no recorded design history. The observed design of the script is documented as facts in `ARCHITECTURE.md`; no ADR is backfilled from it. The only adoption choices recorded outside this file are the annotation language (English, `.ai/HANDOFF.md`) and automatic context maintenance (`.ai/HANDOFF.md`), both declared by the owner on 2026-10-27.

Do not backfill invented history. Record decisions that are observed, expressly documented, or approved during future work.

The template's own design rationale lives in `docs/design.md`, which is **not present** in this repository (the template was copied without `docs/`).
