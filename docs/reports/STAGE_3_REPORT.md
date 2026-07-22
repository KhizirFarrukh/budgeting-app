# Stage 3 report — Project Scaffolding

**Stage:** S03 · **Substages:** 9 of 9 complete · **Status:** awaiting approval gate
**Branch:** `v1.0` · **Date:** 2026-07-22

---

## 1. What was produced

| Artefact | Description |
|---|---|
| Flutter project | Android-only, `com.khizirfarrukh.pookiebudget`, builds and launches |
| `lib/` tree | Four layers, layer-first, matching ARCHITECTURE §4.2 |
| `tool/guards/guards.dart` | Six invariant guards G1–G6, each demonstrated failing |
| `tool/check.ps1` | One command running every check |
| `.github/workflows/ci.yml` | Mirrors the check script step for step |
| `lib/presentation/theme/` | Tokens, light and dark themes, business scope extension |
| `lib/domain/money/` | `Currency`, `MoneyFormat` — the serialisation half of ARCHITECTURE §8.5 |
| `lib/presentation/formatting/` | Locale-aware display formatter, built on the domain one |
| `lib/presentation/router/` | 29 routes — 28 designed paths plus the developer menu |
| 22 stub screens | Each names its substage, purpose and journey step; no data of any kind |
| `test/support/` | Fake clock, deterministic id generator, vector loader, builders |
| `docs/ENVIRONMENT.md` | Every version, read from tooling |
| `docs/DEPENDENCIES.md` | 21 direct dependencies with purpose, maintenance signal, exit plan |
| `docs/DEVELOPMENT.md` | Local setup, the check sequence, the guards, known gotchas |

**78 tests pass. Coverage 74%. Analyser clean. All six guards pass.**

## 2. Stage definition of done

| Criterion | Result |
|---|---|
| The app builds and launches on a real device or emulator | ✅ Verified by screenshot, not inferred from an exit code |
| Every screen from NAVIGATION.md exists as a reachable stub | ✅ 28 paths, one test each |
| `flutter analyze` clean and every guard demonstrably fails on a deliberate violation | ✅ Analyser clean; all six guards shown failing then reverted |
| CI or the equivalent local script runs green, output pasted | ✅ `ALL CHECKS PASSED (6 steps)` — §4 |
| No business logic, no database and no network code exists | ✅ Verified by search on a clean checkout — §5 |

## 3. Comparison tables (substage 3.9.1)

### 3.1 Directory tree

**40 designed directories, 40 present, zero differences.**

Three documented deviations, all recorded at 3.2.5:

| Deviation | Reason |
|---|---|
| Root is `budgeting-app`, not `budgeting_app` | The design tree's label was illustrative. The **Dart package** is `pookiebudget`, which is what imports actually use |
| 56 `.gitkeep` files | Git does not track empty directories, so the tree would not survive a clone |
| `flutter create` artefacts present | §4.2 documents the source layout, not the whole project |

### 3.2 Routes

| | |
|---|---|
| Designed screens (NAVIGATION §1) | 22 |
| Concrete paths (parameterised + new/edit pairs) | **28** |
| `GoRoute` entries in the router | **29** = 28 + developer menu |
| Route constants | **29** |
| Differences | **none** |

Reconciliation is asserted by test, in both directions: designed-but-missing and offered-but-undesigned are each checked.

### 3.3 Dependencies

All 21 ADR-named packages resolved:

```
flutter_riverpod    3.3.2      google_sign_in     7.2.0      build_runner        2.15.1
riverpod_annotation 4.0.3      googleapis        16.0.0      drift_dev           2.34.0
drift               2.34.2     googleapis_auth    2.3.3      riverpod_generator  4.0.4
drift_flutter       0.3.1      connectivity_plus  7.3.0      mocktail            1.0.5
path_provider       2.1.6      share_plus        13.2.1      flutter_lints       6.0.0
path                1.9.1      workmanager      0.9.0+3
uuid                4.6.0      fl_chart           1.2.0
go_router          17.3.0
intl               0.20.3
```

**All ADR-004 declined packages absent as direct dependencies:** `csv`, `get_it`, `injectable`,
`json_serializable`, `glados`, `riverpod_lint`, `custom_lint`.

**One clarification worth recording.** `sqlite3_flutter_libs` appears in `pubspec.lock` as
`dependency: transitive`, pulled in by `drift_flutter 0.3.1`. It was removed as a **direct**
dependency in 3.3 and that removal stands; the transitive copy is the `0.6.0+eol` release, which
**does nothing at all** by design. Recorded so the lockfile does not appear to contradict
`DEPENDENCIES.md`.

## 4. The full check from a clean checkout (substage 3.9.2)

