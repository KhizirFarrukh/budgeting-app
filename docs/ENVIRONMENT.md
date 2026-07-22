# Build environment

Recorded in substage 3.1.8 and finalised at 3.9.5. **Every version here was read from the tooling on
this machine, not recalled** — per the manifest's knowledge-freshness rule.

| | |
|---|---|
| **Recorded** | 2026-07-21 |
| **Machine** | Windows 11 Pro 64-bit, 25H2 (build 10.0.26200.8875) |

---

## 1. The application id — permanent

```
com.khizirfarrukh.pookiebudget
```

**This can never change after the first Play Store upload.** Substage 3.1.1 treats it as immutable
for that reason. It remains editable until substage 10.5 produces the first signed artefact, but
becomes progressively more tedious as it spreads through build files, package paths and the OAuth
client configuration registered in Stage 7.

Derived from `--org com.khizirfarrukh` plus `--project-name pookiebudget`. The Dart package name is
`pookiebudget`; the repository directory is `budgeting-app`.

## 2. Flutter and Dart

| Component | Version |
|---|---|
| Flutter | **3.44.7**, channel `stable` |
| Install location | `C:\Users\Chichum\flutter` |
| Framework revision | `84fc5cbb22` (2026-07-17) |
| Engine revision | `69c8c61792` |
| Dart | **3.12.2** |
| DevTools | 2.57.0 |

## 3. Android SDK

| Component | Version |
|---|---|
| SDK location | `C:\Users\Chichum\AppData\Local\Android\Sdk` |
| SDK tools | **36.0.0** |
| Platform | **android-36.1** |
| Build tools | **36.0.0** |
| NDK | **28.2.13676358** |
| Emulator | 36.6.11.0 |
| Licenses | All accepted |

**The NDK was installed explicitly** via `sdkmanager`, because Gradle's own auto-download failed
during the first build (`Failed to download package! Install NDK (Side by side) 28.2.13676358`).
Recorded so the same failure is recognisable rather than mysterious on another machine:

```
sdkmanager "ndk;28.2.13676358"
```

## 4. SDK levels

| Level | Value | Reasoning |
|---|---|---|
| `compileSdk` | **36** | Pinned, not inherited from `flutter.compileSdkVersion` |
| `targetSdk` | **36** | **Google Play requires new apps and updates to target Android 16 (API 36) from 31 August 2026** — checked against Play policy on 2026-07-21, not recalled. Six weeks out at the time of writing, so targeting 35 would mean shipping something needing an immediate bump. Re-verify at substage 10.4.5 before upload |
| `minSdk` | *Flutter SDK floor — see below* | Deliberately **not** a guessed number (substage 3.1.3) |

### The `minSdk` floor

`minSdk` is set to `flutter.minSdkVersion`, the Flutter SDK's own current floor, rather than a
hardcoded value. Substage 3.3.2 re-checks it once plugins are added and **raises it only if a plugin
demands it**, recording which plugin set the floor.

| | |
|---|---|
| **Resolved value** | **24** (Android 7.0) |
| Plugin that set the floor | **None.** Re-checked at substage 3.3.2 with *all* plugins present — including `google_sign_in`, the likeliest to raise it — and the floor was unchanged. This is Flutter 3.44.7's own floor |
| How it was determined | Read from the **built artefact**, not assumed: the merged manifest shows `android:minSdkVersion="24"`, and `aapt2 dump badging app-debug.apk` confirms `minSdkVersion:'24'`. Re-read after the plugin build |

Substage 3.3's `common_pitfalls` names the failure this pre-empts: *"Discovering in Stage 7 that the
Google client raised minSdk above the level already advertised."* Adding the Stage 7 and Stage 8
plugins during 3.3 rather than when they are first used is what makes the answer available now.

The Google Sign-In client (Stage 7) is the most likely to raise it. Substage 3.3's
`common_pitfalls` names exactly this: *"Discovering in Stage 7 that the Google client raised minSdk
above the level already advertised."*

## 5. JVM toolchain

| Component | Version |
|---|---|
| JDK | **OpenJDK 21.0.10** (build 21.0.10+-14961533-b1163.108) |
| JDK location | `C:\Program Files\Android\Android Studio\jbr` — bundled with Android Studio |
| Java source/target compatibility | 17 |
| Kotlin `jvmTarget` | 17 |

The JDK is the one bundled with Android Studio rather than a separately installed one. To pin a
different JDK: `flutter config --jdk-dir="path/to/jdk"`.

## 6. Gradle toolchain

| Component | Version |
|---|---|
| Gradle | **9.1.0** |
| Android Gradle Plugin | **9.0.1** |
| Kotlin Gradle Plugin | **2.3.20** |

## 7. Android manifest configuration

Set deliberately in substage 3.1.6; none of these is a platform default.

| Setting | Value | Why |
|---|---|---|
| `android:label` | `PookieBudget` | Launcher name. Verified for truncation at 10.1.6 |
| `android:usesCleartextTraffic` | `false` | No unencrypted traffic, at any stage |
| `android:allowBackup` | `false` | **See below** |
| `android:fullBackupContent` | `false` | Legacy backup path, also disabled |
| `android:dataExtractionRules` | `@xml/data_extraction_rules` | Every domain excluded |
| Permissions declared | **none** | `INTERNET` is added in Stage 7. NFR-02 requires every core flow to complete with no network and no account, so nothing before then needs one |

