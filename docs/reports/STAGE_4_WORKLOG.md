# Stage 4 — Core Data Layer — worklog

Evidence log, one entry per substage.

| Substage | Name | Status |
|---|---|---|
| 4.1 | The Money type and core value types | ✅ Complete |
| 4.2 | Domain entities and enumerations | ✅ Complete |
| 4.3 | Database schema and code generation | ✅ Complete |
| 4.4 | Repository interfaces and CRUD | ⬜ Not started |
| 4.5 | The append-only ledger and transactional writes | ⬜ Not started |
| 4.6 | Balance derivation and cache verification | ⬜ Not started |
| 4.7 | Seed data, suggested categories and the sink | ⬜ Not started |
| 4.8 | Validators and cycle detection | ⬜ Not started |
| 4.9 | Migrations, export and backup | ⬜ Not started |
| 4.10 | Test suite and performance smoke test | ⬜ Not started |
| 4.11 | Documentation and gate preparation | ⬜ Not started |

---

## Stage entry

Stage 4's entry criteria are three:

1. **Stage 3 gate approved** — reached and approved, `docs/reports/STAGE_3_REPORT.md`.
2. **`flutter analyze` and the guards pass on the scaffold** — verified at 3.9 from a clean clone.
3. **`SCHEMA.md` approved and unchanged since Stage 2, _or amended with an ADR_.**

The third needed action. `SCHEMA.md` **was** amended after the Stage 2 gate: the `repair_log` table
was added, taking the schema from 12 tables to 13. That amendment was made correctly but not
recorded as a decision, which is precisely what this criterion exists to catch. Written up before
any Stage 4 code as [`ADR-005`](../decisions/ADR-005-repair-log-schema-amendment.md).

This matters more than a paperwork fix. Substage 4.3 transcribes `SCHEMA.md` **exactly** — so a
table missing from the document is a table that never gets built, and the omission would not surface
until repair tooling was written in a much later stage against a table that does not exist.

---

## 4.1 — The Money type and core value types (S04.01)

**Outputs:** `lib/domain/money/{money,money_failure,basis_points}.dart`,
`lib/data/{clock_impl,id_generator_impl}.dart`, `test/domain/money/money_test.dart`.

`Currency`, `MoneyFormat`, `Clock` and `IdGenerator` already existed from substage 3.6, which built
the money formatter and needed the currency exponent to do it. 4.1 adds the arithmetic type itself,
the failure taxonomy, the basis-point type and the two real implementations.

### Acceptance criteria — verification

| Criterion | Evidence |
|---|---|
| No public API on `Money` accepts or returns a `double` or `num` | Enforced mechanically by guard **G3**, which bans the words `double`, `float` and `num` across `lib/domain` and `lib/data` entirely. Negative-tested below. |
| Every arithmetic operation has an overflow test producing a typed failure, not a wrapped value | `plus`, `minus` and `multiplyByBasisPoints` each have an overflow test. The addition test asserts `valueOrNull` is `null` as well as the failure type — the point is that no number comes back at all. |
| Parsing rejects more decimal places than the exponent allows, with a typed failure | `MoneyUnparseable(reason: tooManyDecimals)`. Tested for exponent 2 (`'1.234'`) and exponent 0, where a decimal point at all is too many (`'1.5'` in JPY). |
| Operations across mismatched currencies are rejected | `CurrencyMismatch` from `plus` and `minus`; `compareTo` throws instead (see below). |
| Tests cover exponent 0, 2 and 3 | JPY (0), USD (2), KWD (3). The round-trip test runs seven values through all three. |

### Design decisions worth recording

**No `toDouble()`, and no `fromDouble` even for tests.** 4.1's `must_not` says a convenience
`toDouble` "will be used", and `common_pitfalls` names the test-convenience `fromDouble` factory that
migrates into production. Neither exists. G3 makes the ban structural rather than a matter of
review discipline — it holds for code that never touches `Money` at all.

