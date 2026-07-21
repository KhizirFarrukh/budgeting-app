# Stage 3 — Project Scaffolding — worklog

Evidence log, one entry per substage.

| Substage | Name | Status |
|---|---|---|
| 3.1 | Project initialisation and Android configuration | ✅ Complete |
| 3.2 | Directory structure and layer boundaries | ✅ Complete |
| 3.3 | Dependencies and the code generation toolchain | ✅ Complete |
| 3.4 | Linting, formatting and invariant guard checks | ✅ Complete |
| 3.5 | Continuous integration pipeline | ✅ Complete |
| 3.6 | Theme, design tokens and the money formatter | Not started |
| 3.7 | Router and stub screens | Not started |
| 3.8 | Test harness, fakes and fixtures | Not started |
| 3.9 | Scaffold verification and gate preparation | Not started |

---

## Stage entry

Entry criteria required Flutter installed with no blocking Android issues. **The toolchain was
absent at stage start** and had to be installed; work was blocked for three exchanges rather than
producing unverifiable artefacts. Two infrastructure gaps surfaced during setup and are recorded in
`ENVIRONMENT.md` §3 and §9 so they are recognisable rather than mysterious on another machine:

1. **Gradle could not auto-download the NDK** — `Failed to download package! Install NDK (Side by
   side) 28.2.13676358`. Fixed by installing it explicitly with `sdkmanager`.
2. **No emulator AVD existed and no system image was installed.** Created `pookie_test` on Android
   16 (`google_apis;x86_64`).

`flutter doctor` still reports ✗ for Chrome and Visual Studio. **Both are out of scope by design** —
NG-09 (no web version) and Android-only — so neither is a blocking Android issue.

---

## 3.1 — Project initialisation and Android configuration (S03.01)

**Outputs:** Flutter project skeleton, `docs/ENVIRONMENT.md`.

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| `flutter build apk --debug` succeeds with no template warnings | Second attempt succeeded in 153.5s producing a 139.4 MB APK; output in `ENVIRONMENT.md` §10 | ✅ |
| The app installs and launches to its own first screen, not the Flutter demo | Installed on `emulator-5554`, activity resumed (PID 5081), **screenshot captured and visually inspected** — app bar "PookieBudget", body "Scaffold placeholder" | ✅ |
| `ENVIRONMENT.md` records every version and the `minSdk` justification | §2–§6, including the resolved `minSdk` read from the built artefact | ✅ |
| The application id is final and recorded | `com.khizirfarrukh.pookiebudget`, §1, with its permanence stated | ✅ |

### Decisions

**`compileSdk` and `targetSdk` pinned to 36 rather than inherited.** Play policy was checked on the
web on 2026-07-21 rather than recalled: new apps and updates must target **Android 16 (API 36) from
31 August 2026** — six weeks away. Inheriting `flutter.targetSdkVersion` would have meant shipping
something that needed an immediate bump. Re-verified at 10.4.5 before upload.

**`minSdk` left at the Flutter SDK's own floor, then read back from the artefact.** Substage 3.1.3
forbids guessing a number. The merged manifest and `aapt2 dump badging` both report **24**. Substage
3.3.2 re-checks it once plugins land, since the Google Sign-In client is the likeliest to raise it.

> Reading the **built artefact** rather than the build file is deliberate, and the same discipline
> substage 4.3.6 applies to the database schema: it proves what was produced, not what was intended.

**Backup disabled deliberately, not left at the platform default.** Android's default
`allowBackup="true"` would copy the app's database — every financial record — to Google's backup
service, contradicting PRD §6.10 and what 9.7.3 verifies on the release build. Implemented as an
explicit `data_extraction_rules.xml` excluding every domain, with 9.7.3 named as the substage that
revisits it.

**No permissions declared at all.** `INTERNET` arrives in Stage 7. NFR-02 requires every core flow to
complete with no network and no account, so nothing before then needs one.

### Template removal

`main.dart` rewritten as a composition root only; `app.dart` holds a placeholder that identifies
itself as unfinished; `widget_test.dart` deleted; the generated README replaced with a docs index. A
scan for `counter`, `_incrementCounter`, `floatingActionButton`, `MyHomePage`, `MyApp` and
`Flutter Demo` across `lib/`, `test/` and `README.md` returns **no matches**.

---

## 3.2 — Directory structure and layer boundaries (S03.02)

