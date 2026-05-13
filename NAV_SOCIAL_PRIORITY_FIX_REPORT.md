# FırınNet — Navigation + Social Priority Fix Raporu

**Tarih:** 2026-05-09
**Aktif proje:** `C:\dev\firinnet`
**Uygulama:** FırınNet
**Önceki sprintler:**
- `SOCIAL_FEED_QUALITY_REPORT.md` (Feed kalite)
- `SOCIAL_GROUPS_V1_REPORT.md` (Sosyal Gruplar V1)
- `DEALER_MANAGEMENT_V1_1_REPORT.md` (Bayi V1.1)

---

## 0. Sprint Hedefi

Önceki sprintlerden sonra **kod tarafı zenginleşti** ama UI'da ürün önceliği belirsizdi:

- Bottom nav'da **Jobs** ana tab idi → ürün vaadiyle uyumsuz (Jobs sektör için bir post-type, ana modül değil)
- **Sosyal Gruplar** sadece Feed içinde küçük yatay carousel olarak görünür
- Yeni kullanıcı uygulamayı açtığında sektör sosyal akışına direkt giremiyordu

Bu sprint **sadece navigation + sosyal öncelik düzeltmesi**. Yeni modül eklenmedi, mevcut iş mantığına dokunulmadı.

---

## 1. Karar Gerekçeleri

### Neden Jobs ana tab'dan çıkarıldı?

| Argüman | Detay |
| --- | --- |
| **Ürün vaadiyle uyum** | FırınNet'in 5 ana sosyal alanı: feed (akış), gruplar (topluluk), market (B2B alım-satım), panel (üretim/bayi defteri), profil. **Jobs** bunların hiçbiri değil — sektör bağlamı içinde **bir post-type** (`PostType.job` mevcut Feed'de). |
| **Veri akışı bağlamı** | İş ilanları zaten `PostType.job` olarak Feed/Market içinde sektörel olarak akıyor. Ana tab olarak ayrı bir ekran "yarı boş" duruyor. |
| **Bilişsel yük** | 5 tab navigation'da her tab'a kullanıcı niyeti gerek. Jobs'a gitmek için niyetli kullanıcı az; Feed/Gruplar/Market'e gelirken Jobs'a kazara basma riski yüksek. |
| **Kod / route güvenliği** | `JobsScreen.dart`, `/jobs` route ve bağımlılıkları **silinmedi** — `Feed/Market` içinde post-type olarak kalır, ileride **Sosyal/Market alt modülü** olarak yeniden ekranlanabilir. |

### Neden Gruplar ana tab oldu?

| Argüman | Detay |
| --- | --- |
| **Sosyal omurga** | FırınNet'in tanımı: "Fırıncının dijital ağı". Akış (Feed) + topluluk (Gruplar) bunun iki ayağı. Tek tab feed birinci sınıf vatandaş yapıyor; gruplar yine ayrı bir sosyal alan olmalı. |
| **Carousel yetersiz** | Feed'deki yatay carousel "popüler 6 grup" gösteriyor; tam liste, kategori filtresi, "üye olduklarım" görünümleri için tam-ekran tab gerekli. |
| **Discovery** | Yeni kullanıcı sektör topluluklarını gözlemledikten sonra katılır — ana navigation'da hızlı erişim önemli. |
| **Ölçeklenme hazırlığı** | V1.1'de Gruplar tab'ı içinde alt sekmeler (Önerilen / Katıldıklarım / Bölgesel / Yeni) eklenebilir. |

### Yeni nav sırası (öncelik mantığı)

```
1. Feed       → ana sosyal akış (default açılış)
2. Gruplar    → ikincil sosyal alan (topluluk)
3. Market     → B2B alım-satım
4. Panel      → üretim + bayi defteri (destek modül)
5. Profil     → kullanıcı state'i + ayarlar
```

İlk üçü sosyal/network → bu vurguyu güçlendirir. Panel destek modülü olarak 4. sıraya alındı.

---

## 2. İlk Açılış / Default Route Doğrulaması

**Akış (V Nav-Social-Priority-Fix öncesi ile aynı, davranış değişmedi):**

