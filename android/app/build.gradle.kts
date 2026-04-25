import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val envProperties = Properties().apply {
    val envFile = rootProject.file("../../.env")
    if (envFile.exists()) {
        load(FileInputStream(envFile))
    }
}

android {
    namespace = "com.foodsavr.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.foodsavr.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Expose all .env variables to the manifest and code
        envProperties.forEach { key, value ->
            val k = key.toString()
            val v = value.toString()
            manifestPlaceholders[k] = v
            resValue("string", k, v)
        }

        // Ensure EMULATOR_HOST has a default for the build to succeed if .env is missing
        if (!envProperties.containsKey("EMULATOR_HOST")) {
            manifestPlaceholders["EMULATOR_HOST"] = "10.0.2.2"
            resValue("string", "EMULATOR_HOST", "10.0.2.2")
        }
    }

    flavorDimensions += "environment"

    productFlavors {
        create("development") {
            applicationIdSuffix = ".development"
            dimension = "environment"
            versionNameSuffix = "-development"
        }
        create("staging") {
            applicationIdSuffix = ".staging"
            dimension = "environment"
            versionNameSuffix = "-staging"
        }
        create("production") {
            dimension = "environment"
            applicationIdSuffix = ".production"
            versionNameSuffix = "-production"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