**Outputs:** the directory tree, four layer READMEs, three domain placeholder types.

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| The created tree matches `ARCHITECTURE.md` §4.2 with no undocumented additions | Tree listed and compared directory by directory; three deviations recorded below | ✅ |
| A search for `package:flutter` under the domain directory returns nothing | `grep -rn --include='*.dart' -E "import\s+'(package:flutter/\|dart:io\|dart:ui)" lib/domain/` → **clean** | ✅ |
| Each layer folder has its `README.md` | `lib/domain`, `lib/data`, `lib/application`, `lib/presentation` — four written, each stating what belongs, what must never appear, and which guard enforces it | ✅ |
| `test/` mirrors `lib/` | Both trees listed; every `lib/` layer has its `test/` counterpart, plus `fixtures/` and `support/` | ✅ |

`flutter analyze` reports **"No issues found!"** on the scaffold.

### Placeholder types

Three real domain files rather than empty stubs, chosen because they are needed by everything later
and carry no logic to get wrong:

- `domain/result.dart` — the sealed `Result<T, F>` for expected failures (ARCHITECTURE §8.1)
- `domain/money/clock.dart` — the `Clock` interface guard G4 protects
- `domain/money/id_generator.dart` — the `IdGenerator` interface, documenting the v7/v4 split

### Deviations from `ARCHITECTURE.md` §4.2, recorded per 3.2.5

| Deviation | Reason |
|---|---|
| Root directory is `budgeting-app`, not `budgeting_app` | The document's tree label was illustrative. The repository directory is `budgeting-app` and the **Dart package** is `pookiebudget`, which is what actually matters for imports |
| `.gitkeep` files in 56 otherwise-empty directories | Git does not track empty directories, so the tree would not survive a clone without them. Each states its origin and that it should be removed once the directory holds real content |
| `android/`, `.metadata`, `analysis_options.yaml`, `pubspec.yaml`, `pubspec.lock` present | Generated by `flutter create`; not in the design tree because §4.2 documents the source layout, not the whole project |

### Finding carried to 3.4

The G4 pre-check (`DateTime.now()` outside the `Clock`) **fired on a documentation comment** in
`clock.dart` that legitimately names the forbidden call. This is exactly the pitfall substage 3.4
warns about:

> *"A grep-based guard with a pattern so loose it fires on comments, which then gets disabled."*

**The real guards must strip comments before matching.** Recorded now so 3.4 implements it rather
than discovering it when the first false positive lands. A guard that cries wolf is a guard someone
switches off.

---

## 3.3 — Dependencies and the code generation toolchain (S03.03)

**Outputs:** `pubspec.yaml` + `pubspec.lock`, `docs/DEPENDENCIES.md`, generated code proven.

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| `flutter pub get` resolves with no conflicts and no unexplained discontinued-package warning | Resolves cleanly at 149 packages. **One discontinued package was found and removed**, one rejected, two dropped — all four explained in `DEPENDENCIES.md` §4 | ✅ |
| The code generation command runs successfully against a placeholder | `build_runner` produced 15 outputs in 26s — `riverpod_generator` and `drift_dev` both ran; `flutter analyze` clean afterwards | ✅ |
| `DEPENDENCIES.md` lists every direct dependency with purpose, licence and exit plan | §1 and §2. Licence handled as ADR-004 constraint **L2** — permissive only, copyleft a blocker — rather than asserted per package from memory | ✅ |
| The resolved tree contains no telemetry, analytics or advertising package | 13 known packages scanned across all **149 resolved** entries, not just direct dependencies → clean | ✅ |
| The `minSdk` floor is re-verified against installed plugins and recorded | Rebuilt with **all** plugins present; merged manifest still reports 24 | ✅ |

### The finding this substage exists to produce

**`minSdk` remains 24 — no plugin raised the floor.** Substage 3.3's `common_pitfalls` names the
failure being pre-empted: *"Discovering in Stage 7 that the Google client raised minSdk above the
level already advertised."*

The Stage 7 and Stage 8 plugins (`google_sign_in`, `googleapis`, `connectivity_plus`, `share_plus`,
`workmanager`, `fl_chart`) were added **now** rather than when first used, precisely so this question
is answered while it is cheap. Read from the merged manifest of a build with everything present, not
predicted.

### Three dependency findings

**`sqlite3_flutter_libs` — discontinued, removed.** Resolved as `0.6.0+eol`; from 0.6.0 the package
**does nothing at all**, existing only as a migration marker. Drift 2.32+ bundles SQLite
automatically and this project resolves 2.34.2. Removed.