**`compareTo` throws on a currency mismatch instead of returning a failure.** `Comparable` cannot
express a failure, and the alternative — returning an arbitrary ordering — would silently produce a
wrong sort. Sorting a mixed-currency list is a programmer error, not a user-correctable condition,
which is the line ARCHITECTURE §8.1 draws for when exceptions are allowed. The arithmetic
operations, which *can* be reached with user data, return `Result` instead.

**`multiplyByBasisPoints` takes the divisor as a parameter.** This is the defect found at substage
2.8 by executing the algorithm rather than reading it. Hardcoding 10000 passes every phase A vector
and fails only under override redistribution, where the surviving weights total less than 10000 —
vector V-09 would have lost 120,000 minor units. The test asserts the two override shares still sum
to exactly the input, which is the conservation property (INV-02) the constant broke.

**`BasisPoints.asPercentString` assembles a string by integer arithmetic.** The first draft had
`raw / 100`, which returns a `double`. It was for a display string, not a stored amount, and G3 would
have caught it — but the reason it is wrong is that INV-01 admits no exception for values that are
"only for display". Same discipline as the money formatter (ARCHITECTURE §8.5).

**`wholePercent` floors.** 9999 bp reads as 99%, never 100%. Showing a complete number for something
not quite complete is a small lie, and it is the same reason the ceiling progress bar never rounds up.

### Verification run

```
dart format .            Formatted 37 files (1 changed)
flutter analyze          No issues found!
flutter test test/domain All tests passed!   (49 tests)
dart run tool/guards     All guards passed (G1-G6).
```

### G3 and G4 negative-tested against real money code

Stage 3 §10 flagged that "G3 gets its first real workout once `Money` exists", and the Stage 3
finding behind that note was that **guards G1 and G5 had been passing while matching nothing at
all**. A passing guard is not evidence. Both guards that now have real code to bite were made to
fail on purpose:

| Probe written to `lib/domain/money/_guard_probe.dart` | Result |
|---|---|
| `double probeRate = 1.0;` | `G3  lib/domain/money/_guard_probe.dart:1` |
| `int probeNow() => DateTime.now().millisecondsSinceEpoch;` | `G4  lib/domain/money/_guard_probe.dart:1` |
| probe deleted | `All guards passed (G1-G6).` |

G4's exemption for `lib/data/clock_impl.dart` is therefore an exemption and not an inert matcher:
the same expression fires one directory away.

### Notes for later substages

- `MoneyFailure` is deliberately narrow — overflow, currency mismatch, unparseable. The allocation
  engine's twelve-failure taxonomy is a separate type built at Stage 5; these three are about the
  *number*, not about the allocation.
- `BasisPoints.sum` exists to be passed as `multiplyByBasisPoints`'s divisor. When Stage 5 wires up
  override redistribution, that is the call site to use — not a literal.
- `UuidIdGenerator` splits v7 (ledger, income) from v4 (configuration) per ARCHITECTURE §8.6. This is
  why `uuid` 4.x is a hard floor and why `riverpod_lint`/`custom_lint` were dropped at 3.3
  (`DEPENDENCIES.md` §4.3) rather than downgrading it.

---

## 4.2 — Domain entities, enums and invalid-state prevention (S04.02)

**Outputs:** `lib/domain/entities/**` (11 files), `test/domain/entities/entities_test.dart`,
`tool/domain_purity_check.dart`.

Ten entities, thirteen enumerations, a failure taxonomy and a headroom type. The goal was *"every
entity as an immutable type that cannot be constructed in an invalid state"* — so every constructor
is private and the only way in is a `create` factory returning `Result`.

### Acceptance criteria — verification

| Criterion | Evidence |
|---|---|
| Every listed invalid construction is rejected, proven by a test | Eight tests under *4.2.4 invalid constructions*, one per bullet in the substage. Each asserts the specific failure type **and** that the valid neighbouring case still succeeds, so a factory that rejects everything would not pass. |
| No entity exposes a floating point monetary value | Amounts are `int` minor units. Guard **G3** bans `double`, `float` and `num` from `lib/domain` outright, negative-tested at 4.1. |
| Enumerations serialise as stable strings, proven by a round-trip test | All 13 enums round-trip every value. A second test pins the wire strings *literally*, and a third asserts no wire name parses as an integer. |
| The layering guard passes on the domain package | G1 passes, and was made to fail on a deliberate Flutter import in `lib/domain`. See the transitive gap below. |
| Headroom semantics live on the category type, not scattered across call sites | `Category.headroom()` is the single implementation; the `switch` on `CategoryType` is exhaustive, so adding a fourth type is a compile error rather than three silent omissions. |