### Why backup is disabled

Android's default is `allowBackup="true"`, which would copy the app's database — **every financial
record the user has** — to Google's backup service. PRD §6.10 states that financial data reaches only
the device and the user's own Drive, and substage 9.7.3 verifies that on the release build.

Substage 3.1.6 requires this decision to be made consciously rather than inherited. The safe position
until 9.7.3 revisits it is to exclude everything. The user's own backup paths are the explicit JSON
export (NFR-07) and cloud sync (FR-09), neither of which uses this mechanism.

## 8. Build and run commands

```powershell
# Dependencies
flutter pub get

# Static analysis and formatting
flutter analyze
dart format --output=none --set-exit-if-changed .

# Tests
flutter test

# Debug build
flutter build apk --debug

# Run on the emulator
flutter emulators --launch pookie_test
flutter run
```

**Flutter is not on the PATH of every shell on this machine.** Where it is absent, invoke it by full
path:

```powershell
& "$env:USERPROFILE\flutter\bin\flutter.bat" <args>
```

## 9. Emulator

| | |
|---|---|
| AVD name | `pookie_test` |
| System image | `system-images;android-36;google_apis;x86_64` — Android 16.0 ("Baklava") |
| Device profile | Default. The `pixel_7` profile lookup failed with *"Could not load devices from … devices.xml"* and fell back to the default, which is adequate for Stage 3 |

`google_apis` rather than `google_apis_playstore`: it includes Google Play services, which Stage 7's
sign-in needs, without the Play Store app.

**An emulator is sufficient for Stage 3** (substages 3.1.7 and 3.9.3). Substage 9.6 requires a
**physical mid-tier device**, because NFR-06 forbids measuring performance on a flagship — or an
emulator on a desktop CPU — and reporting it as representative.

## 10. Verification

Build output and the route walk are captured in `docs/reports/STAGE_3_REPORT.md`.

| Check | Substage | Status |
|---|---|---|
| `flutter build apk --debug` succeeds | 3.1.7 | ✅ 153.5s, `app-debug.apk` 139.4 MB |
| Built artefact carries the intended identifiers | 3.1.7 | ✅ verified by `aapt2 dump badging` — see below |
| App launches to its own screen, not generated boilerplate | 3.1.7 | ✅ installed and launched on `emulator-5554`; screenshot confirms the placeholder screen |
| Every version recorded here | 3.1.8 | ✅ including the resolved `minSdk` |
| `flutter analyze` clean on the scaffold | 3.2 | ✅ "No issues found!" |
| Versions finalised after dependencies are added | 3.9.5 | ✅ All 21 direct dependencies resolved and recorded in `DEPENDENCIES.md`; `minSdk` re-confirmed as 24 with every plugin present |
| Full check passes from a clean checkout | 3.9.2 | ✅ `ALL CHECKS PASSED (6 steps)`, exit 0 |
| Dark mode and 200% font scale on device | 3.9.3 | ✅ Screenshots at default, dark, and `font_scale 2.0` in dark — no clipping or truncation |

### Launch verification

```
$ adb install -r build/app/outputs/flutter-apk/app-debug.apk
Performing Streamed Install
Success

$ adb shell am start -n com.khizirfarrukh.pookiebudget/.MainActivity
Starting: Intent { cmp=com.khizirfarrukh.pookiebudget/.MainActivity }

$ adb shell pidof com.khizirfarrukh.pookiebudget
5081

$ adb shell dumpsys activity activities | grep ResumedActivity
topResumedActivity=ActivityRecord{... com.khizirfarrukh.pookiebudget/.MainActivity t8}
```

A screenshot was captured and inspected: the app bar reads **PookieBudget** and the body reads
**"Scaffold placeholder — Stage 3 substage 3.1. No features are implemented."** No trace of the
generated counter screen. The launch was **verified visually**, not inferred from a zero exit code.

### Artefact verification, read from the APK rather than the source

```
$ aapt2 dump badging build/app/outputs/flutter-apk/app-debug.apk

package: name='com.khizirfarrukh.pookiebudget' versionCode='1' versionName='1.0.0'
         compileSdkVersion='36' compileSdkVersionCodename='16'
minSdkVersion:'24'
targetSdkVersion:'36'
application-label:'PookieBudget'
```

Reading the built artefact rather than the build file is deliberate: it proves what was actually
produced, not what was intended. The same discipline applies at substage 4.3.6, which reads the live
database schema rather than trusting the definition source.

### Build output

```
Running Gradle task 'assembleDebug'...                            153.5s
√ Built build\app\outputs\flutter-apk\app-debug.apk
```

The first build attempt **failed** — Gradle could not auto-download the NDK. Resolved by installing
it explicitly with `sdkmanager` (§3). The second build additionally pulled Android SDK Platform 36
revision 2 and CMake 3.22.1 automatically, accepting their licences, and then succeeded.
