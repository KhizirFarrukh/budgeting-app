# Stage 3 — Project Scaffolding — worklog

Evidence log, one entry per substage.

| Substage | Name | Status |
|---|---|---|
| 3.1 | Project initialisation and Android configuration | ✅ Complete |
| 3.2 | Directory structure and layer boundaries | ✅ Complete |
| 3.3 | Dependencies and the code generation toolchain | Not started |
| 3.4 | Linting, formatting and invariant guard checks | Not started |
| 3.5 | Continuous integration pipeline | Not started |
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
