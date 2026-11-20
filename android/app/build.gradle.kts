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
    val envFile = rootProject.file("../.env")
    if (envFile.exists()) {
        load(FileInputStream(envFile))
    }
}

val signingProperties = Properties().apply {
    val signingFile = rootProject.file("key.properties")
    if (signingFile.exists()) {
        signingFile.inputStream().use { load(it) }
    }
}
fun signingValue(name: String, environment: String): String? =
    System.getenv(environment)?.takeIf { it.isNotBlank() }
        ?: signingProperties.getProperty(name)?.takeIf { it.isNotBlank() }

val releaseStoreFile = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
val releaseSigningConfigured = listOf(
    releaseStoreFile, releaseStorePassword, releaseKeyAlias, releaseKeyPassword
).all { it != null }

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

        // Only allowlisted .env keys reach the APK; .env also holds server secrets.
        val emulatorHost = envProperties.getProperty("EMULATOR_HOST")?.takeIf { it.isNotBlank() } ?: "10.0.2.2"
        manifestPlaceholders["EMULATOR_HOST"] = emulatorHost
        resValue("string", "EMULATOR_HOST", emulatorHost)

        // Facebook Login (flutter_facebook_auth) reads these from string resources.
        fun envValue(name: String): String =
            System.getenv(name)?.takeIf { it.isNotBlank() }
                ?: envProperties.getProperty(name)?.takeIf { it.isNotBlank() }
                ?: ""
        val facebookAppId = envValue("FACEBOOK_APP_ID")
        if (facebookAppId.isEmpty()) {
            logger.warn("FACEBOOK_APP_ID is not set; Facebook sign-in will fail at runtime.")
        }
        resValue("string", "facebook_app_id", facebookAppId)
        resValue("string", "fb_login_protocol_scheme", "fb$facebookAppId")
        resValue("string", "facebook_client_token", envValue("FACEBOOK_CLIENT_TOKEN"))

        if (!manifestPlaceholders.containsKey("appAuthRedirectScheme")) {
            manifestPlaceholders["appAuthRedirectScheme"] = "foodsavr"
        }
    }

    flavorDimensions += "environment"

    productFlavors {
        create("development") {
            applicationIdSuffix = ".development"
            dimension = "environment"
            versionNameSuffix = "-development"
        }
        create("production") {
            dimension = "environment"
        }
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")

            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

tasks.configureEach {
    if (name == "preProductionReleaseBuild") {
        doFirst {
            check(releaseSigningConfigured) {
                "Production releases require signing credentials in android/key.properties " +
                    "or ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, " +
                    "ANDROID_KEY_ALIAS and ANDROID_KEY_PASSWORD."
            }
        }
    }
}

flutter {
    source = "../.."
}