### The pitfall the substage names, and what it cost to close

> *"copyWith that allows a valid entity to be copied into an invalid one."*

`copyWith` **returns `Result`, not the entity.** It routes through the same `create` factory, so there
is no second validation path to drift. Concretely, this now fails instead of producing a broken
object:

```dart
reserve.copyWith(type: CategoryType.uncappedFlow)   // ceiling left behind
// → Failure(CeilingTypeMismatch)
```

The caller has to say `clearCeiling: true`. That is more friction at every call site, and it is the
right trade: the alternative is an `UNCAPPED_FLOW` category carrying a ceiling, which the allocation
engine would read as bounded headroom on a category that can never overflow.

Nullable fields use explicit `clearX` flags rather than a sentinel, because `ceilingMinor: null` is
indistinguishable from omitting the argument.

`RuleLine.copyWith` needed a further rule: changing `scope` drops the old target. A `GROUP` line left
carrying a `category_id` would be **counted in neither total** — the group pass skips it for having a
category, the category pass skips it for being group-scoped. A share that exists but is summed
nowhere looks correct on screen while breaking V-01.

### Why entities hold `int` minor units rather than `Money`

The app holds exactly one currency, immutable once any ledger entry exists (V-24). Giving each entity
its own `Currency` would store the same value in ten places and create ten ways for them to disagree
— the failure mode SCHEMA §3.7 cites when it refuses to carry both a signed amount *and* a direction.
The currency is defined once, on `AppSettings.currency`, and use cases pair it with these integers.

### Headroom is a sealed type, not a sentinel integer

ALLOCATION_ALGORITHM §3.1: *"Unbounded must be represented explicitly, as a distinct value — not as
`int64.max`."* With a sentinel, `min(pending, headroom)` happens to work but `headroom - accepted`
quietly does not, and a sentinel leaking into a stored amount is a corrupt balance.

`Headroom.bounded()` clamps at zero in its constructor, so the `max(0, …)` of §3.1 cannot be
forgotten by a caller. Tested against the "already over ceiling" case, which arises from an override,
a lowered ceiling, or a merge — common, not exotic. A property test asserts
`accept(p) + overflowOf(p) == p` across every headroom/parcel combination: conservation at the
smallest scale.

`acceptedSoFarMinor` is a parameter rather than state because §3.2 requires it — a category can be
reached twice in one run, once in phase A and again by a redirect, and headroom computed once at the
start would let both parcels see the same room.

### 4.2.6 found a real gap in G1, and closed it

G1 greps `lib/domain` for Flutter imports. **It only sees direct imports.** A domain file importing a
local file that itself imports Flutter passes G1 while the domain is no longer pure — and Stage 3
already proved that a guard which looks right can match nothing at all.

`tool/domain_purity_check.dart` closes it by construction: it imports and *exercises* every domain
library, and runs under `dart`, not `flutter`. No Flutter engine is present, so any transitive reach
into `dart:ui` fails to compile. It also refuses to run if a `.dart` file exists under `lib/domain`
that it does not import — an unimported library would be an unchecked one, which is exactly how a
guard becomes inert.

Both mechanisms were made to fail:

| Probe | G1 | Purity check |
|---|---|---|
| `import 'package:flutter/material.dart';` in `lib/domain` | `G1 lib/domain/entities/_guard_probe.dart:1` | — |
| A domain file importing `presentation/theme/tokens.dart`, which imports Flutter | `G1 …:1` | **exit 252**, compilation aborts |
| A new `lib/domain` file the check does not import | passes | *"purity is unverified: lib/domain/_purity_probe.dart"* |
| probes removed | passes | `22 libraries compiled and ran on the bare Dart VM` |

