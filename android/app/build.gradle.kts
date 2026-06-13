import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.reader(Charsets.UTF_8).use { keystoreProperties.load(it) }
}

fun Properties.getClean(name: String): String? {
    val direct = getProperty(name)
    if (direct != null) return direct
    return entries.firstOrNull { (k, _) ->
        k.toString().trim().removePrefix("\uFEFF") == name
    }?.value?.toString()
}

android {
    // Personal sideload ID — avoids Play Protect flags on com.example.* test packages
    namespace = "com.mediavault.personal"
    // Android 16 (API 36)
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getClean("keyAlias")
                keyPassword = keystoreProperties.getClean("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getClean("storeFile")!!)
                storePassword = keystoreProperties.getClean("storePassword")
            }
        }
    }

    defaultConfig {
        // Unique Application ID (package name). Keep stable to preserve data/backup.
        applicationId = "com.mediavault.personal"
        // minSdk 24: Android 7.0+; tested for Android 14–16 (API 34–36)
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Fallback until key.properties + keystore are created (see PACKAGING_NOTES.md)
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Single universal APK (all ABIs in one file). No per-ABI split APKs.
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

flutter {
    source = "../.."
}