**`glados` — the ADR-004 fallback fired, exactly as written.** Version solving failed: it requires
`uuid ^3.0.6` and declares pre-null-safety SDK bounds. ADR-004 had already pre-decided the fallback
— hand-rolled generators with a seeded PRNG — so there was no mid-implementation decision to make.
**Only automatic shrinking is lost.** Properties P1–P7 are defined in ALLOCATION_ALGORITHM §9.2
independently of any library, so this changes how they are verified, never what.

**`riverpod_lint` + `custom_lint` — dropped, and the trade is a real one.** Both force `uuid ^3.0.6`
via `analyzer`/`analyzer_plugin` constraints. But `uuid` 4.x is what provides **UUID v7**, which
ARCHITECTURE §8.6 assigns to ledger entries and income events for index locality — PRD §7.2 shows
those are **80–89% of all rows** at the Heavy profile. Downgrading `uuid` to satisfy a lint plugin
would surrender a decision made on measured grounds.

> The lint plugins lose. They offer Riverpod-specific advice; they enforce **none** of the twelve
> invariants. Those are enforced by guards G1–G6, which are this project's own and independent of
> the analyzer plugin ecosystem.

Verified afterwards that `uuid` 4.6.0 genuinely exports v7, rather than assuming the trade was worth
making. Re-check at Stage 6 — if the plugins become compatible, adding them costs nothing.

### Decision — generated code is not committed (3.3.4)

`*.g.dart`, `*.freezed.dart`, `*.mocks.dart` are gitignored. Generated files in a diff obscure the
real change, and **regenerating in CI verifies that generation still works on every push** — stronger
than trusting a committed artefact that may no longer match its source. The cost is a `build_runner`
step before analyze or test on a fresh clone, which CI performs and `DEVELOPMENT.md` documents.

### Codegen probes

Two deliberately trivial files prove both generators end to end before any real schema depends on
them: `lib/data/database/database.dart` (one Drift table) and
`lib/application/providers/codegen_probe.dart` (one provider). Both are documented as disposable —
4.3 and 6.1 replace them wholesale.

Even the probe honours the schema conventions, so nobody copies a violation out of it: a **TEXT**
primary key rather than auto-increment (INV-12), and money as **INTEGER** minor units (INV-01).

---

## 3.4 — Linting, formatting and invariant guard checks (S03.04)

**Outputs:** `analysis_options.yaml`, `tool/guards/guards.dart`, `docs/DEVELOPMENT.md`.

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| `flutter analyze` returns zero issues on the scaffold | "No issues found!" under strict settings (`strict-casts`, `strict-inference`, `strict-raw-types`, plus promoted errors) | ✅ |
| Each guard demonstrated failing on a deliberate violation, output captured | **All six**, output below. Two failed to fire on the first attempt and were fixed — see the finding | ✅ |
| The formatting check runs and passes | `dart format --output=none --set-exit-if-changed .` → exit 0, "0 changed" | ✅ |
| `DEVELOPMENT.md` documents how to run every check locally | §2 the full sequence, §3 codegen, §4 the guards, §6 tests, §9 known gotchas | ✅ |

### The demonstration — every guard shown failing (3.4.6)

```
G1 — domain imports package:flutter        → G1  lib/domain/result.dart:1
G2 — engine file uses async/Future         → G2  lib/domain/allocation/_probe.dart:1
G3 — double on the money path              → G3  lib/domain/_probe.dart:1
G4 — DateTime.now() outside the Clock      → G4  lib/application/_probe.dart:1
G5 — presentation imports the database     → G5  lib/presentation/_probe.dart:1
G6 — telemetry in the resolved tree        → G6  pubspec.lock:1187

REVERTED → "All guards passed (G1-G6)."  exit 0
working tree clean, no probe files left behind
```

### The finding — two guards were inert, and only the demonstration caught it

**On the first run, G1 and G5 did not fire at all.**

The cause: the comment-stripper also stripped **string literals**, so that a banned word inside a
message could not trip a token guard. But **an import path is a string literal**. With stripping on,
`import 'package:flutter/material.dart';` became `import ;` — and both layering guards matched
nothing, ever.

They passed their baseline. They looked correct. They enforced **nothing**.

> This is the entire justification for substage 3.4.6 and its `must_not`: *"Do not claim a guard
> works without demonstrating a failure."* Baseline-passing is not evidence — a guard that never
> matches also passes its baseline. G1 and G5 protect the layer boundary that INV-08's testability
> rests on, and they would have been silently inert for the next seven stages.

**Fix:** `_scan` gained a `stripStrings` flag. Token guards (G2, G3, G4) keep stripping on; import
guards (G1, G5) switch it off. Both the script header and `DEVELOPMENT.md` §4 record why, so nobody
"tidies" it back.

### A second false-positive class, caught earlier at 3.2

