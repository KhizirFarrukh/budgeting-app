# ADR-003 — Local database

## Status

Accepted — 2026-07-20. Frozen for Stage 4 onward; changing it requires a new ADR.

## Context

The local database is the app's foundation: it holds every financial record, it is the only coupling
between the sync worker and the UI (ARCHITECTURE §3.4), and it must enforce a substantial part of the
correctness design. SCHEMA specifies **22 check constraints and 21 foreign keys** doing real
invariant work — C-15 makes the ledger append-only at database level, C-19 makes a capped sink
impossible, C-21/C-22 pin the reserved columns.

### Evaluation criteria, fixed before candidates

| # | Criterion | Why it matters here |
|---|---|---|
| D1 | **Type-safe queries** | INV-01 forbids floating point in the money path. A compiler that knows a column is `int` is a stronger guarantee than a review that checks it |
| D2 | **Reactive streams** | ARCHITECTURE §3.4 depends entirely on query streams re-emitting when *any* writer commits — including the sync worker, which the UI knows nothing about |
| D3 | **Migration tooling** | NFR-07 requires fixture-based migration tests against every prior schema version |
| D4 | **In-memory instance for tests** | Stage 4's repository tests must be fast and hermetic; substage 4.4.7 requires no filesystem dependency |
| D5 | **Maturity and maintenance signal** | The app is expected to live for years with infrequent maintenance |
| D6 | **Integer-column fidelity** | Money is int64 minor units. The storage type must be genuinely 64-bit integer, with no silent coercion |
| D7 | **Constraint expressiveness** | SCHEMA's 22 check constraints and 21 foreign keys must be enforceable *by the database*, not only by application code |

## Decision

**Drift**, using its code generation, over SQLite.

## Alternatives considered

### sqflite — the serious runner-up

A thin, well-maintained wrapper over SQLite. Full SQL control, no code generation, minimal
dependency surface. Genuinely appealing for a project that values not depending on things.

**Why not, specifically:**

1. **No reactive layer — and that is the mechanism this architecture runs on.** Rows come back as
   `Map<String, dynamic>`; there is no query-stream concept. Building one by hand means every writer
   must remember to publish a change notification. **The writer that forgets is the sync worker** —
   which is precisely the path ARCHITECTURE §3.4 exists to serve, and the failure would be silent:
   the dashboard would simply be stale after a background merge, with no error anywhere. (D2)
2. **No type safety on the money path.** `row['amount_minor'] as int` is a runtime cast. Under
   INV-01, having the compiler know that column is an `int` — and that nothing can hand it a
   `double` — is worth more here than in a typical app. (D1, D6)
3. **Migration testing is entirely manual.** NFR-07 requires a fixture database per prior schema
   version and a harness that migrates and asserts. Drift generates schema snapshots for exactly
   this purpose; with sqflite that harness is bespoke code that itself needs testing. (D3)

sqflite's advantages — no codegen step, smaller dependency — are real. They do not outweigh
hand-building the two mechanisms the design depends on most.

### Isar — excluded on maintenance, and on constraints

**Excluded, for two independent reasons either of which would be sufficient:**

1. **The original author left the project.** Its core is written in Rust, which makes forking
   impractical for a Dart developer — the usual escape hatch when a package is abandoned is closed
   here. ADR-001's criterion C5 (an app maintained infrequently over years) makes this
   disqualifying, and teams that adopted Isar are reportedly writing migration code instead of
   features. (D5)
2. **It is a NoSQL object store, so it cannot express the constraints SCHEMA relies on.** No check
   constraints, no foreign keys. C-15 (a ledger entry may never be tombstoned), C-19 (a sink is
   never capped) and the 21 `ON DELETE RESTRICT` foreign keys would all become application-level
   conventions — enforced by the code that happens to remember, bypassed by any code that does not,
   including a sync merge. That trades a database guarantee for a discipline, which is the trade
   SCHEMA §6.1 exists to refuse. (D7)

Its performance advantages are real and irrelevant: PRD §7.3 shows the Stress profile at 141,000
rows, which SQLite handles comfortably with the indexes of SCHEMA §5.5.

### Hive

Excluded for the same reasons as Isar — same author, same abandonment, plus it is a key-value store
with no query language at all, which makes SCHEMA §5.6's fourteen real queries unimplementable
without loading tables into memory.

## Consequences

### Positive

- Query streams are built in, so ARCHITECTURE §3.4 works by construction rather than by discipline.
- The generated schema is type-safe, so a money column cannot be read as a floating-point value.
- `NativeDatabase.memory()` gives Stage 4 fast, hermetic repository tests with no filesystem.
- Drift generates schema snapshots per version, which is exactly the input NFR-07's fixture-based
  migration harness needs.
- It is SQLite underneath, so every check constraint and foreign key in SCHEMA §5 is enforceable as
  written, and `PRAGMA foreign_keys = ON` (§5.1) applies normally.

### Negative, and what is done about each

| Consequence | Mitigation |
|---|---|
| A code generation step, which can break | Substage 3.3.3 proves the generator runs end to end against a placeholder **before** any real schema depends on it |
| Generated code is a large diff surface | Substage 3.3.4 decides commit-or-gitignore explicitly and applies it consistently |
| Drift's own abstractions could leak into the domain | Guard G5: only `lib/data/` may import the database package. Repository interfaces are expressed entirely in domain types (substage 4.4.1) |
| Foreign keys are still off by default | SCHEMA §5.1 requires `PRAGMA foreign_keys = ON` on every connection open, proven by the orphan-insert test at 4.3.3 |

### The exit plan

The important property: **Drift stores data in an ordinary SQLite file with an ordinary SQL schema.**

If Drift were abandoned, the migration path is to sqflite against **the same database file** —
hand-written mappers replacing generated ones, the same SQL, the same constraints, the same indexes.
**No data migration is required**, because the data was never in a proprietary format. The work is
bounded to `lib/data/`, since the domain layer sees only repository interfaces (ARCHITECTURE §2.1).

That is a meaningfully cheaper exit than Isar or Hive would offer, where the storage format is the
library's own and leaving means exporting and re-importing every user's data.

## Date

2026-07-20