The transitive case turned out to trip G1 too, because G1 also forbids `lib/domain` importing
`lib/presentation`. That is luck, not coverage: a Flutter-importing file in `lib/domain` itself would
be caught, but the two-hop path through any *other* permitted location would not be. The check is
kept for that reason.

One honest note on the second row: the purity check fails via a **compiler crash**
(`type 'InvalidType' is not a subtype of type 'FunctionType'`) rather than a clean "cannot resolve
`dart:ui`" message, because the bare VM cannot compile Flutter's FFI bindings. It exits non-zero and
fails the build, which is what matters, but the diagnostic is poor — anyone hitting it should read it
as *"a domain library reached Flutter"*, not as a toolchain fault.

Added to `tool/check.ps1` and `.github/workflows/ci.yml` as a step, so it runs on every push rather
than only in the session that wrote it.

### Deliberately **not** validated at the entity

These need more than one entity can see, and belong to substage 4.8's validator:

| Rule | Why not here |
|---|---|
| V-09, V-11 — the redirect target exists and is not archived | Needs the other category |
| V-12 — the redirect graph is acyclic | Needs the whole graph. The **self-reference** case (V-10) *is* caught here, since it is visible from one entity |
| V-01, V-02 — shares total exactly 10000 | A single `RuleLine` cannot see its siblings |
| V-24 — currency immutable once a ledger entry exists | Needs to count rows; the domain performs no I/O |

Recording the split matters because the temptation at 4.8 will be to re-check what is already
structural. The entity-level rules are the ones an entity can enforce alone; everything else is the
validator's, once.

### Verification run

```
dart format .                          Formatted 52 files
flutter analyze                        No issues found!
flutter test                           All tests passed!   (153 tests)
dart run tool/guards/guards.dart       All guards passed (G1-G6).
dart run tool/domain_purity_check.dart 22 libraries compiled and ran on the bare Dart VM
```

---

## 4.3 — Database schema definition and code generation (S04.03)

**Outputs:** `lib/data/database/database.dart`, `lib/data/database/tables/**` (4 files),
`test/data/database/schema_test.dart`, `docs/reports/STAGE_4_SCHEMA_COMPARISON.md`.

Thirteen tables, 169 columns, 21 foreign keys, 28 check constraints, 10 unique constraints and 22
indexes. The Stage 3 codegen probe (`CodegenProbes` / `ProbeDatabase`) was **replaced wholesale**, as
its own doc comment instructed.

### Acceptance criteria — verification

| Criterion | Evidence |
|---|---|
| The comparison table shows no undocumented differences from SCHEMA.md | [`STAGE_4_SCHEMA_COMPARISON.md`](STAGE_4_SCHEMA_COMPARISON.md). Six added constraints, all documented as an amendment — see below. |
| A test proves foreign key enforcement is active by failing an orphan insert | `AN ORPHAN INSERT FAILS` inserts a category with a non-existent `group_id` and expects `SqliteException`. Two further tests check that `RESTRICT` blocks a delete, and that **every** declared key is `RESTRICT` rather than `CASCADE`. |
| The automated floating-point check reads the live schema and passes | Three tests. A blocklist (`REAL`, `DOUBLE`, `FLOAT`, `NUMERIC`, `DECIMAL`), an **allowlist** (`TEXT` or `INTEGER` only — which catches a storage class nobody thought to forbid), and a demonstration that INTEGER affinity stores `5000.0` as `integer`. All read `PRAGMA table_info`. |
| Code generation completes with no unresolved warnings | Zero. Two classes of warning were fixed rather than ignored — see below. |
| Every synced table carries all five sync columns | Asserted for all nine, **and** asserted absent on all four device-local tables. |

### The comparison pass found a real defect in substage 4.2

`SCHEMA.md` C-02 requires `amount_minor > 0` on `income_events`. My 4.2 `IncomeEvent` entity
**allowed zero**, on a misreading of golden vector V-11a as "zero income produces no lines". V-11a is
a *failure* vector — its expected outcome is `IncomeNotPositive`, and its own fixture file says so in
its description.

Fixed at the entity (`NonPositiveAmount` now, with the test renamed to state the rule), and the
database enforces it independently. Two mechanisms, as with C-15 and INV-03.