The 3.2 pre-check fired on a documentation comment in `clock.dart` that legitimately names
`DateTime.now()`. That is why the guards are a Dart script rather than a grep: every check strips
comments before matching. Substage 3.4's pitfall — *"a grep-based guard with a pattern so loose it
fires on comments, which then gets disabled"* — was avoided by design rather than discovered later.

**The two findings pull in opposite directions**, which is precisely why both needed demonstrating:
too little stripping produces false positives that get the guard switched off; too much produces
false negatives that make it useless while looking healthy.

### Six guards, not four

The stage plan names four (money, time, layering, telemetry). ARCHITECTURE §2.3 specified six, and
all six are implemented: **G2** engine purity (INV-08 is stronger than general layering and deserves
its own check) and **G5** database containment (explicitly required by substage 2.2.3's wording).

### Strict analyser settings

`strict-casts`, `strict-inference` and `strict-raw-types` all on; `missing_return`, `unused_import`,
`dead_code` and `invalid_override` promoted to **errors**. `always_use_package_imports` was enabled
and immediately caught a relative import in `main.dart`, now fixed.

One rule was removed after the analyser reported it: `package_api_docs` was removed in Dart 3.7.0.
Recorded rather than silently dropped.

---

## 3.5 — Continuous integration pipeline (S03.05)

**Outputs:** `tool/check.ps1`, `.github/workflows/ci.yml`, `test/domain/result_test.dart`.

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| The pipeline, or an equivalent single local command, runs every check in one invocation | `tool/check.ps1` runs seven steps: pub get, codegen, format, analyze, guards, tests+coverage, debug build | ✅ |
| It runs green on the scaffold commit, with output captured | `ALL CHECKS PASSED (6 steps)`, exit 0 — output below | ✅ |
| A deliberate formatting break turns it red, demonstrated and reverted | Exit **1** with the offending file named; exit **0** after revert; tree clean | ✅ |
| A coverage figure is produced, even though it is near zero | **16/26 lines (61.5%)** | ✅ |

### Full run output

```
[1] Resolve dependencies      ok
[2] Code generation           ok
[3] Format check              ok    Formatted 10 files (0 changed)
[4] Static analysis           ok    No issues found!
[5] Invariant guards G1-G6    ok    All guards passed (G1-G6).
[6] Tests with coverage       ok    +5: All tests passed!

Coverage: 16/26 lines (61.5%)
==========================================================
ALL CHECKS PASSED (6 steps)      exit 0
```

### The red-then-green demonstration (3.5.6)

```
=== deliberate formatting violation ===
Changed lib\domain\result.dart
Formatted 11 files (1 changed)
format exit code: 1                    <- pipeline would go RED

=== reverted ===
Formatted 11 files (0 changed)
format exit code after revert: 0       <- green again
git status: clean
```

### The check script found a real problem immediately

Its first run **failed** — `Test directory "test" does not appear to contain any test files.` The
template test was deleted in 3.1 and nothing had replaced it.

That is the script working. **A pipeline that cannot go green has not been verified**, so 3.5.5
cannot be satisfied without at least one test. `test/domain/result_test.dart` was added: five cases
covering the sealed `Result` type — value carrying, failure carrying, value equality, cross-type
inequality, and that an exhaustive `switch` compiles without a default clause.

It is deliberately a **real** test of a **real** type, not a placeholder that asserts nothing.
Substage 9.1's `must_not` — *"do not write a test that asserts only that a widget rendered"* — is
worth applying from the first test rather than from Stage 9. The full harness (fakes, builders, the
golden-vector loader) remains substage 3.8's job.

### One authority, two callers

`tool/check.ps1` is the authority; `.github/workflows/ci.yml` mirrors its steps. Substage 3.5.7 makes
the requirement explicit — *"one command runs every check, not that a particular host runs it"* — and
keeping the workflow a mirror means a green pipeline and a green local run mean the same thing.

The workflow pins **Flutter 3.44.7**, matching `ENVIRONMENT.md` §2, so a version bump is a deliberate
act that updates that document too.

### Decisions

**Codegen runs in CI on every push**, following from the 3.3.4 decision not to commit generated
files. It verifies generation still *works*, which is stronger than trusting a committed artefact
that may no longer match its source.

**Coverage is captured now, at 61.5%**, while it is near zero and meaningless — so the trend is
visible from the first commit rather than appearing for the first time in Stage 9 (substage 3.5.4).

**Box-drawing characters replaced with ASCII.** They rendered as mojibake in the Windows console
host. Cosmetic, but a check script whose output looks broken invites being ignored.


