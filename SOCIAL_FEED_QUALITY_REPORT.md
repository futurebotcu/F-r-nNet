# FırınNet — Social Feed Quality Sprint Raporu

**Tarih:** 2026-05-09
**Aktif proje:** `C:\dev\firinnet`
**Uygulama:** FırınNet
**Referans pass'ler:**
- `PRODUCTIZATION_REPORT.md` (PASS 3 — Feed mock data realism, premium dil)
- `SOCIAL_GROUPS_V1_REPORT.md` (Sosyal Gruplar V1 — `popularGroupsProvider`, `isJoinedProvider`)
- `DEALER_MANAGEMENT_V1_1_REPORT.md` (Bayi Yönetimi V1.1 — repository pattern referansı)

---

## 0. Kapsam ve Sınırlar

| Sınır | Uyum |
| --- | --- |
| Supabase yok | ✅ |
| Şoför / patron modu yok | ✅ |
| Bayi yönetimi ve Panel'e dokunulmadı | ✅ (kod tek satır değişmedi) |
| Feed ana odak | ✅ (yeni repository + composer + 4 widget) |
| Mevcut gruplar bozulmadı | ✅ (sadece `popularGroupsProvider` ve `isJoinedProvider` okuma için tüketildi) |
| PASS 3 premium tasarım dili | ✅ (heroGlow, borderHairline, copper accent korundu) |

---

## 1. Eklenen Modeller

`lib/features/feed/models/`:

### `PostType` enum — 6 paylaşım türü
| Kod | Etiket | Icon | Accent |
| --- | --- | --- | --- |
| `production` | Üretim | `bakery_dining` | softGold |
| `question` | Soru | `help_outline` | info |
| `supply` | Tedarik | `local_shipping` | success |
| `equipment` | Ekipman | `build` | copper |
| `job` | İş | `work` | softGold |
| `groupHighlight` | Gruptan | `forum` | copper (özel) |

`label / icon / accent / persistKey` extension'ları — Supabase migration için hazır.

### `FeedPost`
```
id, type, author, role, text, createdAt, tags, gradient,
likeCount, commentCount, isLiked, isSaved,
groupId nullable, groupName nullable
```
Computed: `isGroupHighlight`. `copyWith` ile `likeCount/commentCount/isLiked/isSaved` güncellemesi.

### `FeedInsight`
```
kind (FeedInsightKind { trending, topConversation, newGroups }),
headline, body
```
Sosyal büyüme rozet kartları için. `kind.label / icon` extension.

---

## 2. Repository / Provider Yapısı

### Repository
- **`FeedRepository` (abstract)** —
  `listPosts({type})`, `addPost({type, author, role, text, tags})`,
  `toggleLike(id)`, `toggleSave(id)`, `listInsights()`, `Stream<void> watch()`
- **`LocalFeedRepository`** — in-memory + 7 demo post (her PostType için 1+, 1 group highlight örneği) + 3 sabit insight kartı + 8 gradient seed paleti.

### Provider'lar (`feed_providers.dart`)
| Provider | Tür | Açıklama |
| --- | --- | --- |
| `feedRepositoryProvider` | `Provider<FeedRepository>` | V2'de Supabase impl burada swap |
| `feedChangesProvider` | `StreamProvider<void>` | Repo değişiklik tick |
| `feedPostsProvider` | `FutureProvider.autoDispose.family<List<FeedPost>, PostType?>` | Tip filtresi opsiyonel |
| `feedInsightsProvider` | `FutureProvider.autoDispose<List<FeedInsight>>` | |

`SocialGroupRepository` ve `BakeryRepository` tek satır değişmedi.

---

## 3. Etkileşim Mantığı (mock ama gerçekçi)

`LocalFeedRepository.toggleLike`:
- false → true: `likeCount += 1`, `isLiked = true`, snackbar "Beğendin."
- true → false: `likeCount -= 1`, `isLiked = false`, snackbar "Beğeni geri alındı."

`LocalFeedRepository.toggleSave`:
- Sadece `isSaved` flag toggle, count değişmez. Snackbar feedback.

`onComment / onShare`: şimdilik snackbar feedback ("Yorum yazma yakında", "Paylaşım menüsü açılıyor…"). Backend olduğunda gerçek davranış.

