# FırınNet — Android Release Signing Runbook (P0-C)

**Tarih:** 2026-05-16
**Hedef:** Google Play Console için imzalı release Android App Bundle (AAB) üretmek. Debug imzasıyla release çıkma riski **fail-fast** olarak kapatıldı.

> Önceki davranış: `android/app/build.gradle.kts` `release { signingConfig = signingConfigs.getByName("debug") }` — release build debug imzasıyla çıkardı (P0-C). Şimdi: `android/key.properties` yoksa release build başlamadan **kasıtlı olarak fail** eder; debug build etkilenmez.

---

## Güvenlik kararı: debug fallback YOK

Bu PR'da release signing davranışı şudur:

- **Debug build / `flutter run` / `flutter build apk --debug`:** Etkilenmez. Mevcut debug keystore ile çalışır.
- **Release build (`flutter build appbundle --release`, `flutter build apk --release`, `assembleRelease`, `bundleRelease`):**
  - `android/key.properties` **yoksa** → build **fail eder** açık Türkçe hata mesajıyla.
  - `android/key.properties` **varsa** ama içinde `storeFile`, `storePassword`, `keyAlias` veya `keyPassword` eksikse → build **fail eder**, eksik alanlar isimle listelenir.
  - Belirtilen `storeFile` diskte yoksa → build **fail eder**, beklenen mutlak yol gösterilir.
  - Şifre değerleri hata mesajlarına ASLA yazılmaz.

Bu kasıtlı bir güvenlik davranışıdır: kazara debug imzalı bir AAB Play Store'a yüklenmesin.

---

## Hızlı durum

| Kontrol | Durum |
|---|---|
| `android/key.properties` git'te | ❌ Yok (`android/.gitignore:12` ignore) |
| `android/app/*.jks` git'te | ❌ Yok (`android/.gitignore:14` + root `*.jks` ignore) |
| `android/app/build.gradle.kts` release signing | ✅ Fail-fast: key.properties yoksa release **fail**, debug fallback **yok** |
| `android/key.properties.example` | ✅ Template var (commit edilir, içinde gerçek şifre/key yok) |
| `flutter build apk --debug` | ✅ Geçer (debug etkilenmedi) |
| `flutter build appbundle --release` (key.properties yokken) | ❌ Kasıtlı fail — "Release signing için android/key.properties gerekli." |

---

## 1. Keystore üret

> ⚠️ **Bu adımı sen yapacaksın.** Keystore üretildiği makinede tutulmalı + ayrı bir yedeğe konmalı. Anahtarı kaybedersen Play Store'a güncelleme veremezsin.

Windows PowerShell veya bash (Java JDK gerekli — `flutter doctor` zaten zorunlu kılar):

```powershell
cd C:\dev\firinnet\android\app
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Sorulan bilgiler:
- Keystore password: güçlü bir parola (kaydet — kaybedersen anahtar yok olur)
- Key password: ayrı bir parola olabilir veya aynı
- First and last name, organization, country: gerçek değerler

Çıktı: `android/app/upload-keystore.jks` (binary). Bu dosya `.gitignore` ile dışlandı; **git'e GİRMEZ**.

---

## 2. `android/key.properties` doldur

```powershell
Copy-Item C:\dev\firinnet\android\key.properties.example C:\dev\firinnet\android\key.properties
```

Düzenle (gerçek değerlerle):

```properties
storePassword=...           # keytool'da girdiğin keystore parolası
keyPassword=...             # key parolası
keyAlias=upload             # keytool -alias parametresi
storeFile=app/upload-keystore.jks
```

`android/key.properties` `android/.gitignore:12` ile dışlandı; **git'e GİRMEZ**.

> `storeFile` yolu `android/` köküne göredir. Mutlak yol da olabilir.

---

## 3. Release AAB build

```powershell
cd C:\dev\firinnet
flutter build appbundle --release `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY
```

Veya hazır script üzerinden:

```powershell
.\scripts\build_release_supabase_aab.ps1
```

Bu script:
- `.env.local`'dan `SUPABASE_URL` + `SUPABASE_ANON_KEY` okur (service_role değil).
- `flutter build appbundle --release` çağırır.
- Anahtarları konsola yazmaz.

Başarılı çıktı: `build/app/outputs/bundle/release/app-release.aab`.

### Beklenen fail durumları

