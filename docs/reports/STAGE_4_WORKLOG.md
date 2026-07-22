# Stage 4 — Core Data Layer — worklog

Evidence log, one entry per substage.

| Substage | Name | Status |
|---|---|---|
| 4.1 | The Money type and core value types | ✅ Complete |
| 4.2 | Domain entities and enumerations | ⬜ Not started |
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