This is what 4.3's `why_it_matters` warns about — *"any divergence here invalidates the Stage 2
design review, silently"* — and it is worth recording that the divergence was mine, introduced one
substage earlier, and that transcribing against the document is what surfaced it. Re-reading my own
entity code would not have.

The now-unused `NegativeAmount` failure was deleted rather than left as dead vocabulary.

### Six constraints added, and recorded rather than absorbed

4.3's `must_not`: *"Do not silently deviate from SCHEMA.md — amend the document and note it."*
Transcribing §3 and §4 surfaced six constraints the design required but §5.4 had not listed. Added to
`SCHEMA.md` §5.4 as **C-23…C-28** with a note explaining the omission.

All six are tightenings — no row valid under the Stage 2 design is now rejected. **C-24** is the one
with teeth: `rule_lines` scope/target agreement was stated in §3.5 as prose only, and without it a
`GROUP` line carrying a `category_id` is counted in neither total. A share that exists but is summed
nowhere looks correct on screen while breaking V-01, and a merge of two independently valid edits is
a plausible way to produce one.

A related mislabel was corrected: `RuleLineScopeMismatch` in 4.2 cited rule `C-21`, which is the
reserved-columns constraint on `categories`. It now cites C-24, the rule that actually exists.

### Generator warnings, and why each mattered

| Warning | Count | Resolution |
|---|---|---|
| *"Drift can only verify custom constraints set as constant string literals"* | 9 | The shared `kSyncCheckConstraint` was inlined at each of the nine sites. Referencing a named constant meant **Drift silently stopped verifying those constraints** — it still emits them, but no longer parses them, so a typo would have reached SQLite as a runtime error instead of a build error. DRY was the wrong trade here. |
| *"Duplicate orderings/filters detected … Filter and orderings for this field wont be generated"* | 4 | `@ReferenceName` added to 15 foreign keys. Two keys pointing at the same table collide in the generated manager API, and the generator's response is to **omit** the accessors — so the loss is silent until 4.4 reaches for one that does not exist. |

Both were cases where the warning meant *"something you asked for was not generated"*, which is the
kind that costs a session to diagnose later.

### Design decisions worth recording

**Foreign keys are switched on in `beforeOpen`, and the result is asserted.** SQLite defaults
enforcement OFF, and it is a **per-connection** setting, so `onCreate` would be the wrong place. The
`PRAGMA foreign_keys` result is read back and the open refused if it is not 1 — a PRAGMA that
silently failed to apply would leave all 21 `RESTRICT` clauses decorative.

**Eight unique constraints are raw `CREATE UNIQUE INDEX … WHERE` rather than Drift `uniqueKeys`.**
Drift cannot express a partial index, and partiality is the whole point: an archived category must
not block reusing its name, and a tombstoned row must not block re-creation. Tested — U-01 refuses a
duplicate live name, then accepts it once the holder is archived.

**Each index is a named constant** rather than an anonymous list entry, so a failing `CREATE INDEX`
names the rule it came from.

**The deliberately-omitted Q9 composite index is asserted absent**, not merely left out. SCHEMA §5.5
records the reasoning — `ledger_entries` is the highest-volume table and every extra index is paid on
every allocation write. A test now stops a later hand from adding it without confronting that.

**IX-01 is verified used by query plan, not assumed.** `EXPLAIN QUERY PLAN` on the balance-derivation
query names `ix_01_ledger_category_time`. SCHEMA §5.5 asks for this at 4.6.1 and 8.1.5; doing it here
costs nothing and means the index has proved useful once before anything depends on it.

**Column order differs from `SCHEMA.md`** — the five sync columns appear first on synced tables,
because they come from a mixin. Column order is not part of the design and no query selects by
position, so it is recorded in the comparison document as an artefact rather than a difference.

### A process failure worth recording

**Substage 4.2 was committed with 48 analyzer issues.** Its worklog entry claims
`flutter analyze — No issues found!`, and that was true when I ran it — but I then added
`tool/domain_purity_check.dart` and committed without re-running. The claim was accurate about a
state that no longer existed by the time of the commit.

