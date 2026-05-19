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
