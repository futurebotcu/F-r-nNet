# FırınNet V1 Expansion — Pre-Audit Report

**Tarih:** 2026-05-16
**Branch:** `main` @ `9a42c87` (origin/main ile **0 ahead, 0 behind**)
**Tip:** Araştırma — kod değişmedi, migration uygulanmadı, commit yok.

---

## 0. Executive Summary

Mevcut sistem ana sosyal/iş omurgası gerçek bir backend'e bağlanmış durumda (feed, comments, groups, jobs, job messaging, marketplace). Ancak feed yüzeyinde **iki "fake placeholder"** kullanıcıyı yanıltıyor:

1. **Anlık ("Atölyeden anlık") şerit** — 9 hardcoded sahte kullanıcı, tıklanmıyor, DB yok, storage yok.
2. **FeedPostCard görsel slot'u** — her post için 5:4 oranlı gradient + "Görsel yüklenmedi" overlay'i; "burada görsel olmalıydı" hissi yaratıyor ama DB'de hiç media kolonu yok.

Bunlar **yeni medya/story ekleme öncesi temizlenmesi gereken yalanlardır** — aksi halde her V1.X eklemesi "var sandığım şey gerçekten yokmuş" şüphesi üzerine inşa edilir.

**Önerilen 3-sprint sıralaması:**
- **Sprint A (P0, sadece UI, DB yok):** Sahte placeholder'ları temizle + dil ölü kodu temizle + ürün ekleme için minimum UI "Diğer" akışı.
- **Sprint B (P1, DB + Storage):** Feed image attachment (gerçek media kolonu + bucket + upload + render). bakery_products için CRUD UI.
- **Sprint C (P2, daha büyük sistemler):** Video, kamera-anlık çekim, story (24h TTL), takip sistemi. Her biri kendi alt-sprint'ine bölünebilir; **takip V1'e zorunlu değil**.

---

## 1. Current App State

### Git
- main = origin/main (0/0).
- Unstaged: `lib/features/auth/utils/auth_error_translator.dart` (önceki turun fix'i, henüz commit yok — user kuralı gereği).
- Untracked: 17 markdown audit raporu (`*_AUDIT*`, `*_REPORT*`, `*_RUNBOOK*`). Working tree güvenli; staged değişiklik yok.

### Open V1 backlog (kod arama sonucu)
- `TODO|FIXME|XXX` sayımı: doğrulanamadı (bu raporun kapsamında ayrı bir tarama yapılmadı; aşağıdaki Sprint planı bu raporda toplanan reality matrislere dayanır).
- Mevcut bilinen kalanlar (commit/audit izlerinden): manuel UI A-K smoke; legal modal final geçiş; gerçek release keystore + AAB; V2 polish.

### Bottom navigation (4 tab)
| Sıra | Tab | Route |
|---|---|---|
| 1 | Feed | `/feed` |
| 2 | Gruplar | `/groups` |
| 3 | İlanlar | `/jobs` |
| 4 | Panel (rol bazlı dashboard) | `/panel` |

- **Profil**: bottom nav'da DEĞİL. Feed header avatar tıklamasıyla `/profile`'a full-screen push olarak ulaşılır (`app_shell.dart:18-22`).
- **Market**: tab kaldırıldı (`/market` deeplink uyumu için route hala açık). `app_shell.dart:13-17`.

---

## 2. Feature Placement Audit (mevcut giriş noktaları)

| Alan | Mevcut giriş | Kullanıcı beklentisi | Doğal mı? | Risk |
|---|---|---|---|---|
| Feed | Tab 1 | Var | Evet | Anlık strip + görsel placeholder yalan |
| Gruplar | Tab 2 | Var | Evet | — |
| İş İlanları | Tab 3 | Var | Evet | — |
| Panel | Tab 4 → role dashboard | Var | Evet | — |
| Profil | Feed header avatar | Bottom nav'da arar | Yarı doğal | Yeni kullanıcı kafa karışıklığı (önceki audit'lere göre kabul edilmiş tradeoff) |
| Mesajlar | `/messages` (route var) — UI'da giriş noktası belirsiz | İlandan/profilden | doğrulanamadı (giriş noktalarının ekrandan ekrana gerçek mevcudiyeti UI smoke'da kontrol edilmeli) | İlanlar → konuşma akışı doğal olmalı |
| Reçete / Bayi / Worker | Panel kartları | Var | Evet | — |
| Anlık | Feed header altı şerit | Var (sadece görsel) | **Hayır — fake** | Yeni kullanıcıya "burada bir şey var" yalanı söyleniyor |
| Public profile (başka kullanıcı) | YOK | Yok (henüz beklenmiyor) | Yok | Takip eklenirse şart |
| Yeni ürün ekle | YOK | "Fiyat ekle" formunda olur | **Hayır — eksik** | UI sadece 6 sabit ürün veriyor |
| Medya paylaşımı | YOK ama PostCard görselmiş gibi davranıyor | "Fotoğraf ekle" composer'da olur | **Hayır — eksik + yanıltıcı** | Placeholder yalanı |

