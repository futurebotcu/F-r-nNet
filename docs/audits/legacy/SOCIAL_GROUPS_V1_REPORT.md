# FırınNet — Sosyal Gruplar V1 Raporu

**Tarih:** 2026-05-09
**Aktif proje:** `C:\dev\firinnet`
**Uygulama:** FırınNet
**İlgili pass'ler:** Bayi V1 / V1.1 (`DEALER_MANAGEMENT_REPORT.md`, `DEALER_MANAGEMENT_V1_1_REPORT.md`)

---

## 0. Kapsam ve Sınırlar

| Sınır | Uyum |
| --- | --- |
| Supabase yok | ✅ |
| Backend yok | ✅ (in-memory + seed) |
| Şoför / patron modu yok | ✅ |
| Bayi yönetimi bozulmadı | ✅ (kod tarafı + 13 dealer testi V1'den korundu) |
| Panel'e dokunulmadı | ✅ |
| Feed bozulmadı | ✅ (story strip altına ek section, yapı korundu) |
| Repository / provider mimarisi | ✅ Bayi V1.1 ile aynı pattern |
| Veri modeli Supabase'e taşınabilir temizlikte | ✅ persistKey extension'ları + dokümante edilmiş şema |

---

## 1. Eklenen Modeller

`lib/features/social_groups/models/`:

### `GroupCategory` enum (8 kategori)
| Kod | Etiket | persistKey |
| --- | --- | --- |
| `bakers` | Fırıncılar Genel | `bakers` |
| `flour` | Un & Hammadde | `flour` |
| `dealer` | Bayi & Dağıtım | `dealer` |
| `equipment` | Ekipman Alım Satım | `equipment` |
| `jobs` | Usta İlanları | `jobs` |
| `recipe` | Reçete & Üretim | `recipe` |
| `regional` | Bölgesel Gruplar | `regional` |
| `wholesale` | Toptancılar | `wholesale` |

### `SocialGroup`
```
id, name, description, category, ownerName, ownerId,
city, isPrivate, maxMembers (nullable → unlimited),
currentMemberCount, createdAt, tags, visualSeed
```
Computed:
- `isUnlimited` → `maxMembers == null`
- `isFull` → `maxMembers != null && currentMemberCount >= maxMembers!`
- `fillRatio` → 0..1 doluluk (sınırsızda 0)

### `GroupMessage`
```
id, groupId, authorName, authorRole, text,
createdAt, isPinned, reactionCount
```

---

## 2. Repository / Provider Yapısı

### Repository (Bayi V1 ile aynı pattern)
- **`SocialGroupRepository` (abstract)** —
  `listGroups`, `listPopular`, `listJoined`, `getGroup`,
  `createGroup`, `joinGroup`, `leaveGroup`, `isJoined`,
  `listMessages`, `postMessage`, `Stream<void> watch()`
- **`LocalSocialGroupRepository`** — in-memory + demo seed:
  - **9 demo grup**: Konya Unculer (187/250), Ekşi Maya Atölyesi (84/100), Taş Fırın Ustaları (**100/100 dolu**), Ekipman Alım & Satım (412, **sınırsız**), Un & Hammadde Pazarı (156/250), Bayi & Dağıtım Ağı (67/100), Usta Arayan Fırınlar (143/250), Toptan Susam/Maya/Yağ (38/50), İstanbul Pastane (özel, 28/50)
  - **5 demo mesaj** (Ekşi Maya Atölyesi, Un & Hammadde, Konya Unculer, Ekipman) — pinned'ler dahil, gerçekçi sektörel sorular
  - Mevcut kullanıcı (`me_misafir`) seed'de 2 gruba zaten üye (`g_eksi_maya`, `g_un_tip550`) — Feed/list ilk açılışta dolu görünüyor

### Service'ler
- **`GroupValidator`** — `validateName`, `validateDescription`, `validateLimit` (`null` → unlimited; `< 5` reddedilir)
- **`GroupJoinResult` enum** — `success / full / alreadyJoined / notFound` + Türkçe `message` extension

### Provider'lar (`social_group_providers.dart`)
| Provider | Tür | Açıklama |
| --- | --- | --- |
| `socialGroupRepositoryProvider` | `Provider<SocialGroupRepository>` | V2'de Supabase impl burada swap |
| `groupValidatorProvider` | `Provider<GroupValidator>` | |
| `groupChangesProvider` | `StreamProvider<void>` | Repo değişiklik tick |
| `groupsListProvider` | `FutureProvider.autoDispose.family<List<SocialGroup>, GroupCategory?>` | Kategori filtresi opsiyonel |
| `popularGroupsProvider` | `FutureProvider.autoDispose<List<SocialGroup>>` | Feed carousel için |
| `joinedGroupsProvider` | `FutureProvider.autoDispose<List<SocialGroup>>` | "Üyesi olduğum" |
| `groupByIdProvider` | `family<SocialGroup?, String>` | |
| `groupMessagesProvider` | `family<List<GroupMessage>, String>` | |
| `isJoinedProvider` | `Provider.family<bool, String>` | Sync — kart CTA için |

`BakeryRepository` ve `DealerRepository` tek satır değişmedi.

---

## 3. Katılımcı Limit Mantığı

```
maxMembers == null   → unlimited, isFull = false her zaman
maxMembers != null   → isFull = currentMemberCount >= maxMembers

joinGroup(id):
  if not found            → GroupJoinResult.notFound
  if alreadyJoined        → GroupJoinResult.alreadyJoined
  if isFull               → GroupJoinResult.full
  else                    → currentMemberCount++, joined.add(id), success

leaveGroup(id):
  if not joined           → noop
  else                    → currentMemberCount--, joined.remove(id)
```

**UI yansıması:**
- `GroupCard` CTA: `Katıl` (default) → `Aç` (üye ise) → `Dolu` (full + üye değil, disabled)
- `GroupDetail`: full + üye değil → kırmızı "Bu grup dolu — yeni katılım kapalı." banner + "Dolu" disabled buton
- Doluluk barı (`LinearProgressIndicator`): %80'in altı softGold, %80+ copper, **%100 (full) danger**

---

## 4. Ekran Akışı

`lib/features/social_groups/screens/` (3 ekran) + `widgets/group_card.dart`:

| Yol | Ekran | İçerik |
| --- | --- | --- |
| `/groups` | `GroupsListScreen` | Search + 9 kategori chip + (sorgu/filtre yokken) `Üyesi olduğum gruplar` yatay row + `Tüm gruplar` dikey list + sağ üst `+` icon + alt FAB `Grup Oluştur` |
| `/groups/create` | `GroupCreateScreen` | İsim/Açıklama/Kategori chips/Şehir/Public-Private SegmentedButton/5 limit chip (25/50/100/250/Sınırsız)/Etiket virgüllü/Oluştur |
| `/groups/:id` | `GroupDetailScreen` | Hero (kategori/tag/üye/limit/owner/doluluk)/Full banner (gerekirse)/Katıl-Aç-Ayrıl/Son konuşmalar (sabitlenmiş badge'li)/Composer (üye değilse kilit) |

`GroupCard` widget (kullanım): `compact` parametresi Feed carousel için ince variant, default list için tam variant. CTA mantığı kart içinde — Katıl/Aç/Dolu state machine'i.

### Kullanılan PASS 3 dili
- `PremiumScaffold` + dark gradient hero (`heroFrom/heroTo`)
- `AppShadow.heroGlow` + copper rim
- `borderHairline` kart kenarları
- `softGold` accent + `FadeSlideIn` hero girişi
- `BouncingScrollPhysics`
- `ChoiceChip` ile chip teması (PASS 2'den)

---

## 5. Feed Entegrasyonu

`lib/features/feed/screens/feed_screen.dart`:

Mevcut yapı **bozulmadan**, story strip'in **hemen altına** yeni `_GroupsSection` (`ConsumerWidget`) eklendi:

```
[Header]
[StoryStrip]
[_GroupsSection]            ← YENİ
  • SectionLabel("Sektör Grupları", trailing="Tüm gruplar →")
  • Horizontal carousel (popularGroupsProvider, max 6 grup)
[SectionLabel("Bugün ağda")]
[Posts list]
```

- Trailing `Tüm gruplar` → `context.push(AppRoutes.groups)`
- Carousel yüksekliği 290 px, kart genişliği 280 px (compact variant)
- Her kartın CTA'sı kendi join/open mantığını çalıştırır
- `popularGroupsProvider` `currentMemberCount desc` sıralı

Feed'in story_strip / post liste / community_tips yapısı **aynı**.

---

## 6. Test Sonuçları

`test/social_group_repository_test.dart` (yeni, **11 test**):

- ✅ Validator: boş isim hata, boş açıklama hata, limit < 5 hata, null OK
- ✅ Limit dolu → join engellenir (`GroupJoinResult.full`)
- ✅ Limit dolu değil → counter++ + `GroupJoinResult.success`
- ✅ Zaten üye → `GroupJoinResult.alreadyJoined`
- ✅ leave → counter-- + üyelikten çıkış
- ✅ Unlimited grup hiçbir zaman dolu sayılmaz
- ✅ Category filter doğru çalışır (regional 2, equipment 1)
- ✅ Joined groups doğru listelenir + join/leave sonrası listeyi günceller
- ✅ createGroup yeni grubu listeye ekler ve owner'ı joined yapar

### Toplam test
- `flutter analyze` → **No issues found! (0.4 s)**
- `flutter test` → **All tests passed! (31/31)**
  - Recipe calculator: 4
  - Dealer balance: 7
  - Dealer repository: 4
  - Dealer share builder: 2
  - Dealer PDF builder: 2
  - **Social group repository: 11 (yeni)**
  - widget_test placeholder: 1

---

## 7. APK / Smoke Test

- `flutter build apk --debug` → **Built `build/app/outputs/flutter-apk/app-debug.apk`** (~14 s gradle, ilk denemede group_detail_screen'de eksik `group_category` import yakalandı, fix edildi, ikinci build OK)
- `adb install -r` → Success
- Smoke pipeline (V1.1'den `enableOnBackInvokedCallback="false"` + 3-button nav korundu) bu pass'te **stabil çalıştı** — 5/5 screenshot otomasyonla alındı (Bayi V1'in tap kararsızlığının tersine).

---

## 8. Screenshot Listesi

Klasör: `C:\dev\firinnet\qa-screenshots\social-groups-v1\`

| Dosya | Boyut | İçerik |
| --- | --- | --- |
| `01_feed_groups_carousel.png` | 203 528 B | Feed üst — story strip, **Sektör Grupları yatay carousel** (Konya Unculer 187/250, %75 dolu, Bölgesel Gruplar etiketi), `Tüm gruplar →` CTA |
| `02_groups_list.png` | 201 300 B | Groups list — search + 9 kategori chip, `Üyesi olduğum gruplar` (Ekşi Maya 84/100 ÜYE), tam liste, sağ alt `Grup Oluştur` FAB |
| `03_group_detail.png` | 253 820 B | Ekşi Maya Atölyesi detay — hero (Reçete & Üretim, 84/100 üye, doluluk %84), `Ayrıl` butonu (üye olduğu için), 2 son mesaj (Hasan Kara pinned, Selin Ateş), composer aktif |
| `04_group_create.png` | 160 908 B | Grup Oluştur formu — isim/açıklama/kategori chips/şehir/Açık-Özel segment/5 limit chip/etiket alanı/Grubu Oluştur |
| `05_group_full_state.png` | 116 677 B | Fırıncılar Genel kategori filtreli — Taş Fırın Ustaları **100/100 dolu**, kırmızı doluluk barı, **`Dolu` disabled buton** |

Yardımcı dump XML'leri: `_dump_init.xml`, `_dump_feed.xml`, `_dump_list.xml`, `_dump_list2.xml`, `_dump_detail.xml`, `_dump_create.xml`, `_dump_full.xml`.

---

## 9. Eklenen / Değişen Dosyalar

**Yeni:**
- `lib/features/social_groups/models/group_category.dart`
- `lib/features/social_groups/models/social_group.dart`
- `lib/features/social_groups/models/group_message.dart`
- `lib/features/social_groups/services/group_validator.dart`
- `lib/features/social_groups/services/group_join_result.dart`
- `lib/features/social_groups/repositories/social_group_repository.dart`
- `lib/features/social_groups/repositories/local_social_group_repository.dart`
- `lib/features/social_groups/providers/social_group_providers.dart`
- `lib/features/social_groups/widgets/group_card.dart`
- `lib/features/social_groups/screens/groups_list_screen.dart`
- `lib/features/social_groups/screens/group_create_screen.dart`
- `lib/features/social_groups/screens/group_detail_screen.dart`
- `test/social_group_repository_test.dart`
- `qa-screenshots/social-groups-v1/01–05` PNG + 7 dump XML

**Genişletildi:**
- `lib/core/constants/app_strings.dart` — 50 yeni `groupXxx` / `feedSectionGroups` sabit
- `lib/app/router/app_router.dart` — 3 yeni rota + 3 import
- `lib/features/feed/screens/feed_screen.dart` — `_GroupsSection` + `_CarouselGroupCard` (story strip altına eklendi)

**Dokunulmadı:**
- Bayi modülü tamamen (`lib/features/dealers/**`)
- Panel ekranı (`bakery_panel_screen.dart`)
- Market / Jobs / Profile / Onboarding / Splash
- `BakeryRepository` ve şubeleri

---

## 10. Supabase'e Migration Yolu

V2 için tek dosya değişimi yeterli:

1. **Yeni:** `lib/features/social_groups/repositories/supabase_social_group_repository.dart`
   - `class SupabaseSocialGroupRepository implements SocialGroupRepository`
   - Tüm metotlar Supabase RPC veya `.from('social_groups').select(...)` ile bağlanır
   - `watch()` Supabase realtime channel
   - Üyelik state'i `group_memberships` tablosu üzerinden — yerel `_joined` Set'i yerine query

2. **Tek satır swap:** `social_group_providers.dart`:
   ```dart
   final socialGroupRepositoryProvider = Provider<SocialGroupRepository>((ref) {
     return SupabaseSocialGroupRepository(ref.read(supabaseClientProvider));
   });
   ```

3. **UI değişmez** — tüm ekranlar `SocialGroupRepository` arayüzü üzerinden çalışıyor.

4. **Şema önerisi (Supabase SQL):**
   ```sql
   create table social_groups (
     id text primary key,
     name text not null,
     description text not null,
     category text not null check (category in (
       'bakers','flour','dealer','equipment','jobs',
       'recipe','regional','wholesale'
     )),
     owner_name text not null,
     owner_id uuid references auth.users(id),
     city text default '',
     is_private boolean not null default false,
     max_members int,                          -- null = unlimited
     current_member_count int not null default 1,
     tags text[] default '{}',
     visual_seed int not null default 0,
     created_at timestamptz not null default now()
   );

   create table group_memberships (
     group_id text references social_groups(id) on delete cascade,
     user_id uuid references auth.users(id),
     joined_at timestamptz not null default now(),
     primary key (group_id, user_id)
   );

   create table group_messages (
     id text primary key,
     group_id text references social_groups(id) on delete cascade,
     author_name text not null,
     author_role text not null,
     text text not null,
     is_pinned boolean not null default false,
     reaction_count int not null default 0,
     created_at timestamptz not null default now()
   );

   -- RLS policy: kapalı gruplara owner approval gerekirse
   --   policy on group_memberships
   ```

   `currentMemberCount`'u trigger ile group_memberships INSERT/DELETE'te
   `social_groups.current_member_count` üzerinde tutmak `joinGroup` çağrılarını
   atomik tutar — istemcide manuel update gerekmez.

5. **`isJoined`** sync provider Supabase'de async olur. UI tarafında küçük bir refactor: ya
   `FutureProvider.family<bool, String>` ya da memberships'i bir kerede yükleyip
   `Set<String>` olarak cache'le (StateNotifier). UI değişimi minimal — sadece
   `ref.watch(isJoinedProvider(id))` çağrılarına `.value ?? false` eklemek yeter.

---

## 11. Kalan Eksikler (V1.1 / V2 önerileri)

V1 sosyal omurganın **iskeletini** kuruyor. Bilinçli olarak dışarıda kalanlar:

1. **Mesajlaşma realtime** — şu an local'de yazıyor ama anlık başka kullanıcıların görmesi backend ile mümkün; mesaj reaction (kalp tap) UI yok.
2. **Mesaj filtreleme/arama** — sabitlenmiş + son mesajlar gösteriliyor ama tarih filtresi, yazara göre süzme yok.
3. **Üye listesi ekranı** — Detail'de `Üye sayısı` görünüyor ama "kim?" listesi yok. Supabase + memberships geldiğinde kolay.
4. **Owner moderasyonu** — Mesaj silme, üye atma, grubu kapatma yok. V2 admin paneli.
5. **Private grup onay akışı** — Şu an `isPrivate` sadece bir badge; gerçek "katılım talep et → owner onaylar" akışı yok. V2.
6. **Edit / Delete grup** — Owner kendi grubunu güncelleyemiyor / silemiyor.
7. **Profil → Grup geçmişi** — Profile ekranında "Üyesi olduğu gruplar" şu an yok.
8. **Bildirim sayacı** — Yeni mesaj olduğunda bottom nav'da rozet vs. yok (zaten Feed nav'ı kullanılıyor).
9. **Image / dosya** — Mesajlarda sadece text, görsel yok.
10. **Feed'de daha çok grup içeriği** — Bir grubun pinned mesajı feed'de görünmüyor; "Topluluktan" tarzı highlights V2.
11. **Widget testleri** — Sadece repository unit testleri. GroupsListScreen filtresi / GroupCreateScreen validation için widget test seti V1.1.

---

**Sosyal Gruplar V1 durumu:**
- ✅ Modeller, repository, services, providers, router, 3 ekran + carousel widget tam
- ✅ Demo seed: 9 grup (1 dolu, 1 sınırsız, 1 özel, 4 farklı kategori), 5 mesaj, 2 mevcut üyelik
- ✅ Katılımcı limit mantığı (`isFull`, `fillRatio`, `joinGroup` enum sonucu)
- ✅ Feed entegrasyonu (story strip altı carousel + Tüm gruplar CTA), Feed yapısı korundu
- ✅ 31/31 test geçti, `flutter analyze` temiz, debug APK build + install OK
- ✅ **5/5 screenshot otomasyonla alındı** (Feed carousel, list, detail, create, full state)
- ✅ V1.1'de açtığımız tap pipeline iyileştirmeleri (predictive-back kapalı + 3-button nav) sayesinde smoke test stabil
- ✅ Bayi yönetimi V1 + V1.1 ve Panel modülü tek satır değişmedi

V1.1 (sosyal genişletme) veya başka bir sprint için talimatınızı bekliyorum.