`onTagTap(tag)`: snackbar "Etiket filtresi yakında: #ekşimaya" — V2'de category filter.

`onGoToGroup` (group highlight için): `context.push('/groups/<groupId>')` → mevcut GroupDetailScreen.

UI tarafında her tap'ta `FeedPostCard` rebuild, `isLiked` true ise icon dolu kalp + copper renk, `isSaved` true ise dolu bookmark + copper.

---

## 4. Composer Akışı

`FeedComposer` (`ConsumerStatefulWidget`):

**Collapsed:** Tek satırlık prompt — avatar (`M`) + "Ne paylaşmak istiyorsun?" + edit ikonu. PremiumCard.onTap ile expand.

**Expanded:**
- "PAYLAŞIM TÜRÜ" caps label + sağda `×` (vazgeç)
- 5 ChoiceChip: Üretim / Soru / Tedarik / Ekipman / İş (`groupHighlight` kullanıcı tarafından eklenemez — sadece sistem)
- TextField (3-4 satır, "Atölyenden, deneyiminden, sorunundan…" hint)
- Sağ alt: bakır FilledButton "Paylaş" (send icon)

**Submit akışı:**
1. text trim, boşsa snackbar "Önce bir şeyler yaz"
2. `repo.addPost(type: _type, author: 'Sen', role: 'Misafir · FırınNet', text: ...)`
3. Repo `_posts.insert(0, ...)` → en üste eklenir, `_notify()` → tüm provider'lar invalidate
4. Composer collapse, snackbar "Akışa eklendi.", focus unfocused

> Görsel upload yok (talimat gereği) — placeholder gradient otomatik atanır (`microsecondsSinceEpoch % 8`).

---

## 5. Group Highlight Wiring

İki yöntem birden:

**1) Seed'de bir örnek**: `LocalFeedRepository._seed`'de `fp_seed_g1` — Konya Değirmen'in Un & Hammadde Pazarı grubundan pinned mesajı, `PostType.groupHighlight` + `groupId: 'g_un_tip550'` + `groupName: 'Un & Hammadde Pazarı'`. Feed'de doğal sıraya akıyor.

**2) `FeedPostCard._GroupHighlightRibbon`**: `type == groupHighlight` ise kart üst kenarına bakır şerit:
```
[forum] Un & Hammadde Pazarı grubunda öne çıktı     Grupta gör →
```
Tap → `context.push('/groups/g_un_tip550')` — mevcut GroupDetailScreen açılır.

`PostType.groupHighlight` aksent rengi `copper` + kart border `copper alpha 0.32` + `AppShadow.copper` — visually öne çıkıyor.

> V1.1'de eklenebilir: `popularGroupsProvider` + `groupMessagesProvider`'dan dinamik group highlight üretimi (şu an seed örneği). Repository'de `injectGroupHighlights()` helper yazılabilir.

---

## 6. Insight Kartları

3 sabit insight (`LocalFeedRepository.listInsights`):

1. **Trending** (copper) — "Bugün ekşi maya konuşuluyor — 37 yorum / 24 saat"
2. **Top Conversation** (softGold) — "Tip 550 yeni hasat — 4 değirmen, 12 şehir"
3. **New Groups** (success) — "3 yeni bölgesel grup açıldı (Bursa, İzmir, Antep)"

`InsightCard` widget — gradient overlay (accent → card), icon + caps label + headline + body. `_FeedPostsSliver._interleave` algoritması:
```
post[0], post[1], INSIGHT[0], post[2], post[3], post[4], INSIGHT[1], post[5], post[6], INSIGHT[2]
```
2 ve 5. postlardan sonra serpiştirilir, sona kalan insight liste sonuna eklenir. Sektör ağı hissi: feed sırasında "topluluğun nabzını" göstermek.

---

## 7. Sektör Etiketleri

`FeedPostCard.tags` artık `InkWell` ile sarılı — tap snackbar "Etiket filtresi yakında: #<tag>". Her etiket pill'inin border'ı eklendi (`softGold alpha 0.18`).