All 48 are now fixed (24 `prefer_single_quotes`, 19 `no_adjacent_strings_in_list`, 4
`unnecessary_type_check`, 1 `unused_import`), and the verification below covers the whole tree. The
lesson is narrow and worth keeping: **the verification run must be the last thing before the commit,
not the last thing before the final edit.** `tool/check.ps1` exists precisely so this is one command;
I ran the individual pieces out of order instead.

The `unused_import` was fixed by **using** `result.dart` rather than dropping the import — the purity
check's `_importedLibraries` list claims that library is covered, so dropping the import would have
made the completeness guarantee quietly false.

### Verification run

```
flutter pub run build_runner build   wrote 10 outputs, 0 warnings
dart format .                        Formatted 58 files (0 changed)
flutter analyze                      No issues found!
flutter test                         All tests passed!   (183 tests, 29 of them schema)
dart run tool/guards/guards.dart     All guards passed (G1-G6).
dart run tool/domain_purity_check    22 libraries compiled and ran on the bare Dart VM
```

---

## Amendment — FR-16, ceiling-triggered cascade redirect (ADR-006)

**Arrived:** between substages 4.3 and 4.4, after both the Stage 1 and Stage 2 gates.
**Recorded in:** [`ADR-006`](../decisions/ADR-006-ceiling-triggered-cascade-redirect.md).

A new requirement: when an Accumulating Reserve hits its ceiling, its allocation redirects to
explicitly configured fallback categories — by priority or split — cascading onward if those are also
full, and reaching a flagged surplus bucket if the chain runs out.

### Most of it was already designed; two clauses were not

Recorded precisely, because re-implementing an existing mechanism under a new name is how a codebase
acquires two sources of truth for one behaviour.

| Clause | Already lives at | Built? |
|---|---|---|
| live check on every event, mid-calculation | ALLOCATION §3.2 `accepted_so_far` | Yes, 4.2 |
| cascade when a target is also full | §3.3 FIFO worklist; vector V-05 | Specified |
| surplus bucket, never dropped silently | the sink, `SINK_TERMINAL`, INV-07, V-06 | Yes, 4.2 |
| reserve-only; bills stay simpler | §3.1 headroom table | Yes, 4.2 |
| **many targets, split or priority** | — | **New** |
| **Reference Monthly Amount** | — | **New** |

### Decision 1 — `redirect_targets` replaces the single column

`categories.redirect_target_category_id` is **removed**, not kept alongside a table for the
multi-target case. One target is the one-row case of many, and two places to read "where does
overflow go" is the shape SCHEMA §3.7 rejects when it refuses to store a signed amount beside a
direction.

`SPLIT` divides overflow by **the sum of the live targets' weights**, not a constant 10000. This is
the substage 2.8 primitive again: when one of three targets is archived the live weights total 6667,
and dividing by the constant leaves a third of the overflow unallocated. A test asserts the wrong
divisor loses more than 29,000 of a 90,000 overflow, so the defect cannot return quietly.

### The requirement contained an ambiguity, resolved explicitly

Two clauses pull different ways when Hajj is full:

- *"a user-configurable split or **priority order**"* → try Wedding, the source's next choice.
- *"cascade further down **that target's own** redirect target"* → try Hajj's target.

**Resolved: the source's own list is exhausted first, then the chain descends** (ALLOCATION §3.10.1).
Descending immediately would make priority order nearly meaningless — a priority-1 target would only
be reached if priority-0's chain circled back to it. A user who lists Hajj then Wedding is saying
*fill Hajj, then Wedding*, and the design should say what they said.

This is why a parcel carries its **origin** and how far through that origin's list it has travelled,
not merely its immediate predecessor. `origin_id` and `redirected_from` diverge once a chain exceeds
one hop, and conflating them is the easiest way to build this wrongly: the ledger wants to say *"this
came from Hajj"* while the walk still needs to know Wedding is EV Bike's next choice.

Vector **V-18** pins the decision — under the rejected reading Wedding is never reached, so the
vector fails loudly if it is ever quietly reversed.

