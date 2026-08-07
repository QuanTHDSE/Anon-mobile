import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

// The upload keystore is gitignored, so it is absent on fresh clones and new machines.
// Resolve it up front so the signing config can be skipped instead of failing the build.
val uploadKeystore = (keystoreProperties["storeFile"] as String?)
    ?.let { file(it) }
    ?.takeIf { it.exists() }

android {
    namespace = "site.anonwork.mobile"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "site.anonwork.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (uploadKeystore != null) {
            create("common") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = uploadKeystore
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        debug {
            // Fall back to the auto-generated debug keystore when the upload key is absent.
            signingConfig = signingConfigs.findByName("common") ?: signingConfigs.getByName("debug")
        }

        release {
            signingConfig = signingConfigs.findByName("common")
            if (signingConfig == null) {
                logger.warn(
                    "WARNING: upload keystore not found at " +
                        "${keystoreProperties["storeFile"]} - the release build will be UNSIGNED."
                )
            }
        }
    }
}

flutter {
    source = "../.."
}
