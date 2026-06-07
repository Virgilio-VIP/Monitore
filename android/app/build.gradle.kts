import java.util.Properties
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "br.com.monitore.app"
    compileSdk = flutter.compileSdkVersion
// ajuste    ndkVersion = flutter.ndkVersion
// ./graldew clean avisou para mudar
//    ndkVersion = "26.1.10909125"
//    ndkVersion = "27.0.12077973"
// voltei para o erro da 28, mas não é isso pelo gemini
    ndkVersion = "27.0.12077973" // Required by webview_flutter_android and other plugins

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "br.com.monitore.app"

        // Use the Flutter-managed version values (from pubspec.yaml).
        // Shorebird (and Play/App Bundles) use the final AAB manifest version.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Optional: override minSdk/targetSdk if you need a minimum different
        // from what Flutter expects, but keep versionCode/versionName in sync.
        // minSdk = 24
        // targetSdk = 34

        ndk {
            // Garanta que x86 e x86_64 estão aqui para o Genymotion funcionar
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64"))
        }

        // Disable split APK generation when building an AAB (Android App Bundle).
        // Multiple APK outputs can break bundle builds.
        splits {
            abi {
                isEnable = false
            }
        }
    }

    signingConfigs {
        create("release") {
            val keystoreProperties = Properties()
            val keystorePropertiesFile = rootProject.file("app/key.properties")
            if (keystorePropertiesFile.exists()) {
                keystoreProperties.load(keystorePropertiesFile.inputStream())
            }
            storeFile = keystorePropertiesFile.parentFile?.let { 
                File(it, keystoreProperties.getProperty("storeFile") ?: "upload-keystore.jks")
            }
            storePassword = keystoreProperties.getProperty("storePassword") ?: "maria2025"
            keyAlias = keystoreProperties.getProperty("keyAlias") ?: "upload"
            keyPassword = keystoreProperties.getProperty("keyPassword") ?: "maria2025"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Disable code shrinking/minification to avoid issues with missing Play Core
            // classes when targeting Android 14 (SDK 34).
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}