# PookieBudget — architecture

| | |
|---|---|
| **Status** | In progress — Stage 2 |
| **Derived from** | `docs/PRD.md` (approved Stage 1), `00_project_manifest.json` |
| **Sections assembled** | 1, 2, 4, 8, 10 (2.2); 3 (2.1) |
| **Sections pending** | 5, 6 (2.9); 7, 9 (2.12) |

Companion documents: `SCHEMA.md` (data design), `ALLOCATION_ALGORITHM.md` (the engine),
`NAVIGATION.md` (screens and flow), `decisions/ADR-*.md`.

**Vocabulary.** This document and every later design document use the glossary terms of PRD §9.
Product language (PRD §9.1's left column — "goal", "target", "room", "catch-all") is for the user
interface and must not appear here.

---

## 1. Layers

Four layers. The division exists to keep one property true under pressure: **the allocation engine
must be unit-testable with no Flutter, no database and no clock** (INV-08). A boundary that is only
a convention erodes within two stages, so this one is visible in the filesystem (§4) and checked
mechanically (§2.3).

### 1.1 What belongs in each layer

**`domain`** — pure Dart. No Flutter, no I/O, no clock, no global state.

- Value types: `Money`, `Currency`, `BasisPoints`
- Entities: category group, category, account, distribution rule version, rule line, income event,
  allocation, ledger entry, spending transaction, app settings
- Enumerations, all serialised as stable strings
- **The allocation engine** — contracts, split, headroom, worklist, period, override, reversal
- Configuration validators and redirect cycle detection
- Repository **interfaces**, expressed entirely in domain types
- The `Result` type used for expected failures
- The `Clock` and `IdGenerator` **interfaces** (not their implementations)

**`data`** — everything that touches the outside world.

- Database definition, tables, connection, generated code
- Repository implementations and row↔entity mappers
- Balance derivation queries and the recompute-and-compare verifier
- Period boundary computation shared with the engine (§8.4)
- Seed data and the seeder
- Migrations and the backup export/import
- Reporting aggregation queries (Stage 8)
- Sync: remote store abstraction, provider adapter, HLC, merge, repair, outbox, worker, compaction,
  bootstrap
- Authentication
- Real implementations of `Clock` and `IdGenerator`

**`application`** — orchestration.

- Use cases: complete onboarding, preview allocation, confirm income, reverse income, save category,
  save account, log spending, run sync
- Providers exposing repository streams and use-case results
- State notifiers for scope, onboarding progress, the in-flight income draft, sync status

**`presentation`** — Flutter only.

- Screens and widgets
- Theme, design tokens, the business-scope treatment
- The locale-aware money formatter
- Router

### 1.2 The rule that decides placement

If a piece of code could be wrong about *money*, it belongs in `domain`. If it could be wrong about
*storage or the network*, it belongs in `data`. If it could be wrong about *sequencing*, it belongs
in `application`. If it could be wrong about *appearance*, it belongs in `presentation`.

---

## 2. The dependency rule

**Dependencies point inward only.** No layer may import from a layer to its right.

```
domain  ←  data  ←  application  ←  presentation
```

### 2.1 What each layer may import

| Layer | May import | May **not** import |
|---|---|---|
| `domain` | Dart core libraries only (`dart:core`, `dart:math`, `dart:collection`, `dart:convert`) | `package:flutter/*`, `dart:io`, `dart:ui`, the database package, any HTTP or Google package, and `data`, `application` or `presentation` |
| `data` | `domain`; the database package; platform and network packages; `dart:io` | `application`, `presentation`, `package:flutter/material` and other UI packages |
| `application` | `domain`; `data` **repository interfaces and implementations for wiring only**; Riverpod | `presentation`; widget libraries |
| `presentation` | `application`; `domain` types **for display only**; Flutter | `data` — no direct database, repository, sync or network access from a widget |

Two clarifications that would otherwise be argued about later:

- **`presentation` importing `domain`** is permitted so a widget can hold a `Money` or a `Category`
  for rendering. It may not call a domain *validator* or the *engine* — those are reached through
  use cases, so that the preview and the confirmed write cannot diverge.
- **`application` importing `data`** is permitted only to bind an implementation to an interface at
  the composition root. Use-case logic depends on interfaces.

### 2.2 What the domain layer needs injected

Because `domain` performs no I/O and reads no clock, everything it needs arrives from outside:

| Abstraction | Interface in | Real implementation in | Fake in |
|---|---|---|---|
| `Clock` | `domain/money/clock.dart` | `data` | `test/fakes` (S03.8.2) |
| `IdGenerator` | `domain/money/id_generator.dart` | `data` | `test/fakes` (S03.8.3) |
| `CategoryRepository` | `domain/repositories/` | `data/repositories/` | in-memory database (S04.4.7) |
| `AccountRepository` | `domain/repositories/` | `data/repositories/` | in-memory database |
| `RuleRepository` | `domain/repositories/` | `data/repositories/` | in-memory database |
| `LedgerRepository` | `domain/repositories/` | `data/repositories/` | in-memory database |
| `IncomeEventRepository` | `domain/repositories/` | `data/repositories/` | in-memory database |
| `SettingsRepository` | `domain/repositories/` | `data/repositories/` | in-memory database |

**The allocation engine receives none of these.** It is a pure function whose entire world arrives in
its request object — balances, rules, the evaluation timestamp, the period definition. It does not
hold a repository, and does not hold a `Clock`. This is stronger than the rest of the domain layer,
which may hold injected interfaces.

### 2.3 Enforcement — mechanical, not conventional

Stage 3 substage 3.4 implements these. Each must be **demonstrated failing on a deliberate
violation**, with the failure output captured in the Stage 3 report; a guard that has never failed
has never been tested.

| # | Guard | Fails when |
|---|---|---|
| G1 | **Layering** | Any file under `lib/domain/` imports `package:flutter`, `dart:io`, `dart:ui`, the database package, or any path under `lib/data/`, `lib/application/`, `lib/presentation/` |
| G2 | **Engine purity** | Any file under `lib/domain/allocation/` imports anything beyond Dart core, or contains `async`, `await`, `Future`, `Stream`, or `DateTime.now` |
| G3 | **Money type** | `double`, `float` or `num` appears in any file under `lib/domain/` or `lib/data/` outside an allow-list justified in `DEVELOPMENT.md` |
| G4 | **Clock** | `DateTime.now()` appears outside the `Clock` implementation |
| G5 | **Database containment** | Any file outside `lib/data/` imports the database package |
| G6 | **Telemetry** | A known analytics, crash-reporting or advertising package appears anywhere in the *resolved* dependency tree, not merely the direct dependencies |

**What these guards cannot catch, stated so nobody assumes otherwise.** G1–G6 check imports and
tokens. They cannot detect a widget reading an application-layer provider it has no business
reading, because both are in permitted layers. That gap is closed by two non-import mechanisms:
repository providers are declared private to the application layer, and substage 6.1.1 adds an
explicit check that no widget constructs a repository or touches the database. Substage 2.2 does not
treat the import guards as sufficient on their own.

---

## 3. State management

Decided in substage 2.1. Full reasoning, alternatives and consequences: **ADR-001**.

### 3.1 The decision

**Riverpod (3.x line), with code generation for providers.**

The application layer is composed of providers exposing repository streams and use-case results.
Widgets read providers. No widget constructs a repository, opens the database, or calls the
allocation engine directly.

### 3.2 What is held in state, and what is not

| Held in the state layer | Never held — re-derived on demand |
|---|---|
| Active scope (personal / business) | Every category balance |
| Onboarding progress | Every account total |
| The in-flight income draft: amount, label, date, manual overrides | Every report figure |
| Transient UI state: filters, selected period, sort order | Every ceiling progress value |
| Sync status | Anything else derived from ledger entries |

INV-04 makes a balance a derived value. Caching one in a provider would create a second copy that no
recompute-and-compare path verifies. Where a cache is required for performance — and PRD §7.4 shows
it is, at the Heavy profile — it lives in the data layer with the verification path specified in
substage 2.4.5, never in the state layer.

### 3.3 Where use cases live and how they are invoked

Use cases live in the **application** layer. Each orchestrates a sequence — gather balances, call the
engine, write atomically — and returns a typed result the UI maps to a message. A use case contains
no allocation arithmetic; the engine is the only thing that computes a split.

Invocation path, with no step skippable:

```
Widget → (reads) Provider → (invokes) Use case → Repository interface  → Data layer
                                              ↘ Allocation engine (pure, domain)
```

Repository providers are declared private to the application layer. Presentation reaches them only
through use-case providers, so a widget cannot acquire a repository even accidentally.

### 3.4 How a background sync mutation reaches a visible screen

The case the decision turned on. From Stage 7, the sync worker writes to the database while a screen
is visible; INV-06 forbids blocking the UI and FR-13 requires the change to appear without a manual
refresh.

```mermaid
sequenceDiagram
    participant Sync as Sync worker (data)
    participant Repo as Repository (data)
    participant DB as Database
    participant SP as StreamProvider (application)
    participant UI as Dashboard (presentation)

    Note over Sync,UI: The sync layer holds no reference to the UI at all.
    Sync->>Repo: apply merged records
    Repo->>DB: write (transaction)
    DB-->>Repo: change notification on affected tables
    Repo-->>SP: query stream re-emits
    SP-->>UI: providers emit; watching widgets rebuild
```

**The database is the only coupling.** The sync worker does not know the presentation layer exists,
does not publish an event to it, and cannot block it. Any writer — user action, sync merge, restore
from backup, migration repair — propagates identically, because they all write through the same
repository API.

Verification obligations this creates:

| Stage | Obligation |
|---|---|
| S04.4.4 | A test that mutates through a second code path and asserts the stream emits |
| S06.1.3 | The same assertion at screen level: a non-UI mutation updates a visible screen |
| S06.8.5 | Every dashboard figure driven by a reactive query, including for future sync writes |

### 3.5 Enforcement

The layering guard (substage 3.4.4) checks imports, which catches a widget importing the data layer
but **not** a widget reading an application-layer provider it should not. That gap is closed
separately:

| Rule | Enforced by |
|---|---|
| `domain` imports no Flutter, no `dart:io`, no other layer | CI layering guard, S03.4.4 — demonstrated failing on a deliberate violation |
| No widget constructs a repository or touches the database | S06.1.1 check; repository providers private to the application layer |
| No allocation arithmetic outside the engine | S06.4.6 test asserting the preview equals engine output exactly |
| No Riverpod persistence feature is used at any stage | ADR-001 prohibition; the app has its own persistence and sync |

### 3.6 Constraints this places on later stages

1. The engine imports nothing from this layer. If ADR-001 were ever reversed, the domain layer, the
   data layer and their tests are unaffected — the blast radius is application plus presentation.
2. The allocation preview watches **one** provider carrying the whole engine result, not one per
   category, and is debounced (S06.4.2). NFR-06 P-07 budgets 100 ms from keystroke at 40 categories.
3. Flow and journey tests override only the outermost boundaries — clock, id generator, remote store
   — never repositories or use cases, so the graph under test resembles production.

---

## 4. Directory structure

Stage 3 substage 3.2 creates this tree **verbatim**. A folder wanted but absent here is a design
gap: raise it and amend this document rather than inventing it.

### 4.1 Layer-first, not feature-first — and why

Layer-first at the top level. Justified against the two facts that decide it:

- **Screen count (~21) and team size (1).** Feature-first pays off when several developers own
  separate features and want to avoid touching each other's directories. With one developer that
  benefit is zero, while its cost is not.
- **The guards must be mechanical.** `lib/domain/**` being one greppable path is what makes G1, G2
  and G3 simple and reliable. Under feature-first, every guard would need to know which
  subdirectories inside each feature are domain and which are data — a pattern that grows with every
  new feature and silently stops matching when someone names a folder differently. The boundary this
  project most needs to hold is the layer boundary, so the filesystem is organised around it.

Feature grouping still appears **inside** `presentation/screens/` and `application/usecases/`, where
it aids navigation without weakening a guard.

### 4.2 The tree

```
budgeting_app/
├── android/
├── lib/
│   ├── main.dart                      # entry point; composition root only
│   ├── app.dart                       # MaterialApp, theme wiring, router attach
│   │
│   ├── domain/                        # PURE DART — guards G1, G2, G3 apply
│   │   ├── result.dart                # Result<T, F> for expected failures
│   │   ├── money/
│   │   │   ├── money.dart             # int64 minor units; no double anywhere
│   │   │   ├── currency.dart          # ISO 4217 code + minor-unit exponent
│   │   │   ├── basis_points.dart      # 0..10000, validated at construction
│   │   │   ├── clock.dart             # interface only
│   │   │   └── id_generator.dart      # interface only
│   │   ├── entities/
│   │   │   ├── enums.dart             # all enums, stable string serialisation
│   │   │   ├── category_group.dart
│   │   │   ├── category.dart
│   │   │   ├── account.dart
│   │   │   ├── distribution_rule_version.dart
│   │   │   ├── rule_line.dart
│   │   │   ├── income_event.dart
│   │   │   ├── allocation.dart
│   │   │   ├── ledger_entry.dart
│   │   │   ├── spending_transaction.dart
│   │   │   └── app_settings.dart
│   │   ├── allocation/                # THE ENGINE — guard G2 applies, strictest
│   │   │   ├── contracts.dart         # AllocationRequest, AllocationResult
│   │   │   ├── failures.dart          # the sealed error taxonomy
│   │   │   ├── split.dart             # largest-remainder integer split
│   │   │   ├── headroom.dart          # headroom per category type
│   │   │   ├── worklist.dart          # phase B queue, redirects, termination
│   │   │   ├── period.dart            # period boundary arithmetic (pure)
│   │   │   ├── override.dart          # manual override redistribution
│   │   │   ├── reversal.dart          # compensating entry generation
│   │   │   └── engine.dart            # the public entry point
│   │   ├── validation/
│   │   │   ├── validators.dart
│   │   │   ├── cycle_detection.dart
│   │   │   └── validation_failure.dart
│   │   └── repositories/              # INTERFACES ONLY
│   │       ├── category_repository.dart
│   │       ├── account_repository.dart
│   │       ├── rule_repository.dart
│   │       ├── ledger_repository.dart
│   │       ├── income_event_repository.dart
│   │       └── settings_repository.dart
│   │
│   ├── data/                          # guard G5: only this layer imports the DB package
│   │   ├── database/
│   │   │   ├── database.dart
│   │   │   ├── connection.dart        # opens the DB; enables foreign keys explicitly
│   │   │   ├── converters/
│   │   │   └── tables/                # one file per table
│   │   ├── repositories/              # implementations of the domain interfaces
│   │   ├── mappers/                   # row ↔ entity, one place, round-trip tested
│   │   ├── balances/
│   │   │   ├── balance_queries.dart
│   │   │   ├── balance_verifier.dart  # recompute-and-compare (INV-04)
│   │   │   └── period_boundaries.dart # single home; see §8.4
│   │   ├── seed/
│   │   │   ├── seed_data.dart         # the 19 suggestions, externalised strings
│   │   │   └── seeder.dart            # idempotent, non-destructive
│   │   ├── migrations/
│   │   │   ├── migrations.dart
│   │   │   └── v1.dart
│   │   ├── backup/
│   │   │   ├── export_json.dart
│   │   │   └── import_json.dart
│   │   ├── reporting/                 # Stage 8
│   │   │   └── queries.dart
│   │   ├── sync/                      # Stage 7
│   │   │   ├── remote_store.dart      # provider-agnostic interface
│   │   │   ├── hlc.dart
│   │   │   ├── merge.dart
│   │   │   ├── repair.dart
│   │   │   ├── outbox.dart
│   │   │   ├── worker.dart
│   │   │   ├── compaction.dart
│   │   │   ├── bootstrap.dart
│   │   │   └── adapters/
│   │   │       └── drive/             # the ONLY place the provider SDK appears
│   │   ├── auth/                      # Stage 7
│   │   ├── clock_impl.dart
│   │   └── id_generator_impl.dart
│   │
│   ├── application/
│   │   ├── providers/                 # repository + engine wiring; composition root
│   │   ├── usecases/
│   │   │   ├── onboarding/
│   │   │   ├── income/                # preview, confirm, reverse
│   │   │   ├── spending/
│   │   │   ├── categories/
│   │   │   ├── accounts/
│   │   │   └── sync/
│   │   └── state/                     # scope, onboarding progress, income draft, sync status
│   │
│   └── presentation/
│       ├── router/
│       │   ├── router.dart
│       │   └── routes.dart
│       ├── theme/
│       │   ├── tokens.dart            # spacing, typography, colour — the only literals
│       │   ├── app_theme.dart         # light + dark
│       │   └── business_scope_theme.dart
│       ├── formatting/
│       │   └── money_formatter.dart   # locale grouping + symbol; see §8.5
│       ├── widgets/                   # shared primitives: money text, progress, empty/error/loading
│       └── screens/
│           ├── onboarding/
│           ├── dashboard/
│           ├── income/
│           ├── categories/
│           ├── accounts/
│           ├── spending/
│           ├── history/
│           ├── reports/
│           ├── settings/
│           └── sync/
│
├── test/                              # mirrors lib/ exactly
│   ├── domain/
│   │   ├── money/
│   │   ├── entities/
│   │   ├── allocation/
│   │   └── validation/
│   ├── data/
│   │   ├── repositories/
│   │   ├── balances/
│   │   ├── seed/
│   │   ├── migrations/
│   │   ├── backup/
│   │   ├── reporting/
│   │   └── sync/
│   ├── application/
│   ├── presentation/
│   ├── fixtures/
│   │   ├── allocation/                # the golden vector JSON files
│   │   └── databases/                 # migration fixture DBs, one per schema version
│   └── support/
│       ├── fakes/                     # fake Clock, deterministic IdGenerator, fake RemoteStore
│       ├── builders/                  # entity test-data builders
│       └── vector_loader.dart         # reads fixtures/allocation/ with no code change per vector
│
├── integration_test/
├── tool/
│   ├── reconcile.dart                 # Stage 9 independent money audit
│   └── guards/                        # G1..G6 check scripts
├── docs/
└── .github/workflows/
```

**A test's location is always predictable from the file it covers:** `lib/domain/allocation/split.dart`
is tested by `test/domain/allocation/split_test.dart`.

### 4.3 Notable placements, and why

| Placement | Reason |
|---|---|
| `domain/allocation/period.dart` **and** `data/balances/period_boundaries.dart` | Two files, one authority — see §8.4. The domain file owns the arithmetic; the data file only applies it to a query. |
| `data/sync/adapters/drive/` isolated | The only directory where the provider SDK may appear (S07.2.5 adds a check). Keeps the provider replaceable and the privacy surface auditable. |
| `presentation/formatting/money_formatter.dart` | Display formatting is presentation. Machine-readable serialisation is **not** here — see §8.5. |
| `test/fixtures/databases/` | Migration fixtures, one per schema version, committed from v1.0 (NFR-07). |
| `tool/guards/` | The guards are scripts in the repository, runnable locally, not CI-only configuration. |

---

## 8. Cross-cutting concerns

### 8.1 Error handling

The domain layer returns **typed results** for expected failures and reserves exceptions for
programmer error.

- `Result<T, F>` is a sealed type in `domain/result.dart`. A validator returns
  `Result<void, ValidationFailure>`; the engine returns `Result<AllocationResult, AllocationFailure>`.
- **Nothing in the domain layer throws for an expected condition.** An invalid configuration, an
  over-maximum income, a bad override — all are values, not exceptions.
- Exceptions are permitted only for states that indicate a bug: a conservation assertion failing
  inside the engine, a mapper receiving a row with an impossible enum value.
- Every user-visible failure carries enough context for a specific message — the offending category
  or group, and the offending value — plus a recovery action. "Something went wrong" is not an
  acceptable terminal state (§6.1 of the PRD's NFR treatment).

### 8.2 Logging

**No financial data is logged at any level, in any build.** Specifically forbidden in log output:
monetary amounts, category names, account names or labels, note text, and the contents of any entity
that carries them.

Permitted: record identifiers, enum values, counts, durations, error types, and sync state
transitions. "Merged 47 records, 3 repairs" is acceptable; "Groceries balance 12,500" is not.

The allocation engine logs **nothing** — it is pure. Diagnostics reach the caller through the result
object, which the UI renders; they are never written to a log.

Enforcement: substage 7.10.4 runs a full session at verbose logging and scans the output for
amounts, category names and account labels, then adds an automated check so it cannot regress.

### 8.3 Time

- **Storage is always int64 UTC epoch milliseconds** (INV-09), for every timestamp in every table
  and every payload.
- `DateTime.now()` is banned outside the `Clock` implementation, enforced by guard G4.
- The engine never reads a clock at all: the evaluation timestamp arrives in the request (INV-08).
- **Local timezone is applied in exactly two places:** the presentation layer, when displaying a
  date; and the reporting query layer, when computing calendar-month and calendar-year boundaries
  (PRD A-18). The reporting layer receives the timezone as an **input** rather than reading it
  from the platform, so period boundary behaviour is testable without changing the device timezone.

### 8.4 Period boundaries — one authority, two callers

Fixed-recurring categories need to know which period an evaluation falls in. Two layers need this:
the engine (to compute headroom) and the data layer (to compute how much was already allocated this
period). Implemented twice, the anchor-day-31-in-February rule will drift — the two would disagree
about which period a payment belongs to, and headroom would be computed against the wrong window.

**Therefore:** `domain/allocation/period.dart` is the single authority. It is pure arithmetic —
given an anchor day, an instant and a timezone offset, it returns the period boundaries.
`data/balances/period_boundaries.dart` contains **no** period arithmetic; it calls the domain
function and applies the result to a query.

The rule for the anchor day that does not exist in a short month is fixed in substage 2.10.4 and
implemented once, here.

### 8.5 Money: two representations, two homes

| Purpose | Where | Produces |
|---|---|---|
| **Serialisation** — CSV export, JSON backup | `domain/money/money.dart` — a pure `toDecimalString()` | An exact decimal string derived by integer arithmetic from minor units, respecting the currency exponent. No locale, no grouping separator, no symbol. |
| **Display** | `presentation/formatting/money_formatter.dart` | A locale-aware string with grouping separators and the currency symbol. |

The display formatter is built on the serialisation function; it never re-derives the decimal
placement. **Neither path may involve a floating-point value at any point**, including intermediates
— guard G3, plus substage 3.6's acceptance criterion that the formatter has no code path accepting
or returning a floating-point number.

This split is why the CSV exporter in `data/` does not import the presentation layer: it needs
serialisation, not display.

### 8.6 Identifiers

All primary keys are client-generated UUIDs stored as text (INV-12), so records created offline on
separate devices never collide and every write is idempotent.

| Record class | Version | Reason |
|---|---|---|
| Ledger entries, income events, allocations | **UUID v7** | Time-sortable. PRD §7.2 shows these are 80–89% of all rows at the Heavy profile, so insert locality in the index matters. |
| Configuration — categories, accounts, rule versions, settings | **UUID v4** | Low volume, no ordering benefit, and v4 avoids embedding record-creation times in the sync payload. |

Identifier generation goes through the injected `IdGenerator`, so tests get deterministic ids and
expected outputs stay stable across runs.

---

## 10. Sequence diagrams

### 10.1 Confirming an income event — the money path

The path that must never lose a unit. The engine purity boundary is marked explicitly: everything
inside it is a pure function of its inputs.

```mermaid
sequenceDiagram
    autonumber
    participant UI as Add Income (presentation)
    participant UC as ConfirmIncome use case (application)
    participant Repo as Repositories (data)
    participant DB as Database
    participant Eng as Allocation engine (domain — PURE)

    UI->>UC: confirm(amount, label, date, overrides?)
    UC->>Repo: load active rule version
    UC->>Repo: load active categories
    UC->>Repo: derive balances + allocated-in-period
    Repo->>DB: read
    DB-->>Repo: rows
    Repo-->>UC: rules, categories, balances

    UC->>UC: clock.nowMs() — read HERE, not in the engine
    rect rgb(232, 244, 234)
        Note over Eng: PURITY BOUNDARY<br/>Crosses in: amount, evaluated_at_ms, rule snapshot,<br/>per-category state, sink id, overrides, period definition.<br/>Crosses out: line items, diagnostics, summary, or a typed failure.<br/>No I/O. No clock. No global state. Byte-identical for identical inputs.
        UC->>Eng: allocate(AllocationRequest)
        Eng->>Eng: validate → phase A split → phase B worklist
        Eng->>Eng: assert sum(line items) == amount
        Eng-->>UC: Result<AllocationResult, AllocationFailure>
    end

    alt failure
        UC-->>UI: typed failure + recovery route
    else success
        UC->>Repo: writeIncomeEvent(event, entries) — ONE transaction
        Repo->>DB: BEGIN … insert event + N ledger entries … COMMIT
        Note over Repo,DB: All rows commit or none (S04.5.2).<br/>Idempotent by client-generated UUID.
        DB-->>Repo: change notification
        Repo-->>UI: query streams re-emit → dashboard rebuilds
        UC-->>UI: success + undo affordance
    end
```

**What the diagram fixes:**

1. Balances are gathered **before** the engine runs and passed in. The engine never fetches.
2. The clock is read in the use case; the resulting timestamp crosses the boundary as data.
3. The engine returns either a complete conserved result or a failure — never a partial allocation.
4. The write is one transaction covering the event and every ledger entry.
5. The UI learns of the change through the database's own notification, the same path a background
   sync write uses (§3.4).

### 10.2 Previewing an allocation — the same engine, no write

```mermaid
sequenceDiagram
    autonumber
    participant UI as Allocation Preview
    participant UC as PreviewAllocation use case
    participant Repo as Repositories
    participant Eng as Allocation engine (PURE)

    UI->>UC: preview(amount) — debounced, on every keystroke
    UC->>Repo: rules, categories, balances (cached per draft)
    UC->>Eng: allocate(AllocationRequest)
    Eng-->>UC: AllocationResult
    UC-->>UI: line items + diagnostics trace
    Note over UI,Eng: Identical request → identical result.<br/>Preview and confirmation call the SAME function,<br/>so what is shown is exactly what is written (S06.4.6).
```

The preview and the confirmed write differ in exactly one respect: the preview does not persist.
They share the request construction and the engine call, which is what makes the substage 6.4.6
assertion — preview output equals engine output equals what confirmation writes — provable rather
than hopeful.
