# FirinNet Release Quality Gate

## Amac

Bu kalite kapisi her build sonrasinda su temel sorulara hizli cevap verir:

- Uygulama aciliyor mu?
- Feed ve ana tablar gorunuyor mu?
- Feed, Gruplar, Market, Ilanlar ve Panel arasinda gecis calisiyor mu?
- Temel guest deneyimi ve inline composer erisimi bozulmamis mi?

Detayli senaryo envanteri `QA_TEST_MATRIX.md` dosyasindadir.

## Calistirma

Repo kokunde PowerShell ile:

```powershell
.\scripts\run_quality_gate.ps1
```

Script sirayla sunlari calistirir:

```text
flutter analyze
flutter test
flutter build apk --debug
maestro test .maestro/app_smoke.yaml
```

Ilk uc adim fail-fast calisir. Maestro kurulu degilse smoke testi acik bir
uyariyla atlanir; basarili Flutter adimlari fail sayilmaz.

## Maestro Kurulumu

Guncel kurulum talimati:

https://docs.maestro.dev/getting-started/installing-maestro

Kurulumdan sonra yeni bir terminal acip dogrulayin:

```powershell
maestro --version
```

Android package ID kaynak config'den alinmistir:
`com.firinnet.firin_defter`.

## Lokal Emulator Smoke Testi

1. Android emulatoru baslatin ve `adb devices` ile gorundugunu dogrulayin.
2. Debug APK'yi build edip kurun:

```powershell
flutter build apk --debug
adb install -r .\build\app\outputs\flutter-apk\app-debug.apk
```

3. Smoke flow'u calistirin:

```powershell
maestro test .maestro/app_smoke.yaml
```

Flow deterministik guest smoke icin uygulama state'ini temizler, auth entry
ekraninda `Kayıtsız devam et` aksiyonunu kullanir ve Feed'e ilerler. Bu nedenle
test cihazinda saklanan oturum smoke calismasi sirasinda korunmaz.

## P0 Release Kriteri

P0 senaryolari release blocker'dir. Ozellikle su alanlar gecmelidir:

- App boot ve splash sonrasi Feed
- Bes ana bottom navigation etiketi
- Tum ana tab gecisleri ve Feed'e donus
- Feed inline composer gorunurlugu
- Bos Market ve Is Ilanlari durumlari
- Guest yazma guard'i
- Profil/avatar aksiyonunun crash etmemesi
- Temel navigasyonda crash olmamasi

Release adayi icin `QA_TEST_MATRIX.md` icindeki tum P0 satirlari gecmelidir.

## Release Oncesi Komut

```powershell
.\scripts\run_quality_gate.ps1
```

Maestro kurulu bir release makinesinde emulator ve guncel APK hazir olmadan
kalite kapisi tamamlanmis sayilmaz.