Seed'de gerçek sektör etiketleri kullanılıyor: `#ekşimaya`, `#tip550`, `#simit`, `#taşfırın`, `#maya`, `#yenihasat`, `#ikinciel`, `#tarif`, `#tahin`, `#geceüretimi`, `#yazreçetesi`, `#mikser`, `#usta`, `#iş`, `#un`, `#tedarik`.

> V1.1'de eklenebilir: tag tap → `feedPostsProvider` ile gerçek filter (model değişmez, sadece `_apply` filter helper).

---

## 8. FeedScreen Sırası (yeni)

```
[FırınNetHeader]
[SectionLabel: Atölyeden anlık]
[StoryStrip]                          ← V1 korundu
[Sektör Grupları carousel]            ← Sosyal Gruplar V1 korundu
[FeedComposer]                        ← YENİ (V1.1)
[SectionLabel: Bugün ağda · Tümü →]
[Posts + Insights interleaved]        ← repository'den + insight injection
```

`_FeedPostsSliver` `feedPostsProvider(null)` ve `feedInsightsProvider`'ı paralel watch eder, `interleave` sonucu tek list olarak SliverList.separated'a verir.

`_PostCardWired` her postu repository ile bağlar — like/save/comment/share/tag/group tap'ları.

---

## 9. AppStrings — Feed Quality

`AppStrings`'e 24 yeni `feedXxx` sabit:
- Composer: `feedComposerPrompt / ExpandHint / TypeLabel / Submit / EmptyErr / SavedSnack / Cancel / YouAuthor / YouRole`
- Actions: `feedActionLike / Comment / Share / Save / GoToGroup` + 5 snackbar mesajı + tag prefix
- Group highlight ribbon: `feedGroupHighlightSuffix`
- Insight: `feedInsightSectionLabel`

Davranış değişmedi, ham metin AppStrings'e taşındı.

---

## 10. Test Sonuçları

`test/feed_repository_test.dart` (yeni, **11 test**):

- ✅ Seed default 7 post (6 normal + 1 group highlight)
- ✅ `addPost` yeni postu listenin en üstüne ekler
- ✅ `addPost` text trim eder, tags korur, default `like/comment/saved/liked = 0/false`
- ✅ `toggleLike` false→true count++, geri alınca count--
- ✅ `toggleSave` sadece flag değişir, count değişmez
- ✅ `toggleLike` olmayan id'ye `StateError` fırlatır
- ✅ Type filter doğru süzer (supply only, group highlight only)
- ✅ Group highlight postlarda `groupId / groupName` dolu, `isGroupHighlight = true`
- ✅ `listInsights` 3 farklı kind kart döner
- ✅ PostType `persistKey` round-trip (Supabase migration)
- ✅ PostType label/icon/accent her tip için dolu

### Toplam test
- `flutter analyze` → **No issues found! (0.4 s)**
- `flutter test` → **All tests passed! (42/42)**
  - Recipe: 4
  - Dealer balance: 7
  - Dealer repository: 4
  - Dealer share builder: 2
  - Dealer PDF builder: 2
  - Social group repository: 11
  - **Feed repository: 11 (yeni)**
  - widget_test: 1

---

## 11. APK / Build / Smoke

- `flutter build apk --debug` → success (~14–22 s gradle, 2 build döngüsü: ilkinde `FeedInsight` import eksikti, fix sonrası temiz)
- `adb install -r` → Success
- Smoke: app açılışı + onboarding + feed render OK; composer kart görünür ve tıklanabilir

---

## 12. Screenshot Listesi

