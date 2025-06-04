plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.fairshare.fairshare_app"
    compileSdk = 35                     // 🚀 Latest for 3-year stability
    ndkVersion = "27.0.12077973"        // 🚀 Latest stable NDK
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17    // 🔧 Updated to Java 17 LTS
        targetCompatibility = JavaVersion.VERSION_17    // 🔧 Updated to Java 17 LTS
    }
    
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()   // 🔧 Updated to Java 17 LTS
    }
    
    defaultConfig {
        applicationId = "com.fairshare.fairshare_app"
        minSdk = 28                     // 🎯 Future-proof (Android 9.0, covers 95% users)
        targetSdk = 35                  // 🚀 Latest for Play Store requirements
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

flutter {
    source = "../.."
}