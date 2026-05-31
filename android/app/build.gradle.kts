plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// minSdk pinned to 24 explicitly. The Flags baseline / CLAUDE.md noted minSdk 21
// (just_audio supports 21+), but two locked constraints raise the real floor:
//   - Flutter 3.44 enforces a hard minimum supported Android SDK of 23
//     (DebugMinSdkCheck), and
//   - google_mobile_ads 8.0.0 declares minSdkVersion 24 in its manifest,
// so the manifest merge requires >= 24. 24 is therefore the lowest achievable
// value for this locked dependency set. Held in a val so the `flutter build`
// gradle migration does not rewrite it to the (currently identical)
// `flutter.minSdkVersion`, keeping the value explicit and self-documenting.
val appMinSdk = 24

android {
    // COMP-04: App ID must be exactly com.otis.brooke.state.the.state
    namespace = "com.otis.brooke.state.the.state"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // COMP-04: Exact App ID — com.otis.brooke.state.the.state
        applicationId = "com.otis.brooke.state.the.state"
        // minSdk: see appMinSdk above (24 — google_mobile_ads 8.0 + Flutter 3.44 floor)
        minSdk = appMinSdk
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
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
