plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.meridian.meridian_tycoon_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Diperlukan oleh flutter_local_notifications (core library desugaring).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.meridian.meridian_tycoon_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Tandatangan debug supaya APK tetap boleh dipasang tanpa keystore
            // rahsia (Peraturan rilis). CI menggantikan dengan keystore sebenar
            // jika secret KEYSTORE_* wujud (lihat .github/workflows/release.yml).
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

// Versi automatik rilis: versionName daripada tag (RELEASE_TAG), versionCode
// daripada run number (RELEASE_RUN_NUMBER) — release.yml menyer
// --build-name / --build-number kepada `flutter build apk` apabila env wujud.
