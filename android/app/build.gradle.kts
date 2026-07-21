plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.khizirfarrukh.pookiebudget"

    // Pinned rather than inherited from flutter.compileSdkVersion.
    // Google Play requires new apps and updates to target Android 16 (API 36) from
    // 31 August 2026 (substage 3.1.4 — checked against Play policy on 2026-07-21,
    // not recalled). Targeting 36 now avoids shipping something that needs an
    // immediate bump. Re-verify at substage 10.4.5 before upload.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // PERMANENT. Immutable after the first Play Store upload (substage 3.1.1).
        applicationId = "com.khizirfarrukh.pookiebudget"

        // minSdk is deliberately left at the Flutter SDK's own floor rather than a
        // guessed number. Substage 3.3.2 re-checks it once plugins are added — the
        // Google Sign-In client is the most likely to raise it — and records which
        // plugin set the floor in docs/ENVIRONMENT.md.
        minSdk = flutter.minSdkVersion

        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Debug signing only so `flutter run --release` works during development.
            // Real release signing is configured in substage 10.5, where the upload
            // keystore is generated and kept out of the repository.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
