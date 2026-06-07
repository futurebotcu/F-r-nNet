# FirinNet Release Quality Gate

## Amac

Bu kalite kapisi her build sonrasinda uygulamanin acildigini, ana tablarin
calistigini ve temel guest navigasyonunun bozulmadigini dogrular.
`QA_TEST_MATRIX.md` ayrintili release senaryolarini listeler.

Flutter native golden testleri ana ekranlarin renk, spacing, header, kart,
empty state ve bottom navigation gorunumlerini sabit baseline PNG'lerle
karsilastirir. Yeni golden dependency eklenmemistir.

Performance baseline, mevcut build/test/startup/runtime durumunu sadece
olcume dayali raporlar. Bu asamada optimization hedefi degildir ve release
blocker sayilmaz; ayrintilar `PERFORMANCE_BASELINE.md` dosyasindadir.

Patrol ana Flutter-native E2E smoke hattidir. Patrol runner ortami stabil hale
gelene kadar scriptte advisory olarak raporlanir. Maestro, Windows native
driver/gRPC kararsizligi nedeniyle advisory olarak tutulur.

## Calistirma

Repo kokunde:

```powershell
.\scripts\run_quality_gate.ps1
```

Script su sirayla calisir:

```text
flutter analyze
flutter test
flutter build apk --debug
flutter test test/golden
patrol test -t patrol_test/app_smoke_test.dart --no-uninstall
patrol test -t patrol_test/guest_guard_empty_profile_smoke_test.dart --no-uninstall
patrol test -t patrol_test/cta_guard_settings_legal_smoke_test.dart --no-uninstall
maestro test .maestro/app_smoke.yaml
```

Flutter analyze, tum testler, debug build ve golden visual regression adimlari
fail-fast calisir. Patrol ve Maestro sonuclari ayri raporlanan advisory
adimlardir; bu asamada ikisi de tek basina release kapisini fail etmez. Patrol
CLI kurulu degilse acik uyari verilir.

## Performance Baseline

Bu sprintin performans katmani measure-only'dir.

- Ne ölçülür: build/test sureleri, debug APK boyutu, cold start, ana tab
  geçişleri, feed scroll gözlemi, medya/repository riskleri.
- Nasıl çalıştırılır: `PERFORMANCE_BASELINE.md` içindeki ölçümlere bakılır;
  kalite scripti performansı fail-fast yapmaz.
- Rapor dosyası: [PERFORMANCE_BASELINE.md](C:/dev/firinnet/PERFORMANCE_BASELINE.md)
- Release blocker mı: hayır, bu sprintte advisory baseline'dir.
- Bir sonraki aşama: profile/release ortamında yeniden ölçüm ve ardından
  optimize edilecek tekil darboğazlar.

## Golden Visual Regression

Golden kapsam:

- Feed
- Gruplar
- Market empty state
- Is Ilanlari empty state
- Panel

Test ve baseline dosyalari:

```text
test/golden/main_screens_golden_test.dart
test/golden/goldens/*.png
```

Normal dogrulama:

```powershell
flutter test test/golden
```

Baseline yalniz inceleme sonucu onaylanan kasitli UI degisikliginde
guncellenmelidir:

```powershell
flutter test test/golden/main_screens_golden_test.dart --update-goldens
```

Viewport `390x844`, device pixel ratio `1`, text scale `1`, locale `tr_TR` ve
light brightness olarak sabitlenir. Guest flag mock SharedPreferences ile
sabitlenir; local repository'ler kullanilir, network veya Supabase write
yapilmaz. Bundled Roboto ve Material Icons fontlari testte yuklenir. Flutter
test ortamindaki bazi explicit Material CTA/chip stilleri deterministik Ahem
blok gliflerine dusebilir; bu gliflerin boyutu ve yerlesimi yine baseline
karsilastirmasina dahildir.

Golden sonucu dogrulanmis Windows/Flutter ortaminda baseline'dan farkliysa ve
degisiklik kasitli/onayli degilse release blocker sayilir. Farkli OS veya
Flutter engine surumunde raster/font farki gorulurse baseline otomatik
guncellenmez; once ayni pinned ortamda yeniden uretilir ve diff incelenir.

## Patrol Kurulumu

Projede `patrol` dev dependency ve Android native runner ayari bulunur.
Lokal CLI kurulumu:

```powershell
dart pub global activate patrol_cli
patrol doctor
```

Pub cache `bin` klasoru PATH uzerinde degilse terminal profilinize ekleyin.
Android package ID `com.firinnet.firin_defter`, iOS bundle ID
`com.firinnet.firinDefter` olarak mevcut platform config dosyalarindan
alinmistir.

## Dogrulanan Patrol Ortami

7 Haziran 2026 lokal dogrulama sonucu:

- Patrol package: `4.6.1`
- Patrol CLI: `4.4.0`
- Flutter: `3.35.4`
- Dart: `3.9.2`
- Windows 11 25H2
- Android SDK: `36.1.0-rc1`
- Basarili AVD: Pixel 7 hardware profile, Android 16 / API 36, x86_64
- Dummy boot: 1/1 pass
- App navigation smoke: 1/1 pass
- Stability verification: 3/3 ardisik app navigation smoke pass
- Guest/empty/profile smoke: 1/1 pass, 21/21 adim
- CTA/settings/legal smoke: 1/1 pass, 33/33 adim
- Status: verified release gate candidate

Patrol kapsam katmanlari:

- Patrol 01: app boot ve Feed > Gruplar > Market > Ilanlar > Panel > Feed
  ana navigasyon smoke.
- Patrol 02: inline composer, guest write guard, Market empty state + CTA,
  Is Ilanlari iki segment empty state ve guest profile/avatar fallback smoke.
- Patrol 03: group join, Market create ve Is Ilanlari create CTA guest guard;
  guest profile fallback; Kullanim Sartlari ve Gizlilik Politikasi navigasyonu;
  Feed'e guvenli donus smoke.

API 37 / Android 17 pre-release 16 KB page-size image'da Android Test
Orchestrator instrumentation'i test selectorlerine ulasmadan erken kapandi.
Bu app davranisi veya selector hatasi degildir. Release smoke icin API 35
onerilir; API 36 bu makinede clean pass ile dogrulanmistir. API 37 preview
image kullanilmaz.

## Lokal Emulator Testi

1. Pixel 6/7 sinifi API 35 veya API 36 x86_64 emulatoru cold boot ile baslatin.
2. `flutter devices` ve `patrol doctor` ile ortami dogrulayin.
3. Runner sagligini dummy test ile dogrulayin:

```powershell
patrol test -t patrol_test/dummy_boot_test.dart --no-uninstall
```

4. Ana smoke testini calistirin:

```powershell
patrol test -t patrol_test/app_smoke_test.dart --no-uninstall
```

5. Guest/empty/profile smoke testini calistirin:

```powershell
patrol test -t patrol_test/guest_guard_empty_profile_smoke_test.dart --no-uninstall
```

6. CTA/settings/legal smoke testini calistirin:

```powershell
patrol test -t patrol_test/cta_guard_settings_legal_smoke_test.dart --no-uninstall
```

Android runner her test icin app data'yi temizler. Test guest girisini yapar;
Feed, Gruplar, Market, Ilanlar ve Panel tablarini dolasip Feed'e geri doner.
Patrol 02 gercek login veya write yapmaz; guest guard'i, local bos veri
durumlarini ve guest avatar fallback'ini dogrular.
Patrol 03 gercek join, ilan olusturma veya login yapmaz; uc CTA'nin guest
guard'ini ve guest profil fallback'indeki iki legal sayfanin acilip geri
donulebildigini dogrular.
`--no-uninstall`, Windows Android emulatorlerinde ADB uninstall kilitlenmesini
engeller; test izolasyonu `clearPackageData=true` runner ayariyla korunur.

Snapshot/cache kaynakli sorunlarda AVD'yi cold boot edin. Package manager
yanit vermiyorsa emulator data'sini wipe edip yeniden baslatin.

iOS config pubspec'te tanimlidir. iOS testi macOS, Xcode ve iOS 13+ simulator
gerektirir; bu sprintin calisma hedefi Android emulatorudur.

## Maestro Advisory

Maestro kurulumu ve manuel calistirma:

```powershell
maestro test .maestro/app_smoke.yaml
```

Kurulum: https://docs.maestro.dev/getting-started/installing-maestro

Windows native driver/gRPC sorunu nedeniyle Maestro sonucu ek sinyal olarak
raporlanir; Patrol ana E2E sonucudur.

## P0 Release Kriteri

P0 release blocker kapsaminda app boot, splash sonrasi Feed, bes ana bottom
navigation etiketi, tum ana tab gecisleri, Feed'e donus ve temel navigasyonda
crash olmamasi yer alir. Ana navigasyon smoke senaryosu Patrol ile otomatik
calisir ve API 36'da clean pass almistir.

Patrol, Pixel 7 / API 36 ortaminda 3/3 ardisik clean pass ile verified release
gate candidate durumundadir. Scriptte stabilization boyunca advisory kalir;
ayni emulator matrisi CI'da sabitlenince release-blocking yapilabilir. Diger P0
senaryolari `QA_TEST_MATRIX.md` durumlarina gore Flutter testi veya
manuel/kosullu kontrol gerektirebilir.

## Release Oncesi Komut

```powershell
.\scripts\run_quality_gate.ps1
```
