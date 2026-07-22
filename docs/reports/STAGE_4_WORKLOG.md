# Stage 4 — Core Data Layer — worklog

Evidence log, one entry per substage.

| Substage | Name | Status |
|---|---|---|
| 4.1 | The Money type and core value types | ✅ Complete |
| 4.2 | Domain entities and enumerations | ✅ Complete |
| 4.3 | Database schema and code generation | ⬜ Not started |
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