| Durum | Hata mesajı (özet) |
|---|---|
| `android/key.properties` yok | "Release signing için android/key.properties gerekli." |
| `key.properties` var ama `keyAlias` boş | "android/key.properties içinde eksik alan(lar): keyAlias" |
| `storeFile=app/foo.jks` ama dosya yok | "Release keystore dosyası bulunamadı: …\android\app\foo.jks" |

Bu fail mesajları gradle çıktısında görünür; şifre değeri ASLA yazdırılmaz.

---

## 4. Doğrulama

```powershell
# AAB var mı?
Test-Path build\app\outputs\bundle\release\app-release.aab

# Hangi keystore ile imzalandı?
jarsigner -verify -verbose -certs build\app\outputs\bundle\release\app-release.aab
```

`jarsigner` çıktısında `"jar verified"` ve **debug** kelimesi YOK olmalı; CN/O alanları senin keystore bilgilerinle eşleşmeli.

---

## 5. Google Play Console upload

1. Play Console → Uygulama oluştur veya mevcut uygulamayı seç
2. **Release → Production → Create new release**
3. `app-release.aab` yükle
4. Play App Signing varsayılan açıktır → Play imza yönetir. Senin `upload-keystore.jks` "upload key" olarak görev yapar.
5. İlk yüklemede Play bu anahtarı kaydeder; sonraki yüklemeler aynı anahtarla imzalı olmak zorunda.

---

## 6. Anahtar kayıp/sızıntı protokolü

Eğer `upload-keystore.jks` veya `key.properties` yanlışlıkla:
- git'e commit'lenirse:
  1. Hemen `git filter-repo` veya `bfg` ile geçmişten kaldır
  2. Play Console → Uygulama → Setup → App integrity → Upload key reset talep et (Google destek 1-2 gün)
  3. Yeni keystore üret, yeni `key.properties` ile devam et
- Public bir kanala (chat / screenshot / commit message) düşerse:
  1. Aynı reset prosedürü
  2. Eski keystore'u local'den de sil (yeni anahtar kullanılacak)

`upload-keystore.jks` **bir** kez kaybedilirse Play Console'dan reset gerekir; lokalde yedek tut.

---

## 7. Bilinen sınırlar

- **Bu runbook keystore üretimini ben yapmadım.** Üretim ve şifre yönetimi senin tarafındadır (güvenlik gereği).
- **AAB build denemesi bu turda yapılmadı (başarılı).** `flutter build appbundle --release` key.properties olmadan kasıtlı fail veriyor — bu **beklenen** sonuçtur ve config'in doğru çalıştığını kanıtlar. Gerçek başarılı AAB build için keystore üretmen + `key.properties` doldurman lazım.
- Play App Signing v2 kullanılacaksa Play ekstra bir "app signing key" üretir; bizim ürettiğimiz keystore "upload key" rolünde kalır.

## İlgili dosyalar

- `android/app/build.gradle.kts` — fail-fast release signing config
- `android/key.properties.example` — template (commit edilir, şifre yok)
- `android/key.properties` — gerçek değerler (git'te YOK)
- `android/app/upload-keystore.jks` — keystore (git'te YOK)
- `scripts/build_release_supabase_aab.ps1` — Supabase env'li release build wrapper

## P0-C kapanış kriterleri

| Kriter | Durum |
|---|---|
| build.gradle.kts release config debug değil | ✅ Fail-fast, debug fallback yok |
| key.properties yokken release build fail eder | ✅ Açık Türkçe hata mesajı |
| key.properties eksik alan kontrolü | ✅ Hangi alan eksikse adıyla listelenir |
| Hata mesajları şifre yazdırmıyor | ✅ |
| Debug build etkilenmedi | ✅ `flutter build apk --debug` geçer |
| key.properties.example template var | ✅ |
| key.properties git ignored | ✅ |
| *.jks git ignored | ✅ |
| Runbook yazıldı | ✅ (bu dosya) |
| Gerçek keystore üretildi | ⏸️ Kullanıcı tarafı |
| Gerçek **başarılı** AAB build | ⏸️ Kullanıcı keystore üretince |

**P0-C "config + fail-fast + dokümantasyon" tarafı tamam.** Kalan: kullanıcı bir kez keystore üretip `flutter build appbundle --release` çalıştıracak; çıktı doğru imzalanırsa P0-C tamamen kapanır.
