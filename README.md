# FırınNet

[![Flutter CI](https://github.com/futurebotcu/F-r-nNet/actions/workflows/flutter.yml/badge.svg)](https://github.com/futurebotcu/F-r-nNet/actions/workflows/flutter.yml)

**Fırıncılar, toptancılar ve sektör çalışanları için sosyal ağ + iş/pazar + defter uygulaması.**

---

## FırınNet nedir?

FırınNet, Türkiye fırın sektörünü tek bir mobil uygulamada toplayan dikey
bir sosyal ağ ve operasyon aracıdır. Ana deneyim sosyal feed üzerinden
akar: fırıncılar üretim, reçete ve sektör gündemini paylaşır; ustalar iş
arar, fırınlar usta arar; toptancılar müşterileri ile aynı platformda
buluşur.

Sosyal akışa ek olarak FırınNet, fırınlara günlük operasyonel araçlar
sunar: bayi defteri, üretim/fire takibi, gün sonu raporu, reçete
kütüphanesi ve hesaplama makinesi. Tüm modüller Supabase (Auth + Postgres
+ Storage + Edge Functions) ile gerçek backend'e bağlıdır; uygulama
local/mock fallback ile de çalışabilir.

## Ana özellikler

- Sosyal feed (Genel Akış / Takip Edilenler segmentleri)
- Post oluşturma (metin, resim, video)
- Yorum, beğeni, kaydetme, paylaşım
- Hikayeler (24 saatlik)
- Takip / takipçi / profil
- Sosyal gruplar (public + private, davet/onay)
- Market ilanları (ürün/ekipman pazaryeri)
- İş ilanları (Usta Arıyor / İş Arıyorum)
- Mesajlaşma (generic + ilan başvuru sohbeti)
- Bayi Defteri (5 sekmeli mini-app: Genel Bakış / Bayiler / Hareketler / Raporlar / Gün Sonu)
- PDF hesap özeti + plain text share
- Fırın paneli (üretim girişi, fire takibi, gün sonu, rapor)
- Reçete kütüphanesi + hesaplama makinesi
- Bildirimler
- Hesap silme (KVKK / Google Play uyumlu Edge Function)

## Roller

| Rol | Açıklama |
|---|---|
| **Ticari / fırın işletmesi** | Fırın paneli + Bayi Defteri + Reçete + sosyal akış |
| **Bireysel / usta** | Worker profili + iş arama + sosyal akış |
| **Toptancı** | Toptancı müşteri yönetimi (dealers altyapısı paylaşımı) + sosyal akış |

## Teknik stack

- **Flutter** 3.9+ / Dart
- **Riverpod** (state management)
- **GoRouter** (routing)
- **Supabase** (Auth, Postgres, Storage, Edge Functions)
- `share_plus`, `pdf`, `image_picker`, `cached_network_image`
- `video_player`, `chewie`, `visibility_detector`
- `flutter_chat_ui`, `url_launcher`, `shared_preferences`, `package_info_plus`

## Kurulum

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

## Supabase yapılandırması

Uygulama, Supabase URL ve anon key değerlerini build-time `--dart-define`
ile alır. **Anahtarlar repo'ya yazılmaz.** Anahtar verilmediğinde
uygulama crash etmez; local/mock fallback ile çalışır (sosyal akış mock,
bayi defteri local, vb.).

Örnek çalıştırma:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

## Güvenlik notu

- `service_role` anahtarı **asla** Flutter app'e (`--dart-define`) verilmez;
  yalnızca Supabase Edge Function ortamında bulunur (örn. `delete-account`).
- `.env.local` ve `.env.admin.local` `.gitignore` ile dışlanmıştır;
  commit edilmez.
- Android signing dosyaları (`*.jks`, `*.keystore`, `key.properties`) ve
  Firebase config (`google-services.json`, `GoogleService-Info.plist`)
  commit edilmez.

## Test ve kalite

```bash
flutter analyze        # No issues found
flutter test           # 1188+ test (sosyal/dealer/auth/groups/market/jobs/recipe)
flutter build apk --debug
```

CI badge yukarıdaki rozet üzerinden GitHub Actions'a bağlıdır.

## Android release notu

- `android/key.properties` commit edilmez (`android/.gitignore`).
- `android/key.properties.example` üzerinden release signing setup yapılır.
- Release signing ayrı manuel adımdır — detaylar repo kökündeki
  `ANDROID_SIGNING_RUNBOOK.md` dosyasında.

## Üçüncü parti lisanslar

FırınNet, açık kaynak projelerden adapte edilen kod parçaları içerir.
Tüm donor referansları, commit hash'leri ve adapte edilen dosya listesi
[`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md) ve
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) dosyalarında takip edilir.

## Durum

Aktif geliştirme. V1 release hazırlığı sürüyor — CI, Android signing,
store metadata ve release hijyeni adımları devam ediyor.
