# Project state — stage by stage

Accurate as of commit `8a68090`, 2026-08-28.

Legend: ✅ complete and verified · 🟡 code complete, **not verified** · ⬜ not started

---

## Stages

| # | Stage | Substages | Status | Gate |
|---|---|---|---|---|
| 1 | Requirements Gathering & Documentation | 8 | ✅ | approved |
| 2 | System Design & Architecture | 13 | ✅ | approved |
| 3 | Project Scaffolding | 9 | ✅ | approved |
| **4** | **Core Data Layer Implementation** | **11** | **🟡 in progress — 7 of 11** | not reached |
| 5 | Core Business Logic — Auto-Distribution Engine | 10 | ⬜ | |
| 6 | UI Implementation — Core Flows | 12 | ⬜ | |
| 7 | Cloud Sync Implementation | 11 | ⬜ | |
| 8 | Reports & Insights | 8 | ⬜ | |
| 9 | Testing & QA Pass | 8 | ⬜ | |
| 10 | Polish & Release Prep | 8 | ⬜ | |

---

## Stage 4 — substage detail

| # | Substage | Status | Commit |
|---|---|---|---|
| 4.1 | The Money type and core value types | ✅ | `d2d17fd` |
| 4.2 | Domain entities, enums and invalid-state prevention | ✅ | `374b696` |
| 4.3 | Database schema definition and code generation | ✅ | `3fef4db` |
| 4.4 | Repository interfaces and CRUD implementation | 🟡 | `2c34a1a` |
| 4.5 | Append-only ledger and transactional writes | 🟡 | `86d6f25` |
| 4.6 | Balance derivation and cache verification | 🟡 | `9fb427e` |
| 4.7 | Seed data, suggested categories and the sink | 🟡 | `8a68090` |
| **4.8** | **Configuration validators and cycle detection** | **⬜ ← NEXT** | |
| 4.9 | Migrations, export and backup | ⬜ | |
| 4.10 | Data layer test suite and performance smoke test | ⬜ | |
| 4.11 | Data layer documentation and gate preparation | ⬜ | |

Detailed evidence for every substage lives in `docs/reports/STAGE_4_WORKLOG.md`. That file is the
record; this table is the index.

---

## What exists in the codebase now

### `lib/domain/` — pure Dart, no Flutter, no I/O (guards G1, G5)

```
domain/
├── money/          Money, BasisPoints, Currency, MoneyFormat, Clock, IdGenerator   [4.1]
├── entities/       11 immutable entities, private ctors, Result-returning create() [4.2]
├── allocation/
│   └── period.dart Period boundary authority — anchor-day clamping (V-20)          [4.6]
├── repositories/   8 interfaces + failure taxonomy + query value objects       [4.4–4.6]
└── result.dart     Result<T, F> — Success | Failure
```

**Eight repository interfaces**, all expressed in domain types only:
`CategoryRepository` (groups, categories, redirect targets), `AccountRepository`, `RuleRepository`,
`SettingsRepository`, `LedgerRepository`, `IncomeEventRepository`, `SpendingRepository`,
`BalanceRepository`.

### `lib/data/` — the only layer that may import Drift (guard G5)

```
data/
├── database/       13 tables transcribed from SCHEMA.md, indexes, FK enforcement    [4.3]
├── mappers/        row ↔ entity, both directions adjacent, per entity family   [4.4, 4.5]
├── repositories/   Drift implementations + repository_support + ledger_writer  [4.4, 4.5]
├── balances/       balance_sql, balance_queries, balance_verifier, period_boundaries [4.6]
└── seed/           seed_data (19 suggestions + 2 sinks), seeder                     [4.7]
```

### `test/`

```
test/
├── domain/         money, entities, result, period, repository interface purity
├── data/           repositories (7 files), mappers round-trip, balances, seed
└── support/        test_database, fakes (clock, id gen), builders (config, movement),
                    movement_fixture, vector_loader
```

### `tool/`

- `guards/guards.dart` — the six invariant guards G1–G6
- `domain_purity_check.dart` — compiles every `lib/domain` library on the bare Dart VM. **Its
  completeness assertion fails if a new file under `lib/domain` is not imported by it** — remember
  to extend it whenever you add one.
- `check.ps1` — the single command that runs everything

---

## Architectural facts worth knowing before you touch anything

**Money is `int` minor units. Always.** Guard G3 bans the tokens `double`, `float` and `num` from
`lib/domain` and `lib/data` outright — including intermediates, including display-only values.

**Time is injected.** Guard G4 bans `DateTime.now()` outside `lib/data/clock_impl.dart`. Every
repository that needs a timestamp takes a `Clock`.

**The allocation engine is stricter still.** Guard G2 bans `async`, `await`, `Future`, `Stream`,
`DateTime.now` and `Random` anywhere under `lib/domain/allocation/`. The engine's entire world
arrives in its request object.

**Deletion is soft everywhere in configuration** (INV-10) — except the ledger, which cannot be
deleted at all.

**The ledger is append-only** (INV-03), enforced six ways: no update/delete method on the interface,
no `copyWith` on `LedgerEntry`, one insert-shaped companion, a single `ledger_writer.dart` chokepoint,
constraint C-15, and `insertOrIgnore` that skips rather than overwrites. There is a design test —
`test/data/repositories/append_only_design_test.dart` — that asserts each of those routes is shut.

**Balances are derived** (INV-04). `balance_cache` is a device-local, disposable cache maintained
inside the same transaction as the ledger write, and audited by a two-tier
recompute-and-compare verifier.

**Sync stamps are not invented by repositories.** Callers supply complete `SyncFields`. The HLC is
Stage 7's to implement; a placeholder minted now would be a second, wrong source of ordering.

---

## Documents amended after their approving gate

Each required an ADR, per the manifest's `sdlc_discipline`.

| ADR | Amends | Why |
|---|---|---|
| ADR-005 | `SCHEMA.md` — adds `repair_log` | §6.8 required a durable repair log; no table held it |
| ADR-006 | `SCHEMA.md`, `ALLOCATION_ALGORITHM.md` — cascade redirect | FR-16; replaces a single redirect column with a `redirect_targets` table |
| **ADR-007** | `SCHEMA.md` §3.12 — adds `balance_cache.entry_count` | §7.1's cheap verifier tier compares against a column §3.12 never declared |

`ARCHITECTURE.md` §2.2's repository table is **three rows stale** and has *not* been amended — see
[`TODO.md`](TODO.md), it is a 4.11 documentation task.
