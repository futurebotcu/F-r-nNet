pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.10.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    // Push notifications — FCM (firebase_messaging) icin google-services.
    id("com.google.gms.google-services") version "4.4.2" apply false
    // Crashlytics — release sembol/mapping upload (yalniz google-services.json
    // varsa app/build.gradle.kts'de conditional apply edilir; CI'da atlanir).
    id("com.google.firebase.crashlytics") version "3.0.2" apply false
}

include(":app")