Cloned to a fresh location — *"clean checkout matters: it catches anything that only works because
of local state."*

```
clean checkout at: b90c5e2
  .g.dart files present: 0      (gitignored, as decided in 3.3.4)
  lib/ dart files:      18
  test/ dart files:     10
  fixtures:              2

[1] Resolve dependencies      ok
[2] Code generation           ok
[3] Format check              ok
[4] Static analysis           ok    No issues found!
[5] Invariant guards G1-G6    ok    All guards passed (G1-G6).
[6] Tests with coverage       ok    +78: All tests passed!

Coverage: 248/335 lines (74%)
==========================================================
ALL CHECKS PASSED (6 steps)          exit 0
```

**This validates the 3.3.4 decision.** Generated code is gitignored, so a fresh clone contains none
— and the check sequence regenerates it and passes. Had generation been broken, this is where it
would have shown.

## 5. No business logic, persistence or network code (substage 3.9.4)

Searched on the clean checkout:

| Search | Result |
|---|---|
| Database connections (`openConnection`, `NativeDatabase`, `databaseFactory`) | **none** outside the codegen probe |
| Network (`HttpClient`, `http.get/post`, `Socket`, `WebSocket`) | **none** |
| Allocation arithmetic in `lib/domain/allocation/` | **empty** — the engine is Stage 5 |

The two codegen probes (`database.dart`, `codegen_probe.dart`) exist solely to prove the generators
run, are documented as disposable, and are replaced wholesale at 4.3 and 6.1.

## 6. Guard demonstrations (substage 3.4.6)

Each guard introduced a deliberate violation, fired, and was reverted:

```
G1 — domain imports package:flutter        → G1  lib/domain/result.dart:1
G2 — engine file uses async/Future         → G2  lib/domain/allocation/_probe.dart:1
G3 — double on the money path              → G3  lib/domain/_probe.dart:1
G4 — DateTime.now() outside the Clock      → G4  lib/application/_probe.dart:1
G5 — presentation imports the database     → G5  lib/presentation/_probe.dart:1
G6 — telemetry in the resolved tree        → G6  pubspec.lock:1187

REVERTED → "All guards passed (G1-G6)."  exit 0, tree clean
```

## 7. Device verification (substage 3.9.3)

| Check | Evidence |
|---|---|
| Builds and installs | `app-debug.apk`, installed on `emulator-5554` |
| Launches to its own screen | Screenshot: "PookieBudget" / "Scaffold placeholder" — no generated boilerplate |
| Routes reachable | Dashboard stub renders with six working navigation actions; 28 routes asserted by test |
| Dark mode | Screenshot in both modes; dark surface, legible light text |
| **200% font scale** | Screenshot at `font_scale 2.0` **in dark mode**: text wraps, buttons grow to two lines, **no clipping, overlap or truncation** |
| Integration harness | `flutter test integration_test -d emulator-5554` → `+1: All tests passed!` |

## 8. Findings

### 8.1 Two guards were completely inert — the stage's most valuable finding

On the first demonstration run, **G1 and G5 did not fire at all.**

The comment-stripper also stripped string literals — sensible, so a banned word inside a message
cannot trip a token guard. But **an import path is a string literal.** With stripping on,
`import 'package:flutter/material.dart';` became `import ;`, and both layering guards matched
nothing.

They passed their baseline. They looked correct. They enforced **nothing** — and they are the two
protecting the layer boundary INV-08's testability rests on.

> This is the whole argument for the rule that a guard must be *shown failing*: **a guard that never
> matches also passes its baseline.** Inspection would not have caught it, and the guards would have
> been silently dead for the next seven stages.

Fixed with a `stripStrings` flag: token guards keep stripping, import guards do not.

**The two guard findings pull in opposite directions**, which is why both needed demonstrating. At
3.2 a grep pre-check fired on a *comment* naming `DateTime.now()` — a false positive, which gets a
guard disabled. Here, stripping too aggressively gave false negatives — a guard that looks healthy
and does nothing.

### 8.2 Dependency findings

**`sqlite3_flutter_libs` discontinued.** Resolved as `0.6.0+eol`; from 0.6.0 it does nothing at all.
Removed as a direct dependency (Drift 2.32+ bundles SQLite automatically).

**`glados` unusable — the ADR-004 fallback fired exactly as written.** Version solving failed on
`uuid ^3.0.6` and pre-null-safety SDK bounds. ADR-004 had pre-decided hand-rolled seeded generators,
so there was no mid-implementation decision. Only automatic shrinking is lost; properties P1–P7 are
defined independently of any library.