---

## 3. Feed Media Audit

### feed_posts schema (gerçek)
`supabase/migrations/20260516041148_social_spine_v1.sql`:
- Kolonlar: `id, owner_id, type, text, tags, group_id, group_name, author_name, author_role, like_count, comment_count, is_deleted, created_at, updated_at`.
- `type` CHECK: `production | question | supply | equipment | job | group_highlight` — **media tipi yok**.
- RLS: select authenticated (is_deleted=false); insert/update/delete owner_id=auth.uid().
- **Hiç media kolonu yok** (jsonb, url, array — yok).

### Composer
`lib/features/feed/widgets/feed_composer.dart`:
- Sadece type chip + text alanı.
- `repo.addPost(type, author, role, text)` — **media parametresi yok**.

### FeedPostCard
`lib/core/widgets/premium/feed_post_card.dart:139-175`:
- Her postun başında **5:4 AspectRatio + LinearGradient (8 renk paletinden post-id seedlı) + "Görsel yüklenmedi" overlay'i**.
- Gerçek görsel URL'i yok; render denemesi yok; placeholder kalıcı.
- **Bu kullanıcıya yalan söylüyor**: "post media destekliyor ama bu kullanıcı yüklememiş" hissi yaratıyor. Aslında sistem hiç desteklemiyor.

### Bağımlılıklar / izinler
| Kaynak | Var mı? |
|---|---|
| `image_picker` | YOK |
| `video_player` | YOK |
| `camera` | YOK |
| `file_picker` | YOK |
| `permission_handler` | YOK |
| AndroidManifest `CAMERA` | YOK |
| AndroidManifest `READ_MEDIA_IMAGES/VIDEO` | YOK |
| Supabase Storage bucket | YOK (kodda hiç `supabase.storage` çağrısı yok) |
| iOS Info.plist NSCamera / NSPhoto | doğrulanamadı (bu turda incelenmedi) |

### Tablo
| Konu | Mevcut | Eksik | En doğal yerleşim | Bozulma riski |
|---|---|---|---|---|
| Text-only post | Çalışıyor | Placeholder yalanı | FeedPostCard'tan gradient slot'u kaldırılmalı | UI snapshot diff (kart yüksekliği değişir) |
| Image attachment | Yok | DB kolonu + Storage + picker + render | `feed_post_media` ayrı tablo + `feed-media` bucket | Layout taşması, upload fail UX, RLS sınır kaçağı |
| Video attachment | Yok | + video_player + thumbnail + boyut limiti | Image akışına ek; **V1.X için "image first, video later"** | Mobil veri tüketimi, thumbnail eksikse boş kart |
| Camera capture | Yok | camera + permissions + capture screen | Composer içinde "+ kamera" sheet | Permission denied recovery, retake akışı |

### Karar sorularına yanıt
- **Text-only doğallaştırmak için sadece UI mı?** Evet — FeedPostCard'tan gradient slot kaldırılır; DB değişmez. Sprint A.
- **Media için tek jsonb mi, ayrı tablo mı?** **Ayrı `feed_post_media(post_id, url, kind, width, height, ordering, created_at)`** — galeri, silme, sıralama, eklerin per-row RLS'i için temiz. Tek jsonb daha hızlı atılır ama silme/sıralama/sayım için sürekli json patch gerek; uzun vadede acı verir.
- **V1'de tam video player mı?** Hayır — V1.X'te image-only; video bir sprint ileri. Geçici çözüm: video upload yok; tıklanırsa "yakında" yerine **hiç butonu gösterme** (sessiz yokluk > sahte buton).
- **Upload başarısız olursa post ne olur?** İki tercih: (a) post atılmaz, kullanıcıya hata; (b) post text-only kaydedilir, media boş. **Önerilen (a)** — kullanıcı "fotoğraflı atayım" diyorsa fotoğrafsız savaş ganimeti istemez.