1. App başlangıç → `GoRouter.initialLocation = AppRoutes.splash`
2. `SplashScreen` 1300 ms sonra → `context.go(AppRoutes.onboarding)`
3. `OnboardingScreen`'de "Kayıtsız Devam Et" → `context.go(AppRoutes.feed)`
4. `OnboardingScreen`'de "Profil Oluştur" → `/profile/create` → "Kaydet" → `context.go(AppRoutes.feed)`

**Bu sprintte ne değişti:**
- Bottom nav'ın **default index'i artık Feed (index 0)** — Jobs çıktığı için indeksleme kaymadı, Feed yine 1. sıra
- Daha önce de Feed default'tu, **Panel default açılmıyordu** (yanlış anlama yok)
- Smoke test: `01_feed_first_screen.png` Onboarding sonrası Feed'in açıldığını kanıtlıyor

> Panel açılışta otomatik açılan bir route değildi; sadece bottom nav'da 3. sıradaydı. Bu sprintten önce de "Panel default" değildi.

---

## 3. Bottom Nav Değişiklikleri

`lib/features/dashboard/screens/app_shell.dart`:

| Tab | Önce (V Sosyal Gruplar V1) | Sonra (V Nav-Social-Priority-Fix) |
| :-: | --- | --- |
| 1 | Feed (`dynamic_feed`) | **Feed** (`dynamic_feed`) — değişmedi |
| 2 | Market (`storefront`) | **Gruplar** (`groups_2`) — yeni |
| 3 | Panel (`dashboard`) | **Market** (`storefront`) |
| 4 | Jobs (`work`) — **çıktı** | **Panel** (`dashboard`) |
| 5 | Profil (`person`) | **Profil** (`person`) — değişmedi |

İkonlar:
- Gruplar: `Icons.groups_2_outlined` (default) / `Icons.groups_2_rounded` (aktif)
- Diğerleri: değişmedi (Feed dynamic_feed, Market storefront, Panel dashboard, Profil person)

`PremiumBottomNav` widget'ına dokunulmadı — sadece `_TabSpec` listesi yeniden sıralandı.

---

## 4. Route Değişiklikleri

`lib/app/router/app_router.dart`:

### Shell içine taşınan
- **`/groups` → `GroupsListScreen` (no-transition)** — daha önce shell DIŞI full-screen idi, artık tab.

### Shell içinden çıkarılan
- **`/jobs`** ShellRoute'tan kaldırıldı, üst seviye `GoRoute` olarak korundu (Feed/Market içindeki `PostType.job` link'leri için geriye dönük uyumluluk).

### Korunan (shell DIŞI full-screen, push akışı)
- `/groups/create` → `GroupCreateScreen`
- `/groups/:id` → `GroupDetailScreen`
- Tüm panel sub-route'ları (`/panel/recipe/production/dealer/waste/end-of-day/report`)
- Tüm dealer route'ları (`/dealers`, `/dealers/:id`, `/dealers/:id/{delivery,return,payment,share,adjustment}`)

`AppRoutes` sabitlerinde değişiklik yok — `groups`, `groupCreate`, `jobs` aynı path'lerde.

---

## 5. GroupsListScreen — Tab Uyumu

Şu ana kadar `GroupsListScreen` shell DIŞI full-screen idi → kendi `AppBar('Sektör Grupları')` + sağ üstte `IconButton(Icons.person_add_alt_1)` + alt FAB `Grup Oluştur` kullanıyordu.

Tab içinde gösterilince diğer tab ekranları (Feed/Market/Panel/Profil) ile **görsel tutarlılık** için:

- `AppBar` → **`FırınNetHeader`** pattern'i (subtitle dahil: "Sektör konuşmaları, bölgesel ağlar")
- `IconButton(person_add_alt_1)` → **`HeaderActionButton(Icons.add_rounded)`** sağ üstte
- FAB **kaldırıldı** — header action button yeterli
- ListView'in ilk öğesi olarak header eklendi (sliver yapısına çevirmek yerine ListView üst kısmında, mevcut search/filter/list rendering korundu)

Davranış aynı (search + filter + listing), sadece header şekli değişti.

---

## 6. Feed — Gruplara Erişim Kestirmeleri

Feed'de gruplara **iki yeni kestirme** eklendi:

