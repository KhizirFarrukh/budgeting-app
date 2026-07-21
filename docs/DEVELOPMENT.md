# Development

How to work on PookieBudget locally. Written in substage 3.4.8.

Exact tool versions: [`ENVIRONMENT.md`](ENVIRONMENT.md). Dependency rationale:
[`DEPENDENCIES.md`](DEPENDENCIES.md).

---

## 1. Setup from a clean checkout

```powershell
flutter pub get
flutter pub run build_runner build
```

**The generation step is not optional.** `*.g.dart` files are gitignored (decision recorded in
substage 3.3.4), so a fresh clone has no generated code and `flutter analyze` will fail until
`build_runner` has run.

### If `flutter` is not on your PATH

It is not on every shell on this machine. Invoke it by full path:

```powershell
& "$env:USERPROFILE\flutter\bin\flutter.bat" <args>
& "$env:USERPROFILE\flutter\bin\dart.bat" <args>
```

## 2. The full check sequence

Run all of it before pushing. Substage 3.5 wires the identical sequence into CI.

```powershell
flutter pub get
flutter pub run build_runner build
dart format --output=none --set-exit-if-changed .
flutter analyze
dart run tool/guards/guards.dart
flutter test
flutter build apk --debug
```

Any non-zero exit is a failure. **The analyser must be clean, not merely error-free** — substage
3.5.3 fails the pipeline on any analyser issue, including warnings and infos.

## 3. Code generation

Two generators run: `drift_dev` (database classes) and `riverpod_generator` (providers).

```powershell
# One-off
flutter pub run build_runner build

# Watch while developing
flutter pub run build_runner watch

# When output is stale after a refactor
flutter pub run build_runner build --delete-conflicting-outputs
```

Generated files are gitignored. If analysis complains about a missing `_$Something`, the answer is
almost always that generation has not been run.

## 4. The guards — what they are and why they matter

`dart run tool/guards/guards.dart` enforces six invariants the analyser cannot express. Specified in
[`ARCHITECTURE.md`](ARCHITECTURE.md) §2.3.

| Guard | Enforces | Invariant |
|---|---|---|
| **G1** | `lib/domain` imports no Flutter, `dart:io`, `dart:ui`, I/O package, or outer layer | Layering |
| **G2** | `lib/domain/allocation` contains no `async`/`await`/`Future`/`Stream`, no `DateTime.now()`, no `Random` | INV-08 |
| **G3** | No `double`/`float`/`num` in `lib/domain` or `lib/data` | INV-01 |
| **G4** | `DateTime.now()` appears only in the `Clock` implementation | INV-09 |
| **G5** | Only `lib/data` imports the database package | Layering |
| **G6** | No analytics, crash-reporting or advertising package in the **resolved** tree | NG-04, NG-08, NFR-01 |

### If a guard fires

**Fix the code, not the guard.** Substage 3.4's `must_not` is explicit: *"Do not weaken a guard to
make existing code pass."* If you believe a guard is genuinely wrong, that is a design question —
amend `ARCHITECTURE.md` and say so, rather than adding a silent exception.

The one legitimate exception in the codebase is `data/clock_impl.dart`, which G4 skips by name
because it is where the real clock must live.

### How they avoid false positives

Every check strips comments before matching, so prose naming a forbidden construct cannot trip a
guard. String literals are stripped only for the **token** guards (G2, G3, G4); the **import**
guards (G1, G5) keep strings intact, because an import path *is* a string literal.

> That distinction was found the hard way. On the first run of the deliberate-violation
> demonstration, G1 and G5 stripped strings too — turning every
> `import 'package:flutter/x.dart';` into `import ;`. Both passed their baseline and detected
> nothing at all. They were caught only because substage 3.4.6 requires every guard to be shown
> **failing**, not merely to look correct.

## 5. Running on a device

```powershell
flutter emulators --launch pookie_test
flutter run
```

An emulator is adequate through Stage 8. **Stage 9 requires a physical mid-tier device** — NFR-06
forbids measuring performance on a flagship, or on a desktop-CPU emulator, and reporting it as
representative.

## 6. Tests

```powershell
flutter test                          # unit and widget
flutter test test/domain/allocation   # one directory
flutter test --coverage               # with coverage
flutter test integration_test         # on a device or emulator
```

Test layout mirrors `lib/` exactly, so a test's location is always predictable from the file it
covers: `lib/domain/allocation/split.dart` → `test/domain/allocation/split_test.dart`.

## 7. Git conventions

**Branches.** `master` → `develop` → `v1.0`. Work lands on `v1.0`. *(This supersedes the stage-branch
convention in the project manifest, at the maintainer's direction.)*

**Commits.** Conventional Commits: `feat(scope):`, `fix(scope):`, `docs(scope):`, `design(scope):`,
`chore:`. One commit per substage, with the substage number in the subject.

**Tags.** `v0.<stage>.0` at each approved stage gate.

**Line endings.** `.gitattributes` stores everything LF. Windows scripts (`.bat`, `.cmd`, `.ps1`)
keep CRLF. Migration fixture databases and golden images are marked binary so they survive
byte-identical.

## 8. Working the staged plan

This project follows a 10-stage plan in `prompts/`. Rules that matter day to day:

- **One substage at a time, in order.** No parallelising, no skipping.
- **Nothing is complete because code was written.** It is complete when its acceptance criteria are
  demonstrably met, with real command output recorded in the stage worklog.
- **Every stage ends at a gate** requiring explicit approval before the next begins.
- **Design documents are authoritative.** If implementation needs to differ, amend the document and
  record the amendment — do not silently diverge.

## 9. Known local gotchas

| Symptom | Cause and fix |
|---|---|
| `Failed to download package! Install NDK ...` | Gradle cannot auto-install the NDK. Run `sdkmanager "ndk;28.2.13676358"` |
| `Android sdkmanager not found` | `cmdline-tools` missing. Android Studio → SDK Manager → **SDK Tools** tab → tick *Android SDK Command-line Tools (latest)* |
| Analyser reports missing `_$Foo` | Code generation has not run — see §3 |
| `flutter doctor` ✗ on Chrome / Visual Studio | Expected and ignorable. Web is NG-09 and Windows desktop is out of scope; neither is a blocking Android issue |
| PowerShell mangles a UTF-8 document | Do not round-trip files through PS 5.1's `Get-Content`/`Set-Content` — it reads UTF-8 as ANSI. Use an editor or the Dart/Node toolchain |
