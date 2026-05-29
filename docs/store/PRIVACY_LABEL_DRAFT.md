# FırınNet — App Privacy Label (Draft)

> App Store Connect → App Privacy bölümü için taslak cevaplar. Kod/veri modeli
> denetiminden (2026-05-29) çıkarıldı. Üçüncü-taraf reklam/analytics SDK'sı YOK.
> Tracking YOK. IDFA/Advertising ID kullanılmıyor.

## Özet Cevaplar
- **Does this app collect data?** Yes
- **Used for tracking (ATT)?** No (tracking yok → ATT prompt gerekmez)
- **Third-party advertising?** No
- **Analytics SDK?** No (şu an analytics paketi yok)

## Veri Tipleri
| Data type | Collected | Linked to user | Tracking | Notes |
|---|---|---|---|---|
| Email Address | ✅ | ✅ | ❌ | Hesap kimlik doğrulama (Supabase Auth) |
| Name (display name) | ✅ | ✅ | ❌ | Profil görünen ad |
| Phone Number | ✅ (opsiyonel) | ✅ | ❌ | Yalnız market/iş ilanı iletişim alanına girilirse |
| User ID | ✅ | ✅ | ❌ | Supabase user id + iç `firinnet_id` (public değil) |
| User Content — Posts/Comments/Stories | ✅ | ✅ | ❌ | Sosyal akış UGC |
| User Content — Market/Job/Dealer/Recipe kayıtları | ✅ | ✅ | ❌ | İşletme/ilan içerikleri |
| Photos or Videos | ✅ | ✅ | ❌ | Kullanıcı yüklemesi (image_picker + storage) |
| Coarse/Approximate Location | ✅ | ✅ | ❌ | Şehir/ilçe seçimi (controlled code). **Precise location YOK** |
| Diagnostics / Crash / Performance | ❌ | — | ❌ | SDK yok |
| Usage Data | ❌ | — | ❌ | analytics yok |
| Advertising Data / IDFA | ❌ | — | ❌ | reklam yok |
| Contacts / Health / Financial | ❌ | — | ❌ | toplanmıyor (bayi "bakiye" kullanıcının kendi defteri, finansal-kurum verisi değil) |

## Data Use Purposes (Apple kategorileri)
- **App Functionality:** email, name, user id, UGC, photos, phone (ilanda), location (şehir).
- **Product Personalization:** takip/feed segmentasyonu (linked, tracking değil).
- Diğer purpose'lar (Analytics, Advertising, Developer Marketing) → **işaretlenmez**.

## SDK / Üçüncü Taraf
| Bileşen | Veri tarafı | Not |
|---|---|---|
| Supabase (`supabase_flutter`) | Backend (kendi altyapımız) | Auth + DB + Storage; veri kullanıcıya bağlı |
| image_picker / video_player / cached_network_image | Cihaz/medya | reklam/analitik değil |
| url_launcher / share_plus / pdf | Eylem | veri toplamaz |
| Google Sign-In | **iOS'ta gizli** (bkz. social login kararı); Android'de Supabase OAuth web akışı | native SDK yok, reversed client id yok |

## Riskli Belirsizlikler (submission öncesi netleştir)
- UGC + foto + opsiyonel telefon → "Data Linked to You" işaretlenmeli (yapıldı).
- İleride analytics/crash SDK eklenirse bu label güncellenmeli.
- Bayi defteri "bakiye/tutar" verisi: kişisel finansal-hesap verisi DEĞİL; kullanıcının
  kendi tuttuğu işletme kaydı. Apple "Financial Info"ya GİRMEZ — ama review notunda
  belirtmek faydalı.