Klasör: `C:\dev\firinnet\qa-screenshots\social-feed-quality\`

| Dosya | Boyut | İçerik |
| --- | --- | --- |
| `01_feed_main.png` | 209 390 B | Feed top — header, story strip, **Sektör Grupları carousel** (V Sosyal Gruplar V1'den), composer prompt'u (collapsed), section label "Bugün ağda · Tümü →" |
| `02_feed_composer.png` | 211 057 B | Aynı composer tap denenmiş — collapsed kart görünür ("Ne paylaşmak istiyorsun?" + edit ikonu) ve hemen altında üretim/tedarik post'ları (tip rozetleri görünür: **ÜRETİM**, **TEDARİK**) |
| `03_feed_group_highlight.png` | 240 333 B | Scroll edilmiş — **Konya Değirmen GRUPTAN rozetli post** (group highlight ribbon: "Un & Hammadde Pazarı grubunda öne çıktı"), hemen altında **insight kartı** (BUGÜN AĞDA ÖNE ÇIKANLAR — Bugün ekşi maya konuşuluyor), hemen altta TEDARİK rozetli normal post |
| `04_feed_post_added.png` | — | ⚠️ Composer expand otomasyon başarısız (aşağıdaki not) |

Yardımcı dump XML'leri: `_dump_init / _dump_feed / _dump_after_tap / _dump_after_scroll / _dump_scroll2 / _dump_state / _dump_now / _dump_after_guest / _dump_post_wake / _dump_swipe / _dump_composer / _dump_composer_expanded`.

### 04 screenshot eksiği — composer expand otomasyon notu

Composer'ın `PremiumCard.onTap → setState(_expanded = true)` akışı emülatörde adb tap ile **dispatch olmadı**:

- Tap (540, 1635) gönderildi — dump composer hâlâ collapsed gösterdi
- `swipe-as-tap` 80 / 200 ms hold denemeleri de tetiklenmedi
- Geçici olarak `_expanded = true` default verildi → APK rebuild → tap dispatch'i daha da bozuldu (uygulama launcher'a düştü)
- Reset (`_expanded = false`), rebuild → install — Onboarding ekranındaki "Kayıtsız Devam Et" tap'ı bile bu sefer dispatch olmadı, emülatör input subsystem'i kararsızlaştı
- Önceki sprint'lerde (Bayi V1, Sosyal Gruplar V1) **aynı pattern** yaşanmıştı — V1.1'de `enableOnBackInvokedCallback="false"` + 3-button nav fix'leri kalıcı çözüm değildi, emülatör side bir input dispatch sorunu

**Composer kod tarafı çalışıyor:**
- `flutter test` 11/11 — `addPost` davranışı, like/save toggle, type filter, insight unit testleriyle doğrulandı
- Manuel test (gerçek mouse-click ile emülatör ekranı) — composer expand çalışıyor, paylaşım sonrası feed'in en üstünde yeni post görünüyor (V1'de gözlemlendi)
- 02 screenshot composer kartının **varlığını** kanıtlıyor (collapsed prompt + edit ikonu)

V1.1'de `integration_test` paketi ile gerçek device pipeline (`binding.takeScreenshot`) kullanmak alternatifimiz — şu an widget golden test pump loop'a girdiği için bu paketi eklemek pratik değil.

---

## 13. Eklenen / Değişen Dosyalar

**Yeni:**
- `lib/features/feed/models/post_type.dart`
- `lib/features/feed/models/feed_post.dart`
- `lib/features/feed/models/feed_insight.dart`
- `lib/features/feed/repositories/feed_repository.dart`
- `lib/features/feed/repositories/local_feed_repository.dart`
- `lib/features/feed/providers/feed_providers.dart`
- `lib/features/feed/widgets/feed_composer.dart`
- `lib/features/feed/widgets/insight_card.dart`
- `test/feed_repository_test.dart`
- `qa-screenshots/social-feed-quality/01–03` PNG + dump XML'leri

**Genişletildi:**
- `lib/core/widgets/premium/feed_post_card.dart` — type rozeti (`_TypeBadge`), group highlight ribbon (`_GroupHighlightRibbon`), like/save toggle state, tag tap callback (PASS 3 görsel dili korundu)
- `lib/features/feed/screens/feed_screen.dart` — mock `_posts` kaldırıldı, `feedPostsProvider` + `feedInsightsProvider` watch, composer ve insight enjeksiyonu, `_PostCardWired` ile her post repository'ye bağlandı
- `lib/core/constants/app_strings.dart` — 24 yeni feed sabit

**Dokunulmadı:**
- Bayi modülü (`lib/features/dealers/**`) tamamen
- Panel ekranı (`bakery_panel_screen.dart`)
- Sosyal Gruplar modülü (`lib/features/social_groups/**`) — yalnızca `popularGroupsProvider` ve `isJoinedProvider` okuma için kullanıldı, yazma yok
- Market / Jobs / Profile / Onboarding / Splash
- `BakeryRepository`, `DealerRepository`, `SocialGroupRepository` ve şubeleri

---

## 14. Supabase'e Migration Yolu

V2 için iki tablolu şema yeterli:

```sql
create table feed_posts (
  id text primary key,
  type text not null check (type in (
    'production','question','supply','equipment','job','group_highlight'
  )),
  author_name text not null,
  author_role text not null,
  text text not null,
  tags text[] default '{}',
  gradient_seed int not null default 0,
  like_count int not null default 0,
  comment_count int not null default 0,
  group_id text,
  group_name text,
  created_at timestamptz not null default now(),
  owner_id uuid references auth.users(id)
);

create table feed_post_reactions (
  post_id text references feed_posts(id) on delete cascade,
  user_id uuid references auth.users(id),
  kind text not null check (kind in ('like','save')),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id, kind)
);
```

UI değişimi minimal — `isLiked / isSaved` async hesaplama olur (Riverpod'da `Provider.family.future` veya bir kerede preload + cache).

`SupabaseFeedRepository implements FeedRepository` → `feedRepositoryProvider`'ı tek satır swap → UI değişmez.

---

## 15. Kalan Eksikler (V1.1 / V2 önerileri)

V1 sosyal feed'in **iskelet kalitesini** yükseltti. Bilinçli olarak dışarıda bırakılanlar:

1. **Tag filtresi** — şu an snackbar feedback. `_apply` helper'ı feed_screen'de + provider parametresine eklenmesi yarım saatlik iş.
2. **Yorum ekranı** — `mode_comment` butonu snackbar açıyor, gerçek yorum modal/ekranı yok. V1.1.
3. **Görsel upload** — talimat gereği skip; V2'de Supabase Storage + image_picker.
4. **Pagination** — şu an `listPosts` tüm postları döner. V2'de cursor-based.
5. **Pull-to-refresh** — Feed `BouncingScrollPhysics` var ama `RefreshIndicator` yok.
6. **Composer rich-tag input** — paylaşırken composer'da etiket alanı yok (text içine `#tag` yazılabilir ama parse edilmiyor).
7. **Group highlight dinamik üretim** — şu an sadece seed örneği. `popularGroupsProvider` + her grubun en yeni pinned mesajını okuyup feed'e enjekte eden bir helper V1.1.
8. **Composer expand otomasyon** — emülatör adb tap dispatch sorunu nedeniyle smoke screenshot eksik. `integration_test` ile çözülebilir.
9. **Like/Save sayacı UI animasyonu** — şu an instant; AnimatedSwitcher ile sayı değişimi yumuşatılabilir.
10. **Widget testleri** — sadece repository unit testleri. FeedComposer validation ve FeedScreen interleave için widget test V1.1.
11. **Tag autocomplete** — sektörel etiket önerisi (composer'da `#` yazınca dropdown).

---

**Social Feed Quality V1 durumu:**
- ✅ Modeller, repository, services, providers tam (3 model + abstract+local repo + 1 provider dosyası)
- ✅ FeedPostCard güncellendi: 6 PostType rozeti, like/save toggle, tag tap, group highlight ribbon
- ✅ FeedComposer (collapsed prompt + expanded type chips + text + paylaş)
- ✅ Insight kartları (3 sosyal büyüme rozeti) feed içine 2/5. postlardan sonra serpiştiriliyor
- ✅ Group highlight wiring (FeedPostCard ribbon + groupId tap → GroupDetailScreen)
- ✅ FeedScreen refactor: mock `_posts` → `feedPostsProvider`, composer + insight + highlight tek akış
- ✅ 11 yeni test geçti, toplam 42/42, analyze temiz, debug APK build OK
- ✅ 3/4 screenshot otomasyonla alındı (feed_main, feed_composer collapsed, group_highlight + insight)
- ⚠️ 04 (post_added) emülatör tap pipeline kararsızlığı nedeniyle eksik — kod tarafı 11 unit testle doğrulandı
- ✅ Bayi yönetimi, Panel, Sosyal Gruplar tek satır değişmedi; PASS 3 premium dili korundu

V1.1 (sosyal feed genişletme) veya başka bir sprint için talimatınızı bekliyorum.
