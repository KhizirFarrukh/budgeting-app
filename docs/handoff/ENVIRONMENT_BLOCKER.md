# Environment blocker — no Dart/Flutter toolchain

**Status: OPEN.** This is the single most important fact about the current state of the repository.

---

## What is wrong

`docs/ENVIRONMENT.md` §2 records the Flutter SDK at:

```
C:\Users\Chichum\flutter
```

The machine substages 4.4–4.7 were written on has **only one user profile, `Khizi`**. A recursive
search of `C:\` (depth 5–6) found:

- no `flutter.bat`
- no `dart.exe`
- nothing on `PATH` matching `dart` or `flutter`
- no `.dart_tool/` directory in the project
- no pub cache under `%LOCALAPPDATA%\Pub\Cache`

The project was evidently developed on a different machine or profile. `pubspec.lock` is committed,
so dependency versions are pinned and recoverable.

## What that means

**`lib/data/database/database.g.dart` has never been generated here.** Every Drift row class,
companion and table accessor referenced by substages 4.4–4.7 was written against the *expected*
generated names, derived from the table definitions and knowledge of the Drift 2.34 API — not from a
compiler.

None of the following has ever run against this code:

- `flutter pub get`
- `flutter pub run build_runner build`
- `dart format`
- `flutter analyze`
- `dart run tool/guards/guards.dart`
- `dart run tool/domain_purity_check.dart`
- `flutter test`

## What *was* done instead

Static checks that do not need a toolchain were run by hand on every file, and all pass:

| Check | Method |
|---|---|
| Bracket/paren/brace balance | Character counting per file |
| `library;` directive placement | Must precede all imports |
| Unused project imports | Symbol cross-reference against each imported file |
| Guard **G2** equivalent | No `async`/`await`/`Future`/`Stream`/`DateTime.now`/`Random` under `lib/domain/allocation/` |
| Guard **G3** equivalent | No `double`/`float`/`num` tokens in `lib/domain` or `lib/data` |
| Domain interface purity | No persistence type name or `package:drift` import in `lib/domain/repositories/` |
| Line length | No **code** line over 80 characters (string literals excepted — `dart format` cannot split them) |

These reduce risk. **They are not a substitute for a build.**

---

## The verification sequence — run this first

On a machine with Flutter 3.44.7 / Dart 3.12.2 (per `docs/ENVIRONMENT.md`), from the repository
root:

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
dart format .
flutter analyze
dart run tool/guards/guards.dart
dart run tool/domain_purity_check.dart
flutter test
```

Or simply, which is the authority and runs all of the above:

```powershell
pwsh tool/check.ps1 -SkipBuild
```

### What to expect, in likely order

1. **`build_runner` failures first.** If any generated name was guessed wrong, this is where it
   surfaces. Most likely candidates: the `$AppSettingsTableTable` accessor name, companion
   constructor required-parameter sets, and `BalanceCacheRow` / `BalanceCacheCompanion`.
2. **`dart format` will change files.** Formatting was done by hand. CI uses
   `--set-exit-if-changed`, so **run `dart format .` and commit the result before pushing**.
3. **`flutter analyze` next.** Strict settings: `strict-casts`, `strict-inference`,
   `strict-raw-types`, and `unused_import` promoted to an *error*.
4. **`domain_purity_check` should pass** — it was extended for every new `lib/domain` file
   (`period.dart`, and the six repository interface files). Its completeness assertion fails if a
   file under `lib/domain` is not imported by it, so a *new* domain file will trip it.
5. **Tests last.** Expect real failures here; they have never run.

### Known-risky API assumptions to check first if something fails

| Assumption | Where | Note |
|---|---|---|
| `InsertMode.insertOrIgnore` | `lib/data/repositories/ledger_writer.dart` | Load-bearing for INV-12 idempotency. Must **not** become `insertOnConflictUpdate` |
| `customInsert(sql, variables:, updates:)` | `ledger_writer.dart` | Upsert into `balance_cache` |
| `customUpdate(sql, variables:, updates:)` | several repositories | `updates:` is what makes `.watch()` streams re-emit |
| `batch.insertAll(table, companions)` | `test/data/balances/balance_benchmark_test.dart` | Bulk insert |
| `$CategoriesTable`, `$LedgerEntriesTable`, `$AppSettingsTableTable` | private helpers in data repositories | Generated table class names |
| `CategoriesCompanion.insert(...)` required params | `lib/data/seed/seeder.dart` | Which columns are required vs `Value<>` |

---

## Also unmeasured: the 4.6.6 benchmark

Substage 4.6's fifth acceptance criterion is *"derivation timing at five-year volume is recorded and
within the NFR-06 budget"* (P-13: ≤ 2 s). **It requires a measured number and cannot be met without
running.**

`test/data/balances/balance_benchmark_test.dart` exists, builds a 67,000-entry / 100-category ledger
(the PRD Heavy profile), times `recomputeAll` + `verify`, and prints the figure. The worklog cell is
**deliberately empty**. When you run it:

1. Paste the printed figure into `docs/reports/STAGE_4_WORKLOG.md` under 4.6.
2. Do **not** substitute SCHEMA §7.1's 40–80 ms estimate — that estimate is precisely what 4.6.6
   exists to replace.

The same test asserts `EXPLAIN QUERY PLAN` names `ix_01_ledger_category_time`, which is substage
4.6.1's query-plan verification. Also unrun.

---

## When this is resolved

1. Run the sequence above; fix what it reports.
2. Update `docs/ENVIRONMENT.md` §2 with the SDK path on the machine that actually builds.
3. Flip 4.4–4.7 from 🟡 to ✅ in `docs/reports/STAGE_4_WORKLOG.md`, replacing every *"not run"* in
   the acceptance-criteria tables with real evidence.
4. Delete this file, or reduce it to a historical note.