### 1) Header'da Gruplar action button
`_FeedHeader` (yeni) — `FırınNetHeader` actions array'ine `Icons.groups_2_outlined` ile `HeaderActionButton`:
```dart
HeaderActionButton(
  icon: Icons.groups_2_outlined,
  tooltip: AppStrings.groupsTitle,
  onTap: () => context.go(AppRoutes.groups),  // tab geçişi
),
```
Bu kestirme **hız için** — feed'deyken hızlıca tab değiştirmek isteyen kullanıcı için.

### 2) "Tüm gruplar →" CTA tab geçişine bağlandı
`_GroupsSection` içindeki SectionLabel `onTrailingTap`:
- Önce: `context.push(AppRoutes.groups)` — full-screen push (bottom nav state güncellenmezdi)
- Şimdi: `context.go(AppRoutes.groups)` — **tab geçişi**, bottom nav Gruplar'a geçer

Sonuç: kullanıcının bottom nav'ı görerek hangi tab'da olduğunu anladığı tutarlı bir model.

> Feed'deki "Sektör Grupları" yatay carousel **korundu** (V Sosyal Gruplar V1'den geldiği gibi) — sadece daha güçlü CTA + header kestirmesi eklendi. Carousel kart tap'ları (her grup) hâlâ `context.push('/groups/<id>')` ile detail full-screen açıyor (push doğru — group detail ana navigation'a yapışmamalı).

---

## 7. Test / Build Sonuçları

