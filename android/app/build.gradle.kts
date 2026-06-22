import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Push notifications — FCM google-services plugin'i YALNIZ config dosyasi
// varsa uygula. google-services.json `.gitignore`'lu (secret; repoya girmez):
// - CI / dosyasiz ortam: plugin atlanir → build derlenir (Firebase runtime'da
//   guard'li init ile sessizce devre disi).
// - Cihaz / release build (dosya mevcut): plugin uygulanir → FCM aktif.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
    // Crashlytics gradle plugin'i de yalniz config varsa uygulanir (google-services'e
    // bagimli). CI/dosyasiz ortamda atlanir → build derlenir; runtime'da Firebase
    // guard'li init ile crash reporting sessizce devre disi. firebase_crashlytics
    // Flutter plugin'i runtime'da bu plugin olmadan da calisir (plugin yalniz
    // release sembol upload icin).
    apply(plugin = "com.google.firebase.crashlytics")
}

// V1 P0-C — Release signing config (fail-fast, no debug fallback).
//
// Release build'leri her zaman `signingConfigs["release"]` kullanır. Bu
// config'in değerleri `android/key.properties`'ten yüklenir. Dosya yoksa
// veya eksik alanları varsa release task'ları açık hata mesajıyla
// **fail** eder — kazara debug imzalı bir AAB/APK Play'e yüklenmesin diye.
//
// Debug build/run etkilenmez: `flutter run`, `flutter build apk --debug`
// gibi komutlar release signing config'e dokunmaz.
//
// `android/key.properties` ve `*.jks` `.gitignore` ile dışlandı; ASLA
// repo'ya commit edilmez. Üretim için `ANDROID_SIGNING_RUNBOOK.md`.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.firinnet.firin_defter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.firinnet.firin_defter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }

    signingConfigs {
        create("release") {
            // key.properties varsa alanları doldur. Yoksa: release config
            // boş kalır → release task çalıştırılırsa aşağıdaki taskGraph
            // hook'u zaten fail eder. Debug build bu config'e bakmaz.
            val storeFilePath = keystoreProperties["storeFile"] as String?
            if (storeFilePath != null && storeFilePath.isNotBlank()) {
                val candidate = file(storeFilePath)
                storeFile = if (candidate.isAbsolute) candidate
                            else rootProject.file(storeFilePath)
            }
            storePassword = keystoreProperties["storePassword"] as String?
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
        }
    }

    buildTypes {
        release {
            // Her zaman release config. Debug'a fallback YOK — bu kasıtlı.
            // key.properties eksikse release task taskGraph hook'unda fail
            // eder; bu sayede yanlışlıkla debug imzalı release çıkmaz.
            signingConfig = signingConfigs.getByName("release")

            // Release minify/shrink: host Kotlin/Java katmanını küçültür
            // (Dart AOT libapp.so'su R8'den etkilenmez). proguard-rules.pro
            // reflection kullanan plugin/SDK katmanlarını korur.
            // NOT: İmza anahtarı bu ortamda yok → release build burada
            // doğrulanamadı; ilk release build signing makinesinde cihaz
            // smoke'u ile teyit edilmeli (bkz. release raporu).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}

// Fail-fast: release task'ı planlandıysa ve key.properties yoksa /
// eksikse, build başlamadan **açık** Türkçe hata mesajıyla durdur.
// Şifreler hata mesajına YAZILMAZ.
gradle.taskGraph.whenReady {
    val releaseTaskInGraph = allTasks.any { task ->
        val n = task.name.lowercase()
        n.contains("assemblerelease") ||
            n.contains("bundlerelease") ||
            n.contains("packagerelease")
    }
    if (!releaseTaskInGraph) {
        return@whenReady
    }
    if (!keystorePropertiesFile.exists()) {
        throw GradleException(
            "Release signing için android/key.properties gerekli. " +
                "android/key.properties.example dosyasını kopyalayıp keystore bilgilerini doldurun. " +
                "Adımlar için: ANDROID_SIGNING_RUNBOOK.md"
        )
    }
    val requiredKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    val missingKeys = requiredKeys.filter { k ->
        val v = keystoreProperties[k] as String?
        v.isNullOrBlank()
    }
    if (missingKeys.isNotEmpty()) {
        throw GradleException(
            "android/key.properties içinde eksik alan(lar): " +
                missingKeys.joinToString(", ") +
                ". ANDROID_SIGNING_RUNBOOK.md adımlarını izleyip dosyayı tamamlayın. " +
                "(Şifre değerleri bu hata mesajına yazılmadı.)"
        )
    }
    val storeFilePath = keystoreProperties["storeFile"] as String
    val storeFileResolved = file(storeFilePath).let { c ->
        if (c.isAbsolute) c else rootProject.file(storeFilePath)
    }
    if (!storeFileResolved.exists()) {
        throw GradleException(
            "Release keystore dosyası bulunamadı: " +
                storeFileResolved.absolutePath +
                ". ANDROID_SIGNING_RUNBOOK.md → 'Keystore üret' adımını çalıştırın."
        )
    }
}