**A pleasant consequence:** the existing FIFO worklist already produces sibling-before-descendant for
free, since siblings enqueue at hop *N* and descendants only at *N+1*. §3.3 chose FIFO to avoid a
stack overflow and keep the hop count visible; it turns out to also be what makes this ordering
correct without a second mechanism. Under LIFO, a deep chain beneath the first target would starve
the second.

### Decision 2 — the Reference Monthly Amount is stored but does not yet allocate

The requirement describes an **absolute** figure (193,000/month). FR-02, a MUST requirement, reads
*"Set a fixed percentage of income allocated to each category."* These differ visibly the first time
income varies: on a 700,000 month against a 550,000 reference, does the bike get 193,000 or 245,000?

Answering "absolute" would require under-funding and over-funding rules, would rework phase A, would
contradict an approved MUST requirement, and would invalidate several golden vectors. **Raised as
OQ-19 with a recommendation rather than decided silently.**

`reference_monthly_amount_minor` is stored now, constrained by C-33 to reserves and to positive
values, so whichever way OQ-19 resolves no row exists that the answer would invalidate — and if it
resolves toward absolute amounts the data is already captured rather than needing backfill.

**The cascade is unaffected by that fork**, which is why Decision 1 shipped with full confidence
while Decision 2 waits. The fork is upstream of the interesting part.

### Ripple

| Document | Change |
|---|---|
| `PRD.md` | FR-16; US-038, US-039 |
| `SCHEMA.md` | §3.14 `redirect_targets`; `categories` ±columns; C-29…C-33; V-28…V-31; U-11, U-12; IX-13; `RedirectMode` |
| `ALLOCATION_ALGORITHM.md` | §3.10 (four subsections); vectors **V-16…V-19** |
| `OPEN_QUESTIONS.md` | OQ-19 |
| `TRACEABILITY.md` | FR-16 row |
| 4.2 outputs | `RedirectTarget` entity; `Category` reworked; `RedirectMode`; four new failures |
| 4.3 outputs | `RedirectTargets` drift table; indexes; comparison document regenerated |

### The four cases the requirement names, tested

Golden vectors V-16…V-19 map one-to-one onto them. The engine is Stage 5, but the **arithmetic each
vector asserts was executed here**, at the level Stage 4 can reach — `Category.headroom` and
`Money.multiplyByBasisPoints` walked by hand in `test/domain/entities/redirect_target_test.dart`,
each asserting conservation:

| Case | Vector | Arithmetic proved |
|---|---|---|
| simple single-target redirect | V-16 | 193,000 into 100,000 headroom → 93,000 to the priority-0 target; total 386,000 |
| multi-target split | V-17 | 93,001 across 6000/4000 → 55,801 / 37,200, leftover 1 to the larger remainder |
| chained cascade, target also full | V-18 | 40,000 → 20,000 → 133,000 to the sink; EV Bike produces **no line**, not a zero line |
| no valid target | V-19 | 193,000 reaches the sink whole; a capped sink cannot be constructed |

A vector whose numbers were never executed is a guess. Substage 2.8 found a real defect precisely by
running the algorithm instead of reading it, so the numbers were run before they were written down.

### Verification

```
flutter pub run build_runner build   0 warnings
tool/check.ps1 -SkipBuild            ALL CHECKS PASSED (7 steps)
flutter test                         All tests passed!   (206 tests)
```

The domain purity check **failed first**, refusing to run because `redirect_target.dart` existed
under `lib/domain` without being imported by it — the completeness assertion added at 4.2 doing
exactly the job it was written for. An unimported library would have been an unchecked one.

### Left for later stages

- **Stage 5** implements §3.10 and must pass V-16…V-19. Fixture files for the four vectors are not
  yet written; the vector table is the contract.
- **Stage 6** needs a redirect-target editor (list, reorder, mode, shares) rather than a single-target
  dropdown, plus the `SURPLUS_UNALLOCATED` surfacing. Named in ADR-006 so it is sized, not discovered.
- **Substage 4.8**'s cycle walk is now over a **branching** graph — a chain check following only the
  first target would miss a cycle reachable through the second.
- **Substage 4.7**'s seed should name the personal sink **"Unallocated Surplus"**, matching the
  requirement's wording.
