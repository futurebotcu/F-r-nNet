# Third-party notices

FırınNet'in sosyal modülü (Feed / Post / Comments / Profile / Follow / Composer /
Stories) ekran akışı ve widget yapısı, aşağıdaki açık kaynak projeden
**substantially modified derivative work** olarak port edilmiştir:

## flutter-instagram-offline-first-clone

- **Yazar**: Emil Zulufov (ezIT)
- **Lisans**: MIT (modifier clause ile — bkz.
  `third_party/instagram_offline_first_clone/LICENSE`)
- **Kaynak**: <https://github.com/itsezlife/flutter-instagram-offline-first-clone>

### Donor'dan alınan: UI / widget tree / ekran akışı

- Feed sayfası (NestedScrollView + RefreshIndicator + InView pagination yapısı)
- Post card düzeni (author header + media + action row + likes/caption)
- Comments sayfası (full Scaffold + composer-as-bottomNavigationBar pattern)
- Kullanıcı profili (NestedScrollView + header + stats + posts grid)
- Followers/Following listeleri (UserTile + tap-to-profile)
- Composer / post oluşturma (media preview + caption + publish butonu)
- Stories carousel (yatay liste + My Story slot)

### Donor'dan **alınmayan** (FırınNet için yeniden yazıldı)

- State management: **BLoC** → **Riverpod**
- Veri katmanı: **PowerSync** + **Firebase** → **Supabase RPC + Postgres**
- Auth: donor auth flow yok; FırınNet'in mevcut auth + guest guard kullanılır
- RLS: donor'un gevşek `WITH CHECK (true)` policy'leri yok; FırınNet'in sıkı
  `auth.uid()` ownership standardı + SECURITY DEFINER RPC kullanılır
- Modeller: donor `InstaBlock / PostBlock` yerine FırınNet'in mevcut
  `FeedPost`, `SocialComment`, `SocialProfile` modelleri kullanılır

### Derivative status

Port edilen kod **donor source'un birebir kopyası DEĞİLDİR**. Widget tree
benzer ama:

1. State management baştan Riverpod ile yazıldı.
2. Veri katmanı baştan Supabase ile yazıldı (FırınNet'in mevcut repository
   triad pattern'i: Local / Supabase / Guarded).
3. Model isimleri ve alan yapısı FırınNet'e özel.
4. UI text Türkçe + FırınNet kelime dağarcığı (Fırıncı / Usta / Bayi).
5. Tema ve renkler FırınNet'in `AppColors` / `AppTokens` set'i.

Bu liste, donor LICENSE'taki "substantially modified and do not constitute a
mere replication" şartını karşılamak içindir.

Alt-paket lisansları (`packages/gallery_media_picker/`,
`packages/image_picker_plus/`, `packages/stories_editor/`) **alınmamıştır**;
sadece üst-seviye `lib/feed/`, `lib/comments/`, `lib/user_profile/`,
`lib/stories/` widget yapısı referans alındı.

## bagisto/opensource-ecommerce-mobile-app

- **Yazar**: Bagisto / Webkul Software
- **Lisans**: MIT — bkz. `third_party/bagisto_opensource_ecommerce_mobile_app/LICENSE`
- **Kaynak**: <https://github.com/bagisto/opensource-ecommerce-mobile-app>

FırınNet **Market V1** classified marketplace ekranları (listing card,
filter sheet, product detail, image gallery, action panel) Bagisto'nun
mobile e-commerce uygulamasından **pattern referansı** ile uyarlanmıştır.

### Donor'dan alınan UI/UX patternleri

- Category chip row + active filter chips
- Filter bottom sheet (city / price / category / condition)
- Product detail page layout (AppBar + image carousel + info section +
  description + attributes + sticky action bar)
- Product image carousel (PageView + dot indicator)
- Fullscreen image viewer (InteractiveViewer + tap-to-zoom)
- Loading/empty/error state ritmi

### Donor'dan **alınmayan** (kapsam dışı; classified marketplace V1)

- Cart / checkout / order / payment / shipping
- Bagisto Laravel API entegrasyonu (FırınNet Supabase kullanır)
- Customer account commerce logic
- Discount coupons, wishlist, reviews, bundle/booking/grouped products
- Push notification (FCM) — FırınNet kendi notifications ayrı
- BLoC state class'ları (Riverpod transpoze)
- ML kit image search (kapsam dışı)
- Bagisto storefront config / API key kurulumu

### Derivative status

Port edilen kod **donor source'un birebir kopyası DEĞİLDİR**:

1. State management Bagisto BLoC → FırınNet Riverpod.
2. Veri katmanı Bagisto Laravel API → Supabase tabloları + sıkı RLS.
3. Model isimleri FırınNet schema'sına (`market_listings`,
   `market_listing_media`, `market_listing_saves`) bağlı.
4. UI text Türkçe + classified vocabulary (Ekipman satışı / Fırın devri).
5. Tema FırınNet `AppColors` + `AppTokens` set'i.
6. E-ticaret payment/order yerine **classified contact panel** (telefon
   / WhatsApp / app içi mesaj — gelecek sprint).

Bu liste, Bagisto MIT lisansı altında derivative work attribution
şartını karşılamak içindir.
