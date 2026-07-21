# `data` — everything that touches the outside world

**May import:** `domain`, the database package, platform and network packages, `dart:io`.

## What belongs here

Database definition and generated code, repository implementations, row↔entity mappers, balance
derivation and its verifier, period boundary *application*, seed data, migrations, backup
export/import, reporting queries, sync (remote store, adapter, HLC, merge, repair, outbox, worker,
compaction, bootstrap), authentication, and the real `Clock` / `IdGenerator` implementations.

## What must never appear here

| Forbidden | Why |
|---|---|
| Imports from `application/` or `presentation/` | Dependencies point inward only |
| `package:flutter/material` and other UI packages | This layer has no widgets |
| `double`, `float`, `num` on the money path | INV-01, guard **G3** |
| Any update or delete path on `ledger_entries` | INV-03 — the ledger is append-only. Check constraint C-15 backs this at database level |
| Hard deletes on synced tables | INV-10 — deletion is soft, via tombstones |

Guard **G5** enforces that **only this layer** imports the database package.

## Two placements worth knowing

**`sync/adapters/drive/` is the only directory that may import the provider SDK.** Substage 7.2.5
adds a check. This keeps the provider replaceable and the privacy surface auditable (ADR-002).

**`balances/period_boundaries.dart` contains no period arithmetic.** The single authority is
`domain/allocation/period.dart`; this file calls it and applies the result to a query. Implemented
twice, the anchor-day-31-in-February rule drifts and headroom is computed against the wrong window
(ARCHITECTURE §8.4).

## Specification

`docs/SCHEMA.md` — thirteen tables, 22 check constraints, 21 foreign keys, 11 indexes, 28 validation
rules. Stage 4 transcribes it exactly and proves the transcription faithful with a comparison table.
