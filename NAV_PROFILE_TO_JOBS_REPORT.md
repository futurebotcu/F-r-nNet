# FırınNet — Navigation Rebalance: Profile → Jobs

**Tarih:** 2026-05-09
**Aktif proje:** `C:\dev\firinnet`
**Uygulama:** FırınNet
**Önceki sprint:** `NAV_SOCIAL_PRIORITY_FIX_REPORT.md`

---

## 0. Sprint Hedefi

Önceki sprint'te (Nav-Social-Priority-Fix) Jobs ana tab'dan çıkarılıp Gruplar eklendi. Bu sprint **bottom nav'ı bir kez daha rebalance ediyor**: Profil yerine **İlanlar (Jobs)** ana tab oluyor.

**Karar yönü:** FırınNet **sektör ağı** olarak konumlanıyor — usta/iş ilanları sektörel olarak Profil'den çok daha **birinci sınıf** vatandaş.

---

## 1. Karar Gerekçeleri

### Neden Profil ana tab'dan çıkarıldı?

| Argüman | Detay |
| --- | --- |
| **Içerik yoğunluğu düşük** | Profil ekranı: kullanıcı bilgileri, basit istatistik mockları (12 paylaşım / 186 bağlantı / 4 yıl), 5 ListTile (İşletme Bilgileri / Ürünlerim / Raporlarım / E-posta / Ayarlar), Profilden Çık. **Yardımcı ekran yoğunluğu** — ana tab gerektirecek aktif kullanım yok. |
| **Niyet sıklığı** | Kullanıcı profilini günde 1-2 kez ziyaret eder; Feed/Gruplar/Market/İlanlar her oturumda ziyaret edilir. Tab slot'u yüksek-niyet için ayrılmalı. |
| **Yeni kullanıcı yolu** | Yeni kullanıcı uygulamaya gelir → Feed → Gruplar → Market → İlanlar zincirinde gezer. Profili sona bırakır veya hiç görmez. Tab pozisyonu boşa gidiyor. |
| **Kayıt güvenliği** | `ProfileScreen` ve `/profile` route **silinmedi** — Feed header avatar üzerinden push ile açılır. Mevcut tüm "Profilden Çık" akışı korunur. |

### Neden Jobs ana tab oldu?

| Argüman | Detay |
| --- | --- |
| **Sektör vaadinin tamamlayıcısı** | FırınNet "fırıncının dijital ağı". Ağ = sosyal akış (Feed) + topluluk (Gruplar) + alım-satım (Market) + **çalışan/usta ilanları (Jobs)**. Bunlar dört sosyal+ekonomi ayağı, hepsi ana tab olmalı. |
| **Kullanıcı ekonomisi** | Bir fırın sahibi ustaya, bir usta işe ihtiyaç duyar — ilanlar **gelir/işgücü hareketi** mantıklı bir tab niyeti. |
| **Mevcut yatırımı kullan** | `JobsScreen.dart` zaten **PASS 3'te zenginleştirildi** (4+3 ilan, gerçek maaş/şehir/vardiya/badge — taş fırın ustası gece vardiyası, pide ustası Antep). FırınNetHeader pattern'ine zaten uyumlu. Tab'a alınınca ek geliştirme gerekmedi. |
| **Önceki sprint'in geri alınması değil** | Nav-Social-Priority-Fix'te Jobs çıkarılmıştı çünkü "Gruplar"a yer açılması gerekiyordu (5 tab limit). Profil çıkınca Jobs için yer açıldı — **Gruplar korunarak Jobs geri eklendi**. |

### Yeni nav öncelik mantığı

```
1. Feed       → ana sosyal akış (default açılış)
2. Gruplar    → topluluk
3. Market     → B2B alım-satım
4. İlanlar    → çalışan/usta arz-talep            ← YENİ ana tab
5. Panel      → üretim + bayi defteri (destek)
```

