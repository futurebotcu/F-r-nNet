# FirinNet Release Quality Gate

## Amac

Bu kalite kapisi her build sonrasinda uygulamanin acildigini, ana tablarin
calistigini ve temel guest navigasyonunun bozulmadigini dogrular.
`QA_TEST_MATRIX.md` ayrintili release senaryolarini listeler.

Patrol ana Flutter-native E2E smoke hattidir. Maestro, Windows native
driver/gRPC kararsizligi nedeniyle advisory olarak tutulur ve sonucu tek
basina release kapisini fail etmez.

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
patrol test -t patrol_test/app_smoke_test.dart --no-uninstall
maestro test .maestro/app_smoke.yaml
```

Flutter adimlari ve kuruluysa Patrol fail-fast calisir. Patrol CLI kurulu
degilse acik uyari verilir ve Flutter sonuclari fail edilmez. Maestro her
durumda advisory'dir.

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

## Lokal Emulator Testi

1. Android emulatoru baslatin.
2. `flutter devices` ve `patrol doctor` ile ortami dogrulayin.
3. Smoke testini calistirin:

```powershell
patrol test -t patrol_test/app_smoke_test.dart --no-uninstall
```

Android runner her test icin app data'yi temizler. Test guest girisini yapar;
Feed, Gruplar, Market, Ilanlar ve Panel tablarini dolasip Feed'e geri doner.
`--no-uninstall`, Windows Android emulatorlerinde ADB uninstall kilitlenmesini
engeller; test izolasyonu `clearPackageData=true` runner ayariyla korunur.

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
calisir. Diger P0 senaryolari `QA_TEST_MATRIX.md` durumlarina gore Flutter
testi veya manuel/kosullu kontrol gerektirebilir.

## Release Oncesi Komut

```powershell
.\scripts\run_quality_gate.ps1
```
