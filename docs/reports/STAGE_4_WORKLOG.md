# Stage 4 — Core Data Layer — worklog

Evidence log, one entry per substage.

| Substage | Name | Status |
|---|---|---|
| 4.1 | The Money type and core value types | ✅ Complete |
| 4.2 | Domain entities and enumerations | ✅ Complete |
| 4.3 | Database schema and code generation | ✅ Complete |
| 4.4 | Repository interfaces and CRUD | 🟡 Code complete, unverified — no toolchain |
| 4.5 | The append-only ledger and transactional writes | 🟡 Code complete, unverified — no toolchain |
| 4.6 | Balance derivation and cache verification | 🟡 Code complete, unverified; benchmark unmeasured |
| 4.7 | Seed data, suggested categories and the sink | 🟡 Code complete, unverified — no toolchain |
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

---

## 4.4 — Repository interfaces and CRUD (S04.04)

**Outputs:** `lib/domain/repositories/**` (6 files), `lib/data/mappers/**` (6 files),
`lib/data/repositories/**` (5 files), `test/data/repositories/**` (4 files),
`test/data/mappers/round_trip_test.dart`, `test/domain/repositories/interface_purity_test.dart`,
`test/support/test_database.dart`, `test/support/builders/config_builders.dart`.

> ### ⚠ This substage is written but **not verified**
>
> The Flutter and Dart toolchain is **absent from this machine.** `ENVIRONMENT.md` §2 records the
> SDK at `C:\Users\Chichum\flutter`; the only profile present is `Khizi`, and a recursive search of
> `C:\` found no `flutter.bat` and no `dart.exe`. There is no `.dart_tool/`, no pub cache, and
> `database.g.dart` has never been generated here.
>
> So none of `build_runner`, `flutter analyze`, `dart format` or `flutter test` has been run against
> any of it. The code below is written against the Drift 2.34 API and the generated names Drift
> derives from the 4.3 table classes — both from knowledge rather than from a compiler.
>
> **Nothing in this entry should be read as evidence.** The acceptance-criteria table records which
> test is *intended* to prove each criterion, not that any of them passed. Substage 4.4 is not
> complete until `tool/check.ps1` runs green on a machine that has the SDK. See
> *"What must be re-run"* at the end.

### Acceptance criteria — and the test written for each

| Criterion | Test written to prove it | Status |
|---|---|---|
| No repository method signature exposes a database or generated type | `interface_purity_test.dart` — strips comments from every file in `lib/domain/repositories`, then fails on 14 persistence type names and 3 banned import prefixes. Includes a self-test that the token list actually catches a violation. | not run |
| Every configuration delete is soft, proven by a test that finds the row still present with a tombstone | `category_repository_test.dart` → `THE ROW SURVIVES, CARRYING A TOMBSTONE`, plus equivalents for accounts, rule versions and rule lines. All read through `rawRow`/`rawCount`, which bypass the repository entirely. | not run |
| Reactive streams emit on changes made through a different code path | The `4.4.4` group — three shapes: a **second repository instance**, a **raw `customUpdate`** with no repository involved, and a soft delete. | not run |
| Row-to-entity mapping round-trips every field, proven per entity | `round_trip_test.dart` — one test per entity, asserting `expect(readBack, original)` against entity `==`, with every field set to a deliberately non-default value. | not run |
| Repository tests run against an in-memory database with no file system dependency | `openTestDatabase()` returns `NativeDatabase.memory()`. No test touches a path. | not run |

### Design decisions worth recording

**The repository does not invent `SyncFields`.** Callers hand over a complete entity, stamp
included. The hybrid logical clock that orders concurrent edits is S07.4's to implement, and a
placeholder minted here would be a *second, wrong* source of ordering that Stage 7 would then have
to detect and undo. The one exception is **soft delete** — the only write a repository originates
rather than relays — which needs a deletion timestamp and therefore takes an injected `Clock`
(INV-09, guard G4). `updated_by_device` is left untouched even there, because device identity lives
in `sync_metadata` and does not exist yet.

**Writes through the mappers are total; the two originated writes are partial.** Every companion in
`lib/data/mappers/**` sets every column, including nullable ones set to an explicit null — so
switching a savings goal to an open envelope actually *clears* the ceiling instead of leaving a
stale one behind the entity's back. The tombstone and archive updates deliberately break that rule
and write only the columns they change, because they are the writes where the repository knows
exactly which fields it is changing and has no opinion about the rest.

**Rejections throw rather than return, so the transaction rolls back.** `RejectedWrite` is an
exception caught by `writeTransaction`, not a returned value. A rejection signalled by returning
early only unwinds cleanly while nothing has been written yet — a property every future edit to a
write path would have to preserve unprompted. `replaceLines` is the case that proves it: it
tombstones the dropped lines *before* inserting the new ones, so a mid-transaction failure without
rollback would persist a percentage set totalling 0%. There is a test for exactly that.

**One gate, not seven call sites, for INV-11.** Every mutating path in `DriftRuleRepository` passes
through `_rejectIfSealed`. `EVERY MUTATING PATH IS REFUSED ONCE SEALED` exercises all six of them —
`updateVersion`, `createLine`, `updateLine`, `deleteLine`, `replaceLines`, `deleteVersion` — because
the failure mode is not "the check is wrong", it is "the eighth path forgot to call it".

**Tombstone filtering is structural, not remembered.** `CategoryQuery`, `AccountQuery` and
`RuleVersionQuery` carry `includeDeleted`, defaulting to false, and every list read funnels through
a single private `_…Select` that applies `tombstoneTerm` unconditionally. `matchAll` exists so that
an unfiltered read takes the *same* code path as a filtered one — a branch that skips `.where`
entirely is a branch where a missing tombstone term is invisible. This is the substage's named
pitfall: *"deleted categories reappear in pickers."*

**Archived and deleted are filtered independently, and a test says so.** Asking for
`ArchivedFilter.any` must not also opt in to tombstones. They are different states everywhere in the
schema — U-01 and U-02 are partial on `is_archived = 0`, so archiving deliberately frees a name for
reuse while a tombstone removes the row from every user-facing read.

**Mapping failures throw; storage failures return.** `MappingError extends Error`, so it passes
straight through `writeTransaction`'s `on Exception` and reaches the developer. The alternative — a
`Result` — invites the recovery "skip this row and carry on", which for a category means a dashboard
silently missing a bucket that holds money.

### Judgement calls, flagged rather than buried

- **`RedirectTarget` CRUD went into `CategoryRepository`**, not a seventh repository. ARCHITECTURE
  §2.2 lists six interfaces and predates ADR-006. Redirect edges are per-category configuration
  edited in the same user action, and splitting them would put the two halves of one edit behind two
  objects. ARCHITECTURE's table is now one row out of date; noted for 4.11.
- **Deleting a category does not check rule lines.** A sealed version's lines must survive the
  deletion (INV-11), while a draft's must be redistributed to keep V-02's total at 10000 — a
  judgement over the whole set, not a referential check over one row. Left to **4.8**, with a comment
  at the call site saying so.
- **Deleting an account with linked categories is refused**, not silently resolved. Unlinking is a
  decision: the categories keep their money either way, but the user loses the record of where it is
  held. Stage 6 asks; Stage 7 takes the documented `ACCOUNT_UNLINKED` repair.
- **Constraint classification is by message, not by exception type.** The data layer does not name
  `SqliteException`, so it stays independent of the SQLite binding — tests run on `NativeDatabase`,
  the app runs through `drift_flutter`. Pre-checks inside the transaction produce the *specific*
  failures (`DuplicateName`, `RuleVersionSealed`); `ConstraintViolation` is only the backstop.
- **`LedgerRepository` and `IncomeEventRepository` are not here.** They are 4.5's, along with the
  append-only guarantee that shapes them. Building them now would mean building them before the
  invariant that constrains their API.

### What must be re-run before this substage can be ticked

On a machine with the SDK, in order:

```
flutter pub get
flutter pub run build_runner build   # database.g.dart does not exist yet
dart format .                        # NOT run here; CI uses --set-exit-if-changed
flutter analyze
dart run tool/guards/guards.dart
dart run tool/domain_purity_check.dart
flutter test
```

`dart format` is called out because `tool/check.ps1` fails the build on any formatting difference,
and hand-formatted code will almost certainly differ somewhere. Expect the first failures to be
formatting and generated-name mismatches rather than logic.

**`tool/domain_purity_check.dart` was extended, not left to fail.** Its
`_assertAllDomainLibrariesImported` refuses to run when a `.dart` file exists under `lib/domain`
that the program does not import — the same completeness assertion that fired at 4.3 on
`redirect_target.dart`. All six new interface files are now imported and exercised there.

That turns out to be the **strongest** available evidence for this substage's first acceptance
criterion. The check compiles the four repository interfaces on the bare Dart VM with no Flutter
engine and no database package present, so a signature naming a Drift type could not compile in it
at all — the criterion proved by construction rather than by the token scan in
`interface_purity_test.dart`. Both are kept: the scan gives a precise file and token, this gives
transitive truth. (Neither has been run.)

---

## 4.5 — Append-only ledger and transactional writes (S04.05)

**Outputs:** `lib/domain/repositories/{ledger,income_event,spending}_repository.dart`,
`lib/data/mappers/movement_mappers.dart`, `lib/data/repositories/ledger_writer.dart`,
`lib/data/repositories/drift_{ledger,income_event,spending}_repository.dart`,
`test/data/repositories/{ledger,income_event,spending}_repository_test.dart`,
`test/data/repositories/append_only_design_test.dart`,
`test/support/{movement_fixture.dart,builders/movement_builders.dart}`.

> **⚠ Still unverified — same toolchain gap as 4.4.** No Dart or Flutter SDK on this machine, so
> nothing here has been compiled or run. Criteria below say which test is *intended* to prove each
> one. See 4.4's *"What must be re-run"*; it applies unchanged.

### Acceptance criteria — and the test written for each

| Criterion | Test | Status |
|---|---|---|
| The ledger repository exposes no update or delete method | `append_only_design_test.dart` → `NO METHOD ON LedgerRepository NAMES A MUTATION`, scanning the interface for nine mutating verbs, plus a self-test that the scan catches one | not run |
| A failure injected midway through an income event write leaves zero rows | `income_event_repository_test.dart` → `A FAILURE MIDWAY LEAVES ZERO ROWS` | not run |
| Inserting the same ledger entry UUID twice is a no-op rather than a duplicate | `4.5.4` group, both halves — count unchanged, **and** the stored amount unchanged | not run |
| Reversal linkage works without altering the original row | `THE ORIGINAL LEDGER ROWS ARE BYTE-FOR-BYTE UNCHANGED` | not run |
| The design test documenting immutability exists and passes | `append_only_design_test.dart`, six routes | not run |

### INV-03 is enforced four ways, because one way is a promise

The interface has no `update` and no `delete`. That stops the application and presentation layers
and nothing else — three repositories in the **data** layer hold a live `PookieDatabase`, on which
`db.update(db.ledgerEntries)` is an ordinary expression. So:

| Route | Closed by |
|---|---|
| Calling an update method | There is none |
| Building an amended entry to write back | `LedgerEntry` has no `copyWith` (4.2's decision, tested here) |
| A partial companion | `movement_mappers.dart` defines exactly one, insert-shaped |
| `db.update(db.ledgerEntries)` from inside the data layer | Every ledger write funnels through `ledger_writer.dart`; the design test asserts no other file in `lib/data/repositories/` names the table in a mutating position |
| Tombstoning, including by a sync merge | Constraint C-15 |
| Re-inserting a changed row under the same id | `insertOrIgnore` skips, never overwrites |

The substage's named pitfall is *"a generic repository base class that supplies update and delete to
every table including the ledger."* `ledger_writer.dart` is the deliberate opposite: not a base
class granting capabilities broadly, but one narrow function granting exactly one.

### `insertOrIgnore`, never `insertOnConflictUpdate`

The whole of INV-12's guarantee sits in that choice. Ignoring a duplicate id makes a retry a no-op,
which is what lets a sync push that timed out *after* committing simply be repeated. Upserting would
make the same retry an update — and a retry carrying a different amount under the same id would
silently rewrite history. **An upsert is an update path wearing an insert's name.** Both halves are
tested: that a replay adds no rows, and that it does not change the stored amount.

### Conservation is checked at the write, not trusted from upstream

`requireConservation` refuses any movement whose entries do not total its amount (INV-02). The engine
already guarantees this and Stage 5 proves it over fifteen vectors — but this is the boundary where
a computed split becomes rows that **can never be edited**. A short write is not a partial record, it
is a permanently wrong one: the balances are wrong until someone notices and writes a compensating
entry, and nothing in the app can tell that they are. Refusing is the only cheap moment.

### Sealing happens inside the income transaction

`record` seals the rule version it used, in the same transaction, with
`WHERE ... AND sealed_at_ms IS NULL`. That is idempotent *and* keeps the first instant — the moment
history became fixed is the first income event, not the latest. Any window in which a committed
event references an unsealed version is a window in which the percentages behind real history can
still be edited, which is exactly what INV-11 promises cannot happen. A test asserts a **rejected**
write does not seal either.

### Reversal: mirrored, guarded against stored state, linked by lookup

Guards R-1 and R-2 are checked against the **stored** original inside the transaction, not against
what the caller believed — two devices can independently decide to undo the same event, and the one
committing second must be refused. The link is then written with
`WHERE id = ? AND reversed_by_event_id IS NULL`, so R-1 is atomic rather than merely checked: a
concurrent winner leaves this matching zero rows, and the mismatch rolls everything back.

"Reversed" on a ledger entry is a **lookup** (`reverses_entry_id`, index IX-04), never a flag —
marking the original would mean writing to it. On the *event* row, `reversed_by_event_id` is the one
permitted mutation, exactly as ALLOCATION_ALGORITHM §4.8 specifies.

### Judgement calls, flagged rather than buried

- **A seventh interface, `SpendingRepository`.** `ARCHITECTURE.md` §2.2 does not name it. Both
  candidate homes are worse: `LedgerRepository` exists to expose *no* mutation, and putting a
  correctable record behind it blurs the line this substage is drawing; `IncomeEventRepository` is
  money arriving, and money leaving is not a variant of that. Flagged for 4.11 — that table is now
  two rows stale, this and `RedirectTarget` from ADR-006.
- **`record()` throws when handed a reversal.** Routing one through it would skip R-1 and R-2
  entirely, letting the same income be undone twice. A returned failure invites a caller to handle
  it and move on; an exception says the code is wrong. Same reasoning for a spending entry that does
  not belong to its transaction. The rule this settles: **caller-construction bugs throw; data-state
  conflicts return.**
- **`DriftLedgerRepository` applies no tombstone filter anywhere.** Everywhere else in this layer
  that is a defect. Here C-15 pins `is_deleted` to 0 for every row, so the term could never change a
  result — and a filter that never matters teaches the next reader the wrong thing about this table.
  A test asserts the column really is always 0, so the omission stays justified rather than assumed.
- **`allocatedInPeriodMinor` counts `REVERSAL` alongside `ALLOCATION`, signed.** Otherwise a
  reversed bill payment permanently occupies its period's capacity and the category refuses money
  for the rest of the month because of an allocation that no longer exists. Spending is deliberately
  *not* counted: the cap is on what may be allocated per period, not what may be spent.
- **A SQLite trigger was considered and not added.** `CREATE TRIGGER ... BEFORE UPDATE ON
  ledger_entries RAISE(ABORT)` would be stronger than all six routes above. It is not here because
  4.3 transcribes `SCHEMA.md` exactly and the document specifies no triggers, so adding one is a
  schema amendment needing an ADR. 4.5's goal is scoped to *"through the repository API"*, which the
  above satisfies. Recorded so the option is a decision rather than an oversight — worth raising at
  4.11 if the gate wants belt and braces.

---

## 4.6 — Balance derivation and cache verification (S04.06)

**Outputs:** `lib/domain/allocation/period.dart`,
`lib/domain/repositories/balance_repository.dart`,
`lib/data/balances/{balance_sql,balance_queries,balance_verifier,period_boundaries}.dart`,
`test/domain/allocation/period_test.dart`,
`test/data/balances/{balance_test,balance_benchmark_test}.dart`,
`docs/decisions/ADR-007-balance-cache-entry-count.md`.

> **⚠ Still unverified — same toolchain gap as 4.4 and 4.5.** No Dart or Flutter SDK on this
> machine. One acceptance criterion here is **not merely unverified but unmeetable** without it; it
> is called out below rather than left to be discovered at the gate.

### A real defect in `SCHEMA.md`, found by reading two sections together

`SCHEMA.md` describes `balance_cache` twice and the two disagree.

- **§7.1** (the balance policy, substage 2.4) specifies the incremental update as
  `balance_minor += …` plus **`entry_count += 1`**, and defines the cheap verifier tier as
  *"one grouped `COUNT(*)` per category compared against the cached `entry_count`."*
- **§3.12** (the table declaration, substage 2.3) lists five columns. **There is no `entry_count`.**

Substage 4.3 transcribed §3.12 faithfully, and `STAGE_4_SCHEMA_COMPARISON.md` correctly reported no
divergence — it compares the transcription against the declaration, which is what it exists to do.
Neither document is wrong about itself. They are wrong about each other, and only 4.6 has cause to
read both.

The consequence is concrete: **the cheap tier as specified could not be implemented.** Raised and
amended rather than patched forward, per the manifest's `sdlc_discipline`, as
[ADR-007](../decisions/ADR-007-balance-cache-entry-count.md). `SCHEMA.md` §3.12 now declares the
column and points at the ADR.

The alternative that needed no schema change — compare `MAX(id)` against the existing
`last_entry_id`, since ledger ids are UUID v7 — was considered and rejected. It is **weakest exactly
where the risk is highest**: it detects an entry appended *after* the cached one, but not an entry
inserted with an *earlier* id, which is precisely what a sync merge produces. §7.1 says merges
dominate this failure mode. A cheap tier blind to merges would pass on every cold start and give
false assurance between full recomputes.

### Acceptance criteria — and the test written for each

| Criterion | Test | Status |
|---|---|---|
| Every balance is derivable from the ledger alone | `balance_test.dart` → `4.6.1` group. Signed sums, negatives permitted, empty categories present at zero | not run |
| The verifier detects a deliberately corrupted cached balance | `THE VERIFIER FINDS A DELIBERATELY CORRUPTED BALANCE` — corrupted by raw SQL, because no API can do it | not run |
| Period-scoped derivation handles anchor 31 through a 28-day February without skipping or duplicating | `period_test.dart` → `TWELVE PERIODS A YEAR, NO GAP AND NO OVERLAP`, plus a day-by-day sweep of a full year | not run |
| Per-account totals reconcile with the sum of linked category balances | `4.6.5` group | not run |
| **Derivation timing at five-year volume is recorded and within NFR-06** | `balance_benchmark_test.dart` exists and asserts P-13 ≤ 2 s | **CANNOT BE MET HERE** |

**The timing criterion is the one I cannot satisfy.** It requires a measured number, and measuring
requires running. The benchmark is written — 67,000 entries across 100 categories, the PRD Heavy
profile — and prints its figure for pasting here, but **the cell is empty and must stay empty until
someone runs it.** Recording an estimate would be inventing evidence; §7.1's own 40–80 ms figure is
explicitly an estimate that 4.6.6 exists to replace.

### Design decisions worth recording

**The cache is folded in by `appendLedgerEntries`, not beside it.** §7.1 requires that *"there is no
code path that writes a ledger entry without adjusting `balance_cache` atomically."* The only way to
make that true is to make it the same code path — a cache updated by a separate call is a cache that
drifts the first time somebody adds a fourth write path and forgets the second call. 4.5's single
chokepoint turned out to be exactly the right place to put it.

**A replayed entry must not fold twice.** `insertOrIgnore` silently skips a duplicate, so
incrementing the balance regardless would make a retried sync push inflate every category it
touched — a corruption caused by the very mechanism that exists to make retries safe. The writer
therefore asks whether the entry is already stored *before* inserting, and folds only what it
actually stored. There is a test.

**`is_stale` is never cleared by an incremental update.** A row marked stale by a merge needs a full
recompute, and an increment does not provide one. Clearing the flag would declare the row
trustworthy on the strength of a write that knows nothing about why it was doubted. The verifier
reports `staleFlagSet` on its own and skips the mismatch checks for that row, so a known-bad row
does not bury the real signal under noise.

**Derived and cached are separate methods, deliberately.** A single `balanceOf` returning "the cache
if fresh, otherwise a recompute" would make the verifier unwritable — there would be no way to ask
for the derived value specifically, and the comparison would compare the cache against itself.

**`recomputeAll` is not a setter in disguise.** 4.6's `must_not` forbids a balance setter. A setter
takes a number from its caller; this takes nothing and reads the ledger, so running it twice gives
the same answer. That reproducibility *is* INV-04's requirement.

**Account totals join through `categories.linked_account_id`, not `ledger_entries.account_id`.** The
two differ on purpose: the entry column is denormalised at write time so history survives a re-link,
while an account's total is what it holds *now*. Summing the entry column would report money against
an account the category no longer belongs to. A test moves a category between accounts and asserts
both behaviours at once.

**Period arithmetic lives once, in `domain/allocation/period.dart`.** ARCHITECTURE §8.4 is explicit,
and `data/balances/period_boundaries.dart` is deliberately trivial — it renames a `PeriodDefinition`
into a `DateRange` and nothing else. Both types are half-open, so there is no boundary adjustment to
get wrong. `nextPeriod` is derived from the instant after this period ends rather than by adding a
month, because adding a month to a *clamped* start compounds the clamp: 28 Feb would give 28 Mar and
an anchor of 31 would be lost permanently after one short month.

### Left for later

- **The benchmark figure**, above.
- **Query-plan verification** is written as a test asserting `EXPLAIN QUERY PLAN` names
  `ix_01_ledger_category_time`, per 4.6.1. Also unrun.
- **`STAGE_4_SCHEMA_COMPARISON.md` must be regenerated at 4.11** so it compares against the amended
  §3.12 rather than the original five-column table.
- **`ARCHITECTURE.md` §2.2's repository table is now three rows stale** — `SpendingRepository`,
  `BalanceRepository`, and `RedirectTarget` folded into `CategoryRepository`. Folding those back is
  a 4.11 documentation task, not a design change.

---

## 4.7 — Seed data, suggested categories and the sink (S04.07)

**Outputs:** `lib/data/seed/{seed_data,seeder}.dart`, `test/data/seed/seeder_test.dart`.

> **⚠ Still unverified — same toolchain gap.** Nothing compiled or run.

### Acceptance criteria — and the test written for each

| Criterion | Test | Status |
|---|---|---|
| Seeding an empty database produces a configuration that passes every validator from 4.8 | `seeding an empty database` group. **Partial by construction** — 4.8's validators do not exist yet, so this asserts V-01, V-02 and INV-07 directly. 4.8 must re-assert it through the real validator | not run |
| Default percentages total exactly 10000 at group level and within every group | `4.7.3` group, written first and as pure arithmetic with no database in sight | not run |
| Running the seeder twice is a no-op | `ROW COUNTS AND TIMESTAMPS ARE UNCHANGED BY A SECOND RUN` | not run |
| A user edit to a seeded category survives a re-run | `A RENAMED AND RETYPED SUGGESTION IS LEFT ALONE`, plus a deleted suggestion staying deleted | not run |
| The sink exists, is uncapped, and is flagged non-deletable | `INV-07 — the sink exists, is uncapped, and settings point at it` | not run |
| Every seeded category can be renamed, retyped, re-ceilinged and removed | `the sink cannot be deleted, but everything else can` — loops over all 14 non-sink rows and deletes each | not run |

### The percentages are computed, not written down

No default split is prescribed anywhere in the PRD, the manifest or SCHEMA, so the numbers are mine.
The named pitfall makes the trap explicit: *"default percentages that total 9999 because of a
hand-computed split, which blocks onboarding."* Nine savings categories at a hand-written 1111 total
9999, and a user who accepts the defaults cannot finish onboarding.

So nothing is hand-computed. `distributeEvenly` splits 10000 across N shares with the remainder
spread one basis point at a time — largest-remainder, the same rule the allocation engine uses, so
the app never rounds two different ways. The totals are exact **by construction**, and adding a
twentieth suggestion later cannot break them. The test sweeps every part-count from 1 to 40.

The group-level defaults are an even 50/50 personal, 40/30/30 with business. An even split is the
honest default: which of spending and saving should dominate is not a recommendation this app is
qualified to make, and the user changes it in onboarding.

**The sink gets a zero share, not an absent one.** It is where overflow lands, not a destination
anyone chose a percentage for — a base share would quietly divert income away from the goals the
user actually set. Zero is legal (C-01 permits 0–10000) and meaningfully different from absent: the
line exists, so the sink shows in the percentage editor at 0% rather than being missing from it.

### Suggested amounts are placeholders, and openly so

`ACCUMULATING_RESERVE` requires a ceiling (V-08) and `FIXED_RECURRING` requires a bill and anchor
day (V-18), so ten of the nineteen suggestions cannot be stored at all without amounts the app
cannot know. Nobody can say what a stranger's Hajj fund should hold.

The resolution is to supply obviously-provisional round figures and **flag every row
`is_suggested_seed` with a `seed_version`**, which is exactly what 4.7.2 asks the flag for: telling
an untouched suggestion from a user's own creation. Stage 6's onboarding walks the user through
confirming each. Inventing a figure that looked authoritative would have been worse than one that
plainly wants changing.

**Amounts are held in major units and scaled by the seeder.** A ceiling of 50,000 is 5,000,000 minor
units in PKR, 50,000 in JPY and 50,000,000 in KWD. Storing minor units in the seed file would bake
in two decimal places, which the manifest's engineering conventions forbid outright. A test seeds
the same set in JPY and asserts the Hajj ceiling is not 100× wrong.

### Idempotent and non-destructive are two promises, held by one rule

They sound identical and are not: a seeder could be idempotent by writing the same rows every time
and still destroy an edit by overwriting it with the original. Both fall out of **the seeder only
inserting, and only when the group is empty**. It has no update path at all, which is the only
reliable answer to *"a seeder that overwrites user edits on every app launch."*

"Already seeded" is decided by **the presence of the group, not a flag in settings**. A flag can
disagree with the database — after a restore, a merge, or a user deleting everything — and when it
does, the seeder either refuses to help an empty install or floods a populated one.

The gate is **per group**, so enabling business scope later seeds that group alone rather than the
presence of Spending making the whole call a no-op.

### Three bugs found while writing it

- **U-04 violation.** Seeding the business group later created a *second* unsealed rule version while
  the first was still a draft, which the partial unique index rejects — aborting the entire seed.
  Fixed by reusing the existing draft; a new version is minted only when there is no draft to join,
  which is also the correct behaviour when the old one has been sealed by an income event (INV-11).
- **An invalid settings insert.** The first draft tried to create the `app_settings` row to hold
  `active_rule_version_id`. That row's currency is the one value in this app that must never be
  guessed (V-24 freezes it the moment money is recorded). The seeder now **requires** the settings
  row and refuses with `RecordNotFound` if it is absent — which also makes the onboarding ordering
  explicit rather than accidental.
- Both settings updates carry `AND <column> IS NULL`, so a user who has already nominated a
  different sink or moved to a later rule version is not dragged back by a re-run.

### Judgement calls, flagged rather than buried

- **Deterministic seed ids were considered and rejected.** Two devices seeding independently while
  offline produce two full sets of categories, which merge into 38. UUID v5 over a fixed namespace
  would make the merge a no-op. It is **not** done here, because ARCHITECTURE §8.6 assigns v4 to
  configuration records and deviating would mean amending an approved document unilaterally for a
  problem **Stage 7.8 already owns** — new-device bootstrap must not seed before checking for a
  remote. Recorded here so 7.8 inherits the constraint rather than rediscovering it.
- **No reset-to-suggestions path.** 4.7.8 says *"if the design calls for one"*, and nothing in the
  PRD, NAVIGATION or the manifest does. Building a destructive action nobody asked for would be
  inventing scope; if Stage 6 wants one, the seeder's insert-only shape makes it easy to add safely.
- **The first criterion cannot be fully met yet.** It asks that seeding produce a configuration
  passing *"every validator from substage 4.8"*, and 4.8 has not been written. The tests assert the
  rules those validators will encode — V-01, V-02, INV-07, the sink being uncapped — but 4.8 must
  re-run this assertion through the real validator once it exists. Noted as a 4.8 obligation.