**`riverpod_lint` + `custom_lint` dropped — a real trade, not a nuisance.** Both force `uuid ^3.0.6`,
but `uuid` 4.x provides **UUID v7**, which ARCHITECTURE §8.6 assigns to ledger rows for index
locality — PRD §7.2 shows those are 80–89% of all rows at the Heavy profile. The lint plugins enforce
none of the twelve invariants; guards G1–G6 do, independently of the analyser plugin ecosystem.
Verified afterwards that `uuid` 4.6.0 genuinely exports v7.

**`workmanager` applies the Kotlin Gradle Plugin.** The integration build warned that future Flutter
versions will fail to build on plugins that do. This strengthens the fallback ADR-004 already chose
— drop the periodic trigger, keep foreground, connectivity and manual sync. **No correctness property
depends on sync frequency**, since convergence comes from the merge design.

### 8.3 `minSdk` answered early, on purpose

**`minSdk` remains 24; no plugin raised it.** The Stage 7 and 8 plugins were added during 3.3 rather
than when first needed, precisely so this was answered while cheap. Substage 3.3's pitfall:
*"Discovering in Stage 7 that the Google client raised minSdk above the level already advertised."*

Read from the merged manifest of a build with everything present, then confirmed against the APK by
`aapt2 dump badging` — the artefact, not the intent.

### 8.4 Infrastructure gaps recorded for the next machine

Gradle could not auto-download the NDK (`sdkmanager "ndk;28.2.13676358"` fixes it), and no emulator
AVD existed. Both are in `ENVIRONMENT.md` §3 and §9 and `DEVELOPMENT.md` §9, so they are recognisable
rather than mysterious.

## 9. Deviations from the stage plan

| Deviation | Why |
|---|---|
| **Six guards, not four** | G2 engine purity (INV-08 is stronger than general layering) and G5 database containment, which substage 2.2.3 explicitly required |
| Guards are a Dart script, not a grep | A grep fires on comments — substage 3.4's named pitfall. The script strips comments before matching |
| One test added during 3.5 | A pipeline that cannot go green has not been verified, and no test file existed after the template was deleted. Five real cases on the sealed `Result` type, not a placeholder |
| Stage 7/8 plugins added at 3.3 | To answer the `minSdk` question early rather than in Stage 7 |
| Startup redirect not implemented | It needs `onboarding_state` from the database — Stage 4's layer, wired at 6.1.5. Recorded in the router's doc comment as a known gap |
| Scope switch not wired | A data condition with nothing to wire until Stage 4 provides group data. The design decision is settled in NAVIGATION §5 |

## 10. What Stage 4 will consume

| From | Drives |
|---|---|
| `lib/domain/money/` | `Money` and `BasisPoints` join `Currency` at 4.1 |
| `lib/data/database/database.dart` | **Replaced wholesale** at 4.3 with the thirteen tables from SCHEMA.md |
| `test/support/fakes/` | The fake clock and deterministic id generator, wired to real implementations at 4.1.5 |
| `test/support/builders/` | Extended as entities arrive at 4.2 |
| `test/fixtures/databases/` | Empty and waiting for the v1 migration fixture at 4.9.3 |
| `tool/guards/guards.dart` | G3 gets its first real workout once `Money` exists |
| `tool/check.ps1` | The command every substage runs before claiming completion |

**Obligations carried into Stage 4:**

1. The **`repair_log`** table (SCHEMA §3.13) must be built — it was added by amendment after the
   Stage 2 gate, and Stage 7 has nowhere to write repairs without it.
2. `database.dart` and `codegen_probe.dart` are **disposable probes** and must be replaced, not
   extended.
3. Coverage targets become real at 4.10: **90% for domain and data**.

---

## 11. Gate

Stage 3 (Project Scaffolding) is complete. The app builds and every designed screen is reachable as
a stub.

**Versions used:**

| | |
|---|---|
| Flutter / Dart | 3.44.7 / 3.12.2 |
| Android SDK | 36.0.0 · platform android-36.1 · build-tools 36.0.0 · NDK 28.2.13676358 |
| JDK | OpenJDK 21.0.10 (bundled with Android Studio) |
| Gradle / AGP / Kotlin | 9.1.0 / 9.0.1 / 2.3.20 |
| `minSdk` / `targetSdk` / `compileSdk` | **24** / **36** / **36** |
| Application id | `com.khizirfarrukh.pookiebudget` — **permanent after first upload** |

**Deviations from the design:** three, all documented in §3.1 and §9 — none affects the layer
boundaries, the guards, or any invariant.

**Two things worth your attention:**

- **`targetSdk` is pinned to 36** because Google Play requires it for new apps from **31 August
  2026**, six weeks out. Checked against Play policy on 2026-07-21 rather than recalled.
- **The application id is now in the build files.** Still changeable until Stage 10.5 produces the
  first signed artefact, but it spreads further with each stage.

Do you approve moving to Stage 4, the core data layer?
