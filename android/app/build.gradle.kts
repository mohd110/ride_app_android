import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Reads the Flutter project's .env file (gitignored — see .env.example for
// the expected keys) so the same GOOGLE_MAPS_API_KEY used by Dart code
// (lib/config/maps_config.dart, via flutter_dotenv) can also be injected
// into AndroidManifest.xml as a manifest placeholder — the native Maps SDK
// reads its key from the manifest, not from Dart/dotenv, so it needs its
// own copy of the value at build time rather than a hardcoded one.
val envFile = File(rootDir, "../.env")
val envProperties = Properties()
if (envFile.exists()) {
    envFile.forEachLine { line ->
        val trimmed = line.trim()
        if (trimmed.isNotEmpty() && !trimmed.startsWith("#") && trimmed.contains("=")) {
            val idx = trimmed.indexOf("=")
            envProperties[trimmed.substring(0, idx).trim()] = trimmed.substring(idx + 1).trim()
        }
    }
}
val googleMapsApiKey: String = envProperties.getProperty("GOOGLE_MAPS_API_KEY", "")

android {
    namespace = "com.example.riderapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.riderapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Consumed by AndroidManifest.xml's com.google.android.geo.API_KEY
        // meta-data as ${GOOGLE_MAPS_API_KEY}. Applies to every build type
        // (debug and release both inherit from defaultConfig).
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Mitigates a reported crash on Android 12L+ when core library desugaring is enabled.
    // https://github.com/MaikuB/flutter_local_notifications#-reports-that-enabling-desugaring
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")
}

flutter {
    source = "../.."
}