---

## 4. Story / Anlık Audit

### Mevcut durum
`lib/features/feed/screens/feed_screen.dart:29-39`:
```dart
static const _stories = <_Story>[
  _Story('Sen', Icons.add_rounded, true),
  _Story('Hasan U.', null, false),
  _Story('Konya Un', null, false),
  _Story('Selin', null, false),
  _Story('Pide Evi', null, false),
  _Story('Mayacı O.', null, false),
  _Story('Ahmet U.', null, false),
  _Story('Taş Fırın', null, false),
  _Story('Ege Susam', null, false),
];
```
- `_StoryAvatar` widget: `InkWell`/`GestureDetector`/`onTap` **yok**. Tıklama hiçbir şey yapmaz.
- AppStrings.feedSectionStories = "Atölyeden anlık".
- DB: stories/story_views/anlik tablosu yok.
- Storage: bucket yok.

**Verdict:** Anlık **tamamen sahte**. Sadece görsel illüzyon. Kullanıcı bunu fark edince güveni sarsılır.

### Tablo
| Soru | Mevcut | Önerilen V1 davranışı | Risk |
|---|---|---|---|
| Anlık menüsü var mı? | UI'da var, backend yok | **Şeridi tamamen kaldır** (Sprint A) ya da gerçek backend ile bağla (Sprint C) | "Gerçekleşene kadar göster" → güven kaybı |
| Feed strip mi ayrı sayfa mı? | Şu an strip | Eğer gerçek olacaksa strip kalır; viewer modal | Layout reflow |
| 24h TTL? | Yok | Olmalı — cron veya Edge Function gece silme | Edge ops yükü |
| Storage paylaşımı? | Yok | Image akışıyla aynı bucket, farklı prefix (`stories/`) | RLS karmaşası |
| Guest paylaşabilir mi? | — | Hayır (AuthRequiredGuard) | — |
| Guest görebilir mi? | — | **Hayır** — story sosyal güven gerektirir, RLS authenticated | — |