İlk dördü tamamen sosyal/network → bu vurguyu netleştirir. Panel destek modülü olarak 5. sıraya alındı. **Profil avatarla erişilen yardımcı ekran** olarak konumlandı.

---

## 2. Profile Erişim Akışı

`ProfileScreen` artık Feed header'dan açılıyor:

**Feed → header sağ üstte avatar (40 px dairesel, softGold→copperMuted gradient + copper glow shadow)** → tap → `context.push(AppRoutes.profile)` → ProfileScreen full-screen overlay.

**Avatar içeriği:**
- Profil yoksa: `M` (Misafir baş harfi)
- Profil varsa: `displayName[0].toUpperCase()`

`_ProfileAvatarAction` ConsumerWidget — `profileControllerProvider` watch eder, profil değişince avatar harf güncellenir.

**Header düzeni (sağdan sola):**
1. Avatar (profil push)
2. Search (placeholder, no-op)
3. Gruplar shortcut (`groups_2_outlined`, `context.go('/groups')`)

Solda FırınNet logo + tagline. Önceki notifications butonu yerini **avatar**a bıraktı (Notifications şimdilik çıkarıldı — sektör için MVP yeterli, V2'de geri eklenebilir).

**Geri yön:** Profile push olduğu için back tuşu önceki Feed tab'ına döner — bottom nav state korunur.

> Talimat'ta "Panel içindeki ayarlar/profil alanı" alternatifi de önerilmişti ama "en stabil çözüm: Feed header avatar → ProfileScreen push" tercih edildi.

---

## 3. Bottom Nav Değişiklikleri

`lib/features/dashboard/screens/app_shell.dart`:

| Tab | Önce (V Nav-Social-Priority-Fix) | Sonra (V Nav-Profile-To-Jobs) |
| :-: | --- | --- |
| 1 | Feed (`dynamic_feed`) | **Feed** (`dynamic_feed`) — değişmedi |
| 2 | Gruplar (`groups_2`) | **Gruplar** (`groups_2`) — değişmedi |
| 3 | Market (`storefront`) | **Market** (`storefront`) — değişmedi |
| 4 | Panel (`dashboard`) | **İlanlar** (`work`) — yeni |
| 5 | Profil (`person`) — **çıktı** | **Panel** (`dashboard_customize`) — ikon güncellendi, sıra düştü |

İkonlar:
- İlanlar: `Icons.work_outline_rounded` (default) / `Icons.work_rounded` (aktif)
- Panel: `Icons.dashboard_outlined / dashboard_rounded` → **`dashboard_customize_outlined / dashboard_customize_rounded`** (ürün-özelleştirilebilir paneli daha iyi yansıtan ikon)
- Diğer 3 tab değişmedi

---

## 4. Route Değişiklikleri

`lib/app/router/app_router.dart`:

### Shell içine taşınan
- **`/jobs` → `JobsScreen`** ShellRoute child olarak eklendi (no-transition page builder). Daha önce shell DIŞI üst-seviye `GoRoute` idi.

### Shell içinden çıkarılan
- **`/profile` → `ProfileScreen`** ShellRoute'tan çıkarıldı, üst-seviye `GoRoute` olarak korundu (Feed avatar push akışı için).

### Korunan
- `/groups` (shell içi tab)
- `/groups/create`, `/groups/:id` (shell DIŞI full-screen push)
- Tüm panel sub-route'ları
- Tüm dealer route'ları
- `/profile/create` → `CreateProfileScreen` (onboarding'den profil oluşturma)

`AppRoutes` sabitleri değişmedi — tüm path'ler aynı. Sadece hangi route'un nerede tanımlandığı değişti.

---

## 5. Test / Build Sonuçları

| Kontrol | Sonuç |
| --- | --- |
| `flutter analyze` | **No issues found! (0.8 s)** |
| `flutter test` | **All tests passed! (42/42)** — değişmedi |
| `flutter build apk --debug` | **Built `app-debug.apk`** (~22 s gradle) |
| `adb install -r` | Success |
| Smoke test | **5/5 screenshot otomatik** alındı |

### Test dağılımı (değişmedi)
- Recipe: 4
- Dealer balance: 7 · repository: 4 · share: 2 · PDF: 2
- Social group: 11
- Feed repository: 11
- widget_test placeholder: 1

Navigation refactor'u yine repository tabanlı testlerden bağımsız → 0 test bozulması.

---

## 6. Screenshot Listesi

Klasör: `C:\dev\firinnet\qa-screenshots\nav-profile-to-jobs\`

| Dosya | Boyut | İçerik |
| --- | --- | --- |
| `01_feed_with_profile_avatar.png` | 217 706 B | **Onboarding sonrası ilk ekran Feed** — header sağ üstte yeni dairesel **`M` avatar** (softGold→copperMuted gradient, copper glow), Gruplar action button + Search ile birlikte. Bottom nav yeni 5 tab: **Feed (aktif) / Gruplar / Market / İlanlar / Panel** |
| `02_jobs_tab_active.png` | 205 445 B | İlanlar tab (756, 2180) tap → **JobsScreen tab içinde** açıldı — FırınNetHeader ("Jobs · Sektörün iş ağı"), Usta Arıyor / İş Arıyor segment, 4 ilan kartı (Taş Fırın Ustası ₺ 38–45k gece vardiyası, Pastacı Yardımcısı, Tezgâh & Sipariş, Pide Ustası). Bottom nav'da İlanlar aktif (work_rounded ikon) |
| `03_new_bottom_nav.png` | 205 923 B | Aynı Jobs tab'ı — 5 tab sırası net görünür: Feed / Gruplar / Market / **İlanlar** (aktif) / Panel. Profil yok |
| `04_profile_push_from_feed.png` | 169 390 B | Feed avatar (975, 185) tap → **ProfileScreen full-screen push** — kendi AppBar'ı (geri butonu var), Profil header, İstatistikler kartı, Hesap ListTile'ları. Bottom nav görünmez (push üstte) |
| `05_panel_still_accessible.png` | 205 960 B | Panel tab (972, 2180) tap → **Panel hâlâ tam fonksiyonel** — Üretim Yönetimi (Reçete + 4 mini grid) + Bayi Yönetimi (3/4 bayi · ₺1.449 açık · ₺1.560 teslim · ₺600 tahsilat). Bottom nav'da Panel aktif (`dashboard_customize_rounded` yeni ikon) |

Yardımcı dump XML'leri: `_dump_feed`, `_dump_jobs`, `_dump_feed2`, `_dump_profile`, `_dump_panel`.

---

## 7. Eklenen / Değişen Dosyalar

**Genişletildi:**
- `lib/features/dashboard/screens/app_shell.dart` — `_tabs` listesi: Profile çıkarıldı, Jobs eklendi, Panel ikonu `dashboard_customize_rounded`'a yükseltildi
- `lib/app/router/app_router.dart` — `/jobs` ShellRoute içine alındı, `/profile` shell DIŞI üst-seviye GoRoute olarak korundu
- `lib/features/feed/screens/feed_screen.dart` — `_FeedHeader` actions array'i: notifications kaldırıldı, **`_ProfileAvatarAction` ConsumerWidget** eklendi (avatar tap → profile push); `profileControllerProvider` import'u eklendi

**Dokunulmadı:**
- `lib/features/dealers/**` — tek satır değişmedi
- `lib/features/bakery_panel/**` — tek satır değişmedi
- `lib/features/social_groups/**` — repository/state/widgets değişmedi
- `lib/features/feed/models/**`, `repositories/**`, `providers/**`, `widgets/**` — feed davranışı değişmedi
- `JobsScreen.dart` — tek satır değişmedi (PASS 3'te FırınNetHeader pattern'inde olduğu için tab'a uyumlu)
- `ProfileScreen.dart` — tek satır değişmedi
- Splash / Onboarding / CreateProfile — initial route akışı zaten Feed'e gidiyordu

---

## 8. Geriye Dönük Uyumluluk

- `/profile` deeplink → ProfileScreen full-screen push olarak açılır (önceki tab geçişi yerine)
- `/jobs` deeplink → bottom nav İlanlar tab'ında açılır (önceki full-screen pop yerine)
- Onboarding "Kayıtsız Devam Et" → `/feed` (aynı)
- "Profilden Çık" → `/onboarding` (aynı, ProfileScreen içinden)
- `/groups`, `/groups/create`, `/groups/:id`, `/dealers/**`, `/panel/**` route'ları değişmedi

---

## 9. UX Notları

### Header avatar tasarımı
- 40 × 40 dairesel
- Gradient: `softGold` → `copperMuted` (sıcak, premium)
- `copper alpha 0.22` glow shadow (hafif derinlik)
- `borderHairline` 0.6 px çerçeve (PASS 3 dili)
- Profil baş harfi: white, w800, 15 px
- InkWell `softGold alpha 0.08` splash

### Notifications çıkarıldı (kasıtlı)
Önceki Feed header'da notifications icon vardı (`_noop`). MVP için **gerçek bildirim sistemi olmadığı sürece** placeholder ikon kalabalık yaratıyordu. Avatar aktif bir CTA olduğu için yer doğal olarak ona açıldı. V2'de bildirim sistemi geldiğinde geri eklenir.

### İkon dengesi
3 nav slotunda `outlined / rounded` çift ikon kullanılıyor (Feed, Gruplar, Market, İlanlar, Panel). Aktif tab `rounded` (dolu, daha güçlü), pasif tab `outlined` (çizgi). Bu dil PASS 2/3'te belirlendi, korundu.

---

## 10. Kalan Öneriler / V1.1

1. **İlanlar filtreleme** — Mevcut JobsScreen 2 segment (Usta Arıyor / İş Arıyor) içeriyor. V1.1'de şehir, vardiya, maaş aralığı filtreleri.
2. **Profile avatar badge** — Gelen mesaj/onay sayısı için kırmızı nokta veya sayı (backend olduğunda).
3. **Pull-to-refresh** — Feed/Gruplar/Market/İlanlar tab'larına RefreshIndicator. Şu an `BouncingScrollPhysics` var ama refresh hook yok.
4. **Profile shell dışı push transition** — şu an default cupertino slide; özel transition (zoom-in vs) eklenebilir.
5. **Header avatar long-press** — quick actions menüsü (Profilden Çık, Hesap, Ayarlar).
6. **Bottom nav badge** — V Sosyal Priority Fix'te de önerildi: Gruplar'da yeni mesaj sayacı, İlanlar'da yeni ilan sayacı (backend olduğunda).
7. **JobsScreen'e composer bağlama** — "Yeni ilan ekle" CTA, Feed composer benzeri ama PostType.job filtreli. V2.

---

**Nav-Profile-To-Jobs durumu:**
- ✅ Bottom nav 5 tab: **Feed / Gruplar / Market / İlanlar / Panel** — Profil ana tab'dan çıkarıldı, Jobs İlanlar olarak ana tab oldu
- ✅ Profile erişimi: Feed header sağ üstte dairesel avatar → push ile full-screen Profile
- ✅ `/jobs` shell içinde tab; `/profile` shell DIŞI push route
- ✅ Panel ikonu `dashboard_customize_rounded`'a yükseltildi
- ✅ JobsScreen ve ProfileScreen tek satır değişmedi (PASS 3 yatırımı reuse edildi)
- ✅ Bayi yönetimi, Panel iş mantığı, Feed/Social repository tek satır değişmedi
- ✅ `flutter analyze` temiz, `flutter test` 42/42, debug APK build OK
- ✅ 5/5 screenshot otomatik alındı

V1.1 (badge, filtreleme, composer) veya başka sprint için talimatınızı bekliyorum.