| Kontrol | Sonuç |
| --- | --- |
| `flutter analyze` | **No issues found! (0.8 s)** |
| `flutter test` | **All tests passed! (42/42)** — değişmedi (testler repository tabanlı, navigation refactor'ından etkilenmiyor) |
| `flutter build apk --debug` | **Built `app-debug.apk`** (~27 s gradle) |
| `adb install -r` | Success |
| Smoke test | **5/5 screenshot otomatik** alındı (önceki sprintlerin tap kararsızlık problemi bu sprintte yaşanmadı) |

### Test dağılımı (değişmedi)
- Recipe: 4
- Dealer balance: 7
- Dealer repository: 4
- Dealer share: 2
- Dealer PDF: 2
- Social group: 11
- Feed repository: 11
- widget_test placeholder: 1

---

## 8. Screenshot Listesi

Klasör: `C:\dev\firinnet\qa-screenshots\nav-social-priority-fix\`

| Dosya | Boyut | İçerik |
| --- | --- | --- |
| `01_feed_first_screen.png` | 211 421 B | **Onboarding sonrası ilk ekran Feed** — header'da yeni Gruplar action button (groups_2 ikon), Sektör Grupları yatay carousel + "Tüm gruplar →" CTA. Bottom nav'da yeni 5 tab sırası: **Feed (aktif) / Gruplar / Market / Panel / Profil** |
| `02_bottom_nav_groups_tab.png` | 220 226 B | Gruplar tab'ı tap edildi → **GroupsListScreen tab içinde** açıldı — FırınNetHeader pattern ("Sektör Grupları · Sektör konuşmaları, bölgesel ağlar"), kategori chip row, "Üyesi olduğum gruplar" yatay strip, Ekşi Maya 84% ÜYE kartı |
| `03_groups_tab.png` | 197 147 B | Gruplar listesi scroll edilmiş — daha aşağıda "Tüm gruplar" sectionunda Konya Unculer, Konya Değirmen un grupları, Bayi & Dağıtım vb. tam liste görünüyor |
| `04_feed_groups_cta.png` | 211 157 B | Feed'e tab ile geri dönüş — header'da Gruplar action button + Sektör Grupları carousel + Tüm gruplar CTA görünür. Bottom nav Feed aktif, Gruplar passive |
| `05_panel_still_available.png` | 206 330 B | Panel tab'ı tıklandı → **Panel hâlâ tam fonksiyonel** — Üretim Yönetimi (Reçete + 4 mini grid) + Bayi Yönetimi (3/4 bayi · ₺1.449 açık · ₺1.560 teslim · ₺600 tahsilat) + bottom nav Panel aktif. Kanıt: navigation refactor'u Panel veya Bayi modülünü hiç etkilemedi |

Yardımcı dump XML'leri: `_dump_after_guest`, `_dump_groups`, `_dump_feed`, `_dump_panel`.

---

## 9. Eklenen / Değişen Dosyalar

**Genişletildi (sadece UI/navigation refactor, davranış değişmedi):**
- `lib/features/dashboard/screens/app_shell.dart` — `_tabs` listesi yeniden sıralandı: Feed/Gruplar/Market/Panel/Profil
- `lib/app/router/app_router.dart` — `/groups` ShellRoute içine taşındı; `/jobs` shell dışına alındı (route korundu); `/groups/create` ve `/groups/:id` shell DIŞI full-screen kaldı
- `lib/features/social_groups/screens/groups_list_screen.dart` — `AppBar` → `FırınNetHeader`; FAB kaldırıldı; davranış aynı
- `lib/features/feed/screens/feed_screen.dart` — `_FeedHeader` widget'ı eklendi (header'da Gruplar action button); "Tüm gruplar" CTA `context.push` → `context.go` (tab geçişi)

**Dokunulmadı:**
- `lib/features/dealers/**` — tek satır değişmedi
- `lib/features/bakery_panel/**` — tek satır değişmedi
- `lib/features/social_groups/repositories/**`, `models/**`, `providers/**`, `services/**` — repository/state davranışı değişmedi
- `lib/features/feed/models/**`, `repositories/**`, `providers/**`, `widgets/**` — feed davranışı değişmedi
- `JobsScreen.dart` — silinmedi, `/jobs` route ile erişilebilir
- Splash / Onboarding / CreateProfile — initial route akışı zaten Feed'e gidiyordu

---

## 10. Geriye Dönük Uyumluluk

- `/jobs` route → `JobsScreen` hâlâ açılır (deeplink veya gelecekteki Feed/Market post-type tap için)
- `/groups` deeplink → bottom nav Gruplar tab'ında açılır (önceden full-screen pop'a gerek vardı)
- `/groups/create` ve `/groups/:id` → push (full-screen) — back tuşu önceki tab'a döner
- Tüm dealer / panel sub-route'ları → değişmedi

---

## 11. Kalan Öneriler / V1.1

1. **Jobs alt modülü** — Market ekranında "İş İlanları" bölümü veya gruplar içinde `GroupCategory.jobs` (zaten var) tab'ında Jobs ekranı reuse edilebilir.
2. **Bottom nav badge** — Gruplar tab'ında okunmamış mesaj sayacı (Feed sosyal akışında yeni post sayacı). Backend olduğunda V2.
3. **Tab swipe gesture** — Feed ↔ Gruplar arası yatay swipe ile geçiş (PageView based shell).
4. **Header'daki Gruplar action button alternatifi** — Bottom sheet ile feed üzerinde "Sektör Grupları" perdesi (talimatta "isteğe bağlı" olarak geçti). Bu sprintte tab'a yönlendirme tercih edildi (en stabil çözüm).
5. **Splash → Feed direct** — Splash'tan onboarding bypass (kullanıcı zaten misafir/profil ise) — şu an her açılışta onboarding görünüyor (ama Profile state korunduğu için Feed otomatik geliyor — splash → onboarding kontrol akışı V1.1'de eklenebilir).
6. **Jobs URL keep-alive notu** — `/jobs` route bir süre kullanılmıyorsa V1.1'de tamamen silinmesi düşünülebilir (Jobs ekranı tamamen Market post-type'a evrilirse).
7. **Bottom nav shell test** — `app_shell_test.dart` ile tab seçim → route değişimi widget testi V1.1.

---

**Nav-Social-Priority-Fix durumu:**
- ✅ İlk açılış kesinlikle Feed (smoke + 01_feed_first_screen kanıtı)
- ✅ Bottom nav 5 tab: **Feed / Gruplar / Market / Panel / Profil** — Jobs ana tab'dan çıkarıldı
- ✅ `/groups` shell içinde tab; `GroupsListScreen` FırınNetHeader pattern'iyle uyumlu
- ✅ Feed'de iki ek Gruplar kestirmesi (header action button + tab'a yönlendiren CTA)
- ✅ Panel ve Bayi Yönetimi tek satır değişmedi, hâlâ tam fonksiyonel (`05_panel_still_available` kanıtı)
- ✅ `/jobs` route + `JobsScreen` korundu (geriye dönük uyumluluk)
- ✅ `flutter analyze` temiz, `flutter test` 42/42, debug APK build OK
- ✅ 5/5 screenshot otomatik alındı

V1.1 navigation iyileştirmeleri (badge, tab swipe, splash bypass) veya başka sprint için talimatınızı bekliyorum.