### Karar
- Anlık'ı **gerçek hâle getirmeden önce mevcut sahte UI silinmelidir** (Sprint A).
- Gerçek story V1 için **gerekli değil** — feed + groups + jobs + market yeterli sosyal yüzey. **Sprint C** (veya V2'ye ertelenebilir).

---

## 5. Product / Price Flow Audit

### Mevcut model
- `bakery_products` tablosu var (`20260512075056_firinnet_v1_core_schema.sql:104-135`): `id, owner_id, bakery_id, name, unit, default_price, is_active, ...`. RLS owner-only.
- **Flutter'da bu tabloyu kullanan repository / UI YOK.** CRUD sadece DB'de.
- `AppProducts.defaults` (`lib/core/constants/app_products.dart`): **6 sabit isim hardcoded** — Ekmek, Simit, Pide, Poğaça, Açma, Börek.
- Tüm akışlar (dealer price sheet, delivery form, production entry) `ProductChoiceChips(AppProducts.defaults)` kullanır.
- `dealer_prices.product_name`: **TEXT, FK değil**. Hiçbir DB constraint bunu `bakery_products.name` ile eşlemiyor.

### Sorun
"Fiyat ekle/güncelle" formunda sadece 6 sabit ürün var. Kullanıcı "Çatal", "Tahinli", "Kurabiye" girmek isterse:
- UI'dan ekleyemez.
- DB'ye direkt erişim olmadığı için pratikte çıkış yok.

### Tablo
| Alan | Mevcut model | Sorun | En doğru çözüm | DB etkisi |
|---|---|---|---|---|
| Ürün listesi kaynağı | `AppProducts.defaults` (const) | Sabit 6 ürün; kullanıcı genişletemez | Önce: form içinde "Diğer → free-text" (no DB). Sonra: `bakery_products` ile dynamic list | Sprint A: yok. Sprint B: `bakery_products` CRUD repo |
| Yeni ürün ekleme | UI yok | Eksik | Price sheet modaline "+ yeni ürün" affordance | INSERT into bakery_products |
| Cross-owner spoof | `product_name` TEXT | Owner A "RakipÜrünü" yazabilir | İleride dropdown sadece kendi `bakery_products` listesi olur | RLS zaten owner-only — kaçak yok ama UX kirli |
| Marketplace vs bakery | Farklı tablolar (`market_listings` ayrı) | OK | Karıştırma — marketplace = public B2B, bakery_products = internal | Yok |
| Ürün birimi | `unit` (default 'adet') | UI'da yönetilmiyor | bakery_products CRUD form'unda | Var |

### Karar
- **Sprint A**: Price sheet ve delivery/production formlarında "Diğer" chip seçilince **inline text field** açılsın; user serbest yazsın. DB'ye gitmez, sadece o satıra string kaydedilir. **Hızlı, riski sıfır, dealer flow'u bozmaz.**
- **Sprint B**: `bakery_products` için CRUD ekranı (`/panel/products` veya Panel kartı). Price sheet'teki chip listesi `AppProducts.defaults` + kullanıcının `bakery_products` kayıtlarının union'ı olur. Yeni ürün eklendiğinde otomatik seçili gelir.
- **Cross-owner**: V1 için string TEXT yeterince güvenli (RLS owner-only). V2'de `product_id` FK'ye çevrilebilir.

---

## 6. Language Option Audit

### Mevcut
- `lib/app/app.dart:30-34`:
  ```dart
  locale: const Locale('tr', 'TR'),
  supportedLocales: const [
    Locale('tr', 'TR'),
    Locale('en', 'US'),   // ← ölü deklarasyon
  ],
  ```
- `main.dart:12`: `initializeDateFormatting('tr_TR')` — hardcoded.
- AppStrings: 760 satır, %100 Türkçe const.
- i18n framework yok (`.arb` yok, `flutter gen-l10n` yok, `easy_localization` yok).
- Settings/Ayarlar dil seçeneği: **commit 970de7f'te kaldırıldı** (`fix(firinnet): remove silent no-op UI actions`). UI'da kullanıcıya görünen dil butonu **yok**.

### Tablo
| Locale alanı | Durum | Risk | Öneri |
|---|---|---|---|
| `supportedLocales: en_US` | Ölü deklarasyon | "Sistem dilim İngilizce" diyen kullanıcıda Material widget'ları İngilizceleşmeye çalışıp app stringleri Türkçe kalır — tutarsız | Kaldır (Sprint A — kozmetik) |
| `locale: tr_TR` hardcoded | OK V1 | — | V2'ye kadar dokunma |
| AppStrings hardcoded | OK V1 | i18n gelecekse büyük refactor | Sıralama: V2 |
| Settings dil butonu | Yok | — | İyi durumdayız |

### Karar
- V1 **Türkçe-only**.
- Sprint A'da `supportedLocales`'ten `Locale('en', 'US')`'i kaldır — bu **kod değişikliği** ama kullanıcı tarafında 0 etki, sadece tutarsızlık riskini siler.
- Dil seçeneği reklam edilmiyor — kullanıcı görmüyor. Skip.

---

## 7. Follow System Audit

### Mevcut
- `follows` tablosu: **YOK**.
- `profiles` kolonları: `follower_count`/`following_count` **YOK**.
- Profile screen: sadece **self** profile. Başka kullanıcı profili rotası yok (`/u/:id` yok).
- Feed author tap: **InkWell/GestureDetector yok** — tıklanmıyor.
- `AuthRequiredGuard`: generic — guest yazma engellenir, follow-specific davranış yok (çünkü follow yok).

### Tablo
| Alan | Mevcut | Eksik | Doğal yerleşim | Risk |
|---|---|---|---|---|
| `follows` tablosu | Yok | (follower_id, following_id, created_at) PK kompozit | Yeni migration | RLS düzgünse temiz |
| Counter | Yok | trigger-maintained `follower_count` | profiles ALTER + trigger | Race condition'lar; alternatif: COUNT(*) sorgu (V1 trafiğinde ucuz) |
| Public profile route | Yok | `/u/:userId` | profile_screen genişletmesi | profiles RLS şu an owner-only SELECT → **diğer kullanıcı email'ini sızdırmamak için politika revize gerek** (örn. ayrı `profiles_public` view) |
| Feed author tap | No-op | onAuthorTap → `/u/:owner_id` | feed_post_card genişletmesi | — |
| Followers/Following listeleri | Yok | Yeni ekran | profile detayında tab | — |
| Following feed filter | Yok | feed_screen query'sinde IN(follow.following) | feed_provider değişimi | Boş follow → boş feed UX'ı |

### Kritik gözlem — RLS çakışması
`profiles` mevcut policy'leri **yalnız sahibi**: `profiles_select_own: id = auth.uid()`. Follow eklenirse, başkasının profilini görmek için ya:
- yeni `profiles_select_public` policy (`true` ama anon DEĞİL), veya
- `profiles_public` view (display_name, account_type, profession_badge, city, avatar_url — **email/created_at hariç**).

E-posta sızıntısı **bu adımda en yüksek risktir**. Atlanırsa GDPR/KVKK ihlal yüzeyi.

### Karar
- Follow **V1 için zorunlu değil** — fırıncı uygulaması topluluk ağı olarak gruplar + iş ilanları + feed üzerinden zaten çalışıyor. Follow eklemek "sosyal medya"ya kayar.
- **Sprint C'ye veya V2'ye ertele**. Eklenecekse **public profile + RLS revize** birinci hareket olmalı; takip butonu son.

---

## 8. Supabase / RLS Risk Matrix (eklenecek olası objeler)

| Yeni obje | Gerekli mi? | RLS riski | Storage riski | Mevcut akış riski | Tavsiye |
|---|---|---|---|---|---|
| `feed_post_media (post_id, url, kind, ordering, ...)` | Sprint B | Düşük — owner_id parent join | Bucket path spoof: path `<owner_id>/<post_id>/<uuid>.jpg` zorunlu | feed select query'sine LEFT JOIN | Önce migration + bucket + dummy → sonra UI |
| `feed-media` storage bucket | Sprint B | Public read mi authenticated mı? Görseller herkese açık ise `public` policy ama path `<owner_id>/` zorunluluğu UPLOAD policy'sinde | Maks dosya boyutu, içerik tipi MIME whitelist | — | `authenticated` read; `WITH CHECK (storage.foldername(name)[1] = auth.uid()::text)` upload |
| `stories` tablo | Sprint C | TTL + select policy (24h içindeki) | Aynı bucket farklı prefix | Feed header reflow | Şart değil V1 |
| `story_views` | Sprint C | INSERT public, SELECT owner_id (story author) — kim izledi | — | — | Story gelirse paralel |
| `follows` | Sprint C | INSERT/DELETE follower=auth.uid(); SELECT taraflara açık | — | profiles policy revize gerekir | V1.X opsiyonel |
| `profiles_public` view veya policy revize | Follow ile zorunlu | **email sızıntı riski** | — | Mevcut profiles_select_own ile çakışır | Follow eklenirse PR'ın birinci adımı |
| `bakery_products` CRUD UI | Sprint B | Mevcut RLS owner-only, riski yok | — | dealer/price/delivery formlarına entegrasyon | Provider + repo + ekran |

**Asla yapma:**
- `WITH CHECK (true)` — owner-id guarantee atlama.
- `USING (true)` — public read herkes-için.
- `anon` rolüne DML.
- `service_role` policy'lere konu olmaz.
- Storage path'inde `auth.uid()::text` doğrulaması olmadan upload.
- Cascade silmeyi unutmak — post silindiğinde media row'ları + bucket dosyaları temizlenmeli (DB cascade + bucket cleanup edge function).

---

## 9. UI Naturalness Matrix

| Sistem | En doğal ekran | Alternatif | Neden | Risk |
|---|---|---|---|---|
| Text-only post temizliği | FeedPostCard render path | — | Yalan placeholder en yüksek güven hasarı; tek yer | Layout snapshot diff |
| Feed image attach | FeedComposer "+ fotoğraf" düğmesi | — | Compose anı, paylaşmadan önce | Composer şişer (mevcut 3-4 satır text alanına buton şeridi eklenmesi gerekir — ölçü kontrolü) |
| Kamera-anlık | Aynı composer içinde "fotoğraf çek" alt seçeneği | Floating capture button | Az affordance, fazla menü olmaz | Permission UX |
| Story strip | Feed header altı 92px slot zaten var | Ayrı sayfa | Mevcut slot kullanılırsa UI değişmez | Sahte stripin yerini gerçek alır — geçişte UI test refresh gerek |
| Yeni ürün ekle | Price sheet modali içinde "Diğer → text" (Sprint A) → bakery_products CRUD ekranı (Sprint B) | Panel'de ayrı "Ürünlerim" kartı | Kullanıcı eksiği fark ettiği yerden çıkar | Modal-in-modal kaçınılmalı |
| Dil seçeneği | YOK olmalı (mevcut UI'da zaten yok) | — | V1 Türkçe-only | — |
| Takip et butonu | Public profile (`/u/:id`) header | Feed author kart aksiyonu | Public profile zaten gerekiyorsa orada toplanmalı | RLS revize edilmezse e-posta sızıntısı |
| Followers/Following list | Public profile tab/bottom sheet | Ayrı route | Profile içinde bağlam | — |
| Following-only feed | Feed üst tab "Hepsi / Takip" | Feed filter chip | Toggle açık olsun | Boş feed UX'ı |

### Doğallık soruları
- **Composer şişer mi?** Evet — mevcut composer dar; image+camera+video butonları eklenirse picker ikon grubu tek satır olmalı, text alanı altına. Sprint B tasarımıyla ölçülmeli.
- **Story strip feed'i boğar mı?** Şu an 92px slot var; gerçek story de aynı ölçüde kalırsa boğmaz.
- **Takip butonu fırıncı app'inde değer katar mı?** Düşük — topluluk yüzeyi grup ve ilanlar üzerinden zaten kuruldu. Sosyal medya tüketimi hedeflenmiyor.
- **Bayi ürünü ile marketplace listing karışır mı?** Şu an farklı tablo + farklı ekran — karışmıyor. Kullanıcı "ürün ekle" deyince hangisi olduğunu UI bağlamı belli ediyor.
- **Dil seçeneği kullanıcıya gereksiz mi?** Evet — V1 Türkçe-only ve gösterilmiyor.

---

## 10. P0 / P1 / P2 Priority

| Öncelik | Sistem | Neden | Bağımlılık | Sprint sırası |
|---|---|---|---|---|
| **P0** | FeedPostCard görsel placeholder kaldırma | "Yalan slot" güveni sarsıyor; kod-only, DB yok | Yok | A |
| **P0** | Anlık fake strip kaldırma | Aynı yalan — feed_screen.dart fake `_stories` listesi | Yok | A |
| **P0** | "Diğer → free-text" ürün adı | Kullanıcı eksiği fark ediyor; minimum UI | Yok | A |
| **P0** | `supportedLocales` en_US ölü kod silme | Material widget dil tutarsızlığı riski | Yok | A |
| **P1** | Feed image attachment (gerçek) | Beklenen feature, DB + Storage + UI | DB migration + Storage bucket + image_picker + permissions | B |
| **P1** | `bakery_products` CRUD UI | Ürün listesi kullanıcının kendi kataloğu olmalı | Yeni repo + provider + ekran | B |
| **P2** | Feed video attachment | Tek başına büyük scope (player, thumbnail, boyut) | Image sistemine binmeli | C |
| **P2** | Kamera anlık çekim | Composer + permission orchestration | image_picker / camera | C |
| **P2** | Story/Anlık 24h | DB tablo + storage + viewer + TTL cron | Image sistemi hazır olmalı | C |
| **P2** | Public profile route (`/u/:id`) + profiles RLS revize | Follow ön şartı; e-posta sızıntı riski | profiles policy düzeltme | C (önkoşul) |
| **P2** | Follow / takip sistemi | V1 için zorunlu değil, sosyal medyaya kayar | Public profile + RLS hazır | C (opsiyonel) |
| **P2** | Followers/Following listeleri | Follow varsa | Follow | C |
| **P2** | Following-only feed filter | Follow varsa | Follow | C |
| Sonra | Push notification / realtime | Ayrı kararnamede ele alınmalı | — | V2 |

---

## 11. Breakage Risk Matrix

| Geliştirme | Bozabileceği akış | Risk | Önlem | Test |
|---|---|---|---|---|
| Feed placeholder kaldırma | FeedPostCard layout snapshot | Düşük | Widget testlerini güncelle | Mevcut feed widget testleri |
| Anlık strip kaldırma | Feed scroll offset, header padding | Düşük | Manuel UI smoke + golden | A-K smoke |
| Ürün "Diğer → text" | Delivery/price form valid akışı | Düşük | Form validator regression | Dealer form testleri |
| supportedLocales en_US silme | OS-en kullanıcıda Material strings | Düşük | tr-only sabit; etki yok | analyze + manual |
| Feed image attach | Composer layout, upload fail UX, storage RLS, post insert tx | Orta | Upload önce → URL alındıktan sonra post insert; fail → rollback storage | Live smoke: 5MB jpg upload + thumbnail render |
| `bakery_products` CRUD | Delivery/price/production formlarında list source değişimi | Orta | AppProducts.defaults + user listesi UNION (kayıp olmasın) | Form integration test |
| Video attach | Player crash, autoplay UX, mobil veri | Yüksek | Maks 30s, MP4 only, thumb otomatik | Live device smoke |
| Camera capture | Permission denied → onboarding, retake | Orta | Permission rationale dialog + fallback gallery | Live smoke iki cihaz |
| Story TTL | 24h sonra kayıt silme cron'u, dangling storage | Yüksek | Edge Function: nightly delete + storage cleanup audit | RLS smoke + manual countdown |
| Follow + public profile | profiles RLS revize → email sızıntı | **En yüksek** | `profiles_public` view veya kolon-level kısıt; mevcut policy'ler değiştirilmeden eklenmeli | RLS smoke: foreign user'ın email'i null gelmeli |
| Following feed filter | Boş follow → boş feed UX | Düşük | "Henüz takip yok → Feed'e dön" empty state | Manuel |

---

## 12. Recommended Sprint Order

### Sprint A — "Yalan temizliği" (P0, DB-free, **en az risk, en yüksek güven kazancı**)
**Hedef:** Yeni özellik eklemeden önce kullanıcının "burada bir şey var sandım" duygusunu siler.
- FeedPostCard: gradient placeholder + "Görsel yüklenmedi" overlay'i kaldır; sadece text postunu render et.
- `feed_screen.dart`: `_stories` listesini ve `_StoryStrip` widget'ını feed'den çıkar (header sectionLabel `feedSectionStories` de gider).
- `AppProducts.defaults` chip listesinin yanına **"Diğer"** chip + seçilirse free-text alanı (dealer price sheet, delivery form, production entry, waste — neresi mantıklıysa). DB değişikliği yok; `product_name` zaten TEXT.
- `lib/app/app.dart`: `supportedLocales`'tan `Locale('en','US')` kaldır.

**DB migration:** YOK.
**Storage:** YOK.
**Test:** flutter analyze + flutter test + manuel UI smoke (özellikle feed scroll + dealer price entry).
**Live smoke:** mevcut sosyal spine smoke'larının kırılmadığı doğrulanır.
**Rollback:** Trivial — UI revert tek commit.

### Sprint B — "Gerçek medya + ürün kataloğu" (P1, DB + Storage)
**Hedef:** Sprint A temizlikten sonra **gerçek image attachment** ve **bakery_products CRUD** ekle.
- Migration: `feed_post_media (id, post_id FK cascade, owner_id FK, kind, url, width, height, ordering, created_at)` + RLS owner-only insert/delete, authenticated select (post visible olduğunda).
- Storage bucket `feed-media`: upload policy path `<auth.uid()>/<post_id>/<uuid>` zorunluluğu; MIME whitelist (image/jpeg, image/png, image/webp); maks boyut.
- pubspec: `image_picker`, `permission_handler`.
- AndroidManifest: `READ_MEDIA_IMAGES` (Android 13+) + legacy `READ_EXTERNAL_STORAGE` (sdk<33).
- iOS Info.plist: `NSPhotoLibraryUsageDescription`.
- FeedComposer: "+ Fotoğraf" butonu → picker → upload → post insert (transaction-like: önce upload, sonra post + media row; upload fail → post atılmaz).
- FeedPostCard: media row varsa Image.network (AspectRatio fit, error → küçük "yüklenemedi" + retry).
- bakery_products: Repository + Provider + `/panel/products` listeleme/ekleme/silme ekranı. Mevcut formlarda chip listesi `AppProducts.defaults + userBakeryProducts` union.

**Test:** unit (repo) + widget (composer media flow) + live smoke (5MB jpg gerçek upload, retrieve, delete cascade).
**Rollback:** Migration'ı geri almak için drop tablo; storage bucket policy'leri kaldırmak.

### Sprint C — "İleri medya + topluluk genişlemesi" (P2, parça parça)
- C-1: Video attachment (image sistemine biner; video_player; thumbnail; boyut limit).
- C-2: Kamera capture (camera package; permission flow).
- C-3: Public profile route (`/u/:userId`) + **profiles RLS revize** (kolon-level public view; email gizli). Bu adım Follow'ın ön koşulu.
- C-4: Story/anlık tablosu + storage prefix + viewer modal + 24h TTL Edge Function.
- C-5: Follow tablosu + counter + feed filter + author tap navigation.

**Karar noktası:** C-3 ile C-5 birlikte planlanmalı çünkü RLS revize edilmeden follow public profile listelemesi yapılamaz. C-4 (story) tamamen ayrı yolla gidebilir; story → follow bağımlılığı yok.

---

## 13. Things Not To Do

- **Sprint atlamak:** Sprint A bitmeden Sprint B'ye geçilirse "fake placeholder + real attachment" aynı PR'da iki ayrı render path'i oluşturur; regression riski.
- **`feed_posts.media_urls jsonb` shortcut:** Hızlı ama silme/sıralama/per-row RLS imkansız. Ayrı tabloya gidin.
- **`profiles_select` policy'sini `true` yapmak:** Email/created_at sızar. View veya kolon-kısıtlı yeni policy şart.
- **Story'yi follow'a bağımlı tasarlamak:** Story herkese açık olabilir (RLS authenticated select). Bağımlılık üretmeyin.
- **Anlık şeridini "şimdilik kalsın, gerçek olunca düzeltiriz" diye bırakmak:** Her gün bir kullanıcının daha güveni sarsılır.
- **Yeni ürün ekleme için modal-in-modal:** Price sheet zaten modal; içine yeni form modali açmak UX rahatsız edici. Inline expansion veya bottom sheet replace.
- **Camera permission'ı şart koşmak:** Kullanıcı reddederse gallery'den seçim fallback'i kalmalı.
- **`service_role` ile workaround:** Mevcut auth/trigger zinciri sağlam; admin path kullanılmamalı.

---

## 14. Exact Next Prompt Recommendation

Bu rapordan sonra Sprint A'yı **tek prompt'la** açmak doğal (en küçük scope, en az risk, en yüksek güven kazancı). Önerilen prompt:

```
Sprint A — V1 "Yalan temizliği" PR aç.

Kurallar:
- Sadece UI; DB migration yok, storage yok, dependency yok.
- Commit/push yok; sadece working tree değişikliği + analyze + test.
- Release AAB yok, service_role yok, .env değerlerini yazdırma.

Görevler:
1. FeedPostCard'tan görsel placeholder slot'unu (5:4 gradient + "Görsel yüklenmedi" overlay'i) kaldır; sadece text postunu render et. Kart yüksekliği yeniden hesaplansın.
2. feed_screen.dart'tan `_stories` listesini, `_StoryStrip` widget'ını ve "Atölyeden anlık" sectionLabel'ını kaldır. AppStrings.feedSectionStories ölü kaldıysa onu da temizle.
3. Tüm `ProductChoiceChips(AppProducts.defaults)` kullanım noktalarında "Diğer" chip seçilirse açılan free-text alanı ekle (dealer price sheet, dealer delivery form, production entry, waste entry — gerçek mevcudiyeti her dosyada doğrula). `product_name` string olarak satıra kaydedilir.
4. lib/app/app.dart'tan `supportedLocales`'taki `Locale('en','US')` kaydını kaldır.

Yapma:
- Yeni dependency ekleme.
- Yeni migration yazma.
- bakery_products tablosuna UI bağlama (Sprint B).

Test:
- flutter analyze --no-pub temiz olmalı.
- flutter test --no-pub geçmeli; feed ile ilgili widget test'leri eklenen/değişen ise güncelle.
- Manuel UI smoke: feed scroll temiz, anlık şeridi yok, dealer price entry "Diğer → free-text" akışı çalışıyor.

Son cevapta:
- Hangi dosyalar değişti?
- analyze/test sonucu ne?
- Hangi snapshot/golden testler güncellenmesi gerekti?
- Sprint B'ye geçmeden önce manuel smoke'da bakman gereken ekran listesi.
```

---

## Son cevap çıktıları

- Kod değiştirildi mi? **Hayır** (sadece bu rapor + önceki turun translator fix'i unstaged).
- Migration uygulandı mı? **Hayır.**
- Commit/push? **Hayır.**
- Storage policy değişti mi? **Hayır.**
- service_role kullanıldı mı? **Hayır.**
- Fatih hesabına dokunuldu mu? **Hayır.**
- `.env.local` değerleri yazıldı mı? **Hayır.**

Bu rapor C:\dev\firinnet\V1_EXPANSION_PRE_AUDIT_REPORT.md altında.
