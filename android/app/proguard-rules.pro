# FırınNet — R8/ProGuard keep kuralları (release minify/shrink için).
#
# NOT: Flutter'da Dart kodu AOT ile libapp.so'ya derlenir; R8 yalnız host
# Kotlin/Java katmanını küçültür. Aşağıdaki keep'ler, reflection kullanan
# plugin/SDK katmanlarının agresif shrink ile bozulmasını önler.
#
# Bu dosya minify AÇIK olduğunda devreye girer; kapalıyken etkisizdir.
# Release minify ilk kez açıldığında cihazda smoke yapılmalı (store öncesi).

# ───────────────────────────── Flutter çekirdek
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ───────────────────────────── Kotlin / coroutines
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ───────────────────────────── Supabase / gotrue / realtime (OkHttp + Ktor)
# supabase_flutter Dart tarafında çalışır; yine de host ağ kütüphaneleri
# için defansif keep + uyarı bastırma.
-keep class com.supabase.** { *; }
-dontwarn com.supabase.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**

# ───────────────────────────── JSON / reflection (Gson/serialization varsa)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ───────────────────────────── Uygulama modelleri (defansif)
# JSON map'leme tamamen Dart tarafında olduğu için zorunlu değil; ileride
# host tarafı reflection eklenirse diye model paketini koru.
-keep class com.firinnet.firin_defter.** { *; }

# ───────────────────────────── image_picker / video / file plugin'leri
-dontwarn androidx.lifecycle.**
-keep class androidx.lifecycle.** { *; }

# ───────────────────────────── Firebase / Google Play Services (FCM push)
# FN-AUDIT-013: Release minify/shrink açıkken Firebase Messaging / GMS reflection
# sınıfları kırpılırsa uygulama-dışı push CIHAZDA SESSİZCE çalışmaz. firebase_core
# + firebase_messaging host katmanını koru.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep interface com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
