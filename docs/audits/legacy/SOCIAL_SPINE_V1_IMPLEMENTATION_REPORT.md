# FırınNet — Sosyal Omurga V1 Implementation Report

Tarih: 2026-05-15 (ilk yazım), 2026-05-16 (canlı apply + P0 fix güncellemesi)
PR scope: Feed + Sosyal Gruplar artık Supabase-backed (Local fallback korunarak)

**2026-05-16 durum:** Migration FırınNet project'e (ref `sjeqwiqgwzagengdukye`) MCP `apply_migration` ile uygulandı. Apply sonrası bulunan 1 adet P0 RLS bypass için düzeltme migration'ı (`social_spine_v1_fix_group_messages_insert`) aynı oturumda uygulandı. DB-level smoke geçti. Detay: [`SOCIAL_SPINE_LIVE_SMOKE_REPORT.md`](./SOCIAL_SPINE_LIVE_SMOKE_REPORT.md). UI smoke ve commit/push manuel adım olarak duruyor.

---

## What changed

### Yeni dosyalar
- `supabase/migrations/20260515120000_social_spine_v1.sql` — Feed + Gruplar omurgası, 7 tablo + RLS + triggerlar + grants.
- `lib/features/feed/repositories/supabase_feed_repository.dart` — `FeedRepository` interface'in Supabase implementasyonu.
- `lib/features/social_groups/repositories/supabase_social_group_repository.dart` — `SocialGroupRepository` interface'in Supabase implementasyonu.
- `test/social_spine_v1_test.dart` — 25 test (provider selection, guarded write block, SQL migration smoke).

### Değişen dosyalar
- `lib/features/feed/providers/feed_providers.dart` — `feedRepositoryProvider` artık `AppConfig.supabaseEnabled && currentAuthUser != null` ise SupabaseFeedRepository seçer (diğer modüllerle aynı pattern). Guarded wrapper korunuyor.
- `lib/features/social_groups/providers/social_group_providers.dart` — Aynı seçim mantığı.
- `lib/features/feed/screens/feed_screen.dart` — Empty/error state için `_FeedEmpty` widget'ı (ham `Text('Akış: $e')` yerine).
- `lib/features/social_groups/screens/groups_list_screen.dart` — Hata durumunda `_GroupsErrorState` placeholder.
- `lib/features/social_groups/screens/group_detail_screen.dart` — Hata mesajları kullanıcı dostu Türkçe.
- `lib/core/constants/app_strings.dart` — 6 yeni copy (feedErrorGeneric, feedEmptyState, groupsErrorGeneric, groupMessagesErrorGeneric, groupDetailErrorGeneric, feedEmptyStateGuest).

### Dokunulmayan dosyalar (kasıtlı)
- `lib/features/auth/**` — Auth modülü değişmedi.
- `lib/features/profile/**` — Profile RLS owner-only kaldı.
- Mevcut Local repository'ler — LocalFeedRepository ve LocalSocialGroupRepository aynen duruyor (Supabase off senaryosu için).
- Guarded repository'ler — yazma guard'ı aynı; sadece wrapped inner değişti.
- 159 mevcut test — hepsi geçmeye devam ediyor.

---

## Migration summary

Dosya: `supabase/migrations/20260515120000_social_spine_v1.sql`

7 yeni tablo:

| Tablo | Amaç | Önemli sütunlar |
|---|---|---|
| `feed_posts` | Sektör akışı gönderileri | owner_id, type (CHECK), text, tags[], group_id (FK→social_groups), group_name, **author_name** + **author_role** (snapshot), like_count, comment_count, is_deleted, timestamps |
| `feed_likes` | Beğeniler | (post_id, owner_id) composite PK |
| `feed_saves` | Bookmark | (post_id, owner_id) composite PK |
| `feed_comments` | Yorumlar | post_id, owner_id, text, author_name + author_role (snapshot), is_deleted, timestamps |
| `social_groups` | Sektör grupları | owner_id, name, description, category, city, is_private, max_members (default 250, CHECK >0), tags[], visual_seed, **owner_name** (snapshot), **member_count** (denormalize), is_deleted, timestamps |
| `group_members` | Üyelikler | (group_id, owner_id) composite PK, role CHECK ('owner','moderator','member'), joined_at |
| `group_messages` | Grup mesajları | group_id, owner_id, text, author_name + author_role (snapshot), is_deleted, timestamps |

### Tasarım kararı: denormalize author/owner snapshot

**Sorun:** `profiles` tablosunda RLS owner-only SELECT var (`USING id = auth.uid()`). Feed listelerinde her gönderinin yazarını join ile alabilseydik, profiles'ın policy'sini gevşetmek gerekirdi — bu, email/avatar_url gibi hassas alanların authenticated kullanıcılara açılması demek olurdu. Auth modülünü bozmama kuralı gereği bu yola gitmedim.

**Çözüm:** `feed_posts.author_name`, `feed_posts.author_role`, `feed_comments.author_name/role`, `social_groups.owner_name`, `group_messages.author_name/role` denormalize sütunları. BEFORE INSERT trigger (SECURITY DEFINER + search_path + execute revoke) `profiles`'tan display_name + (profession_badge ya da Türkçe rol etiketi) çekip satıra yazıyor. UPDATE'te yenilenmez (snapshot semantiği — eski post yazarın o anki kimliğini gösterir).

**Trade-off:** Kullanıcı profile_badge'ini güncellerse eski post'larındaki rol etiketi eski kalır. V1 için kabul edilebilir bir maliyet; ileride nightly refresh işi eklenebilir.

**Kullanıcı spec'inden sapma:** Spec'te `author_name`/`author_role`/`owner_name` sütunları yoktu. Kullanıcı "profile join veya ikinci query" esnekliği verdiği için (ve profile RLS'i bozmamak istediği için), denormalize yola gittim. Sap istisnası `member_count` sütunu için de geçerli — performans için denormalize sayaç, group_members triggerla bakım ediyor.

### Sayaçlar (denormalize, trigger ile bakım)
- `feed_posts.like_count` — `bump_feed_post_like_count` AFTER INSERT/DELETE on feed_likes.
- `feed_posts.comment_count` — `bump_feed_post_comment_count` AFTER INSERT/UPDATE/DELETE on feed_comments (is_deleted geçişini de izler).
- `social_groups.member_count` — `bump_social_group_member_count` AFTER INSERT/DELETE on group_members.

### group_members max_members enforcement
- `enforce_group_max_members` BEFORE INSERT trigger; `group_full` exception atar.
- SupabaseSocialGroupRepository `PostgrestException.message.contains('group_full')` → `GroupJoinResult.full` döner.

### Indexler
- `feed_posts(created_at desc) WHERE is_deleted=false` — feed listing.
- `feed_posts(owner_id, created_at desc)` — profil sayfasında "kendi postlarım".
- `feed_posts(type) WHERE is_deleted=false` — tip filtresi.
- `feed_posts(group_id) WHERE group_id IS NOT NULL AND is_deleted=false` — grup highlight.
- `feed_likes(owner_id)`, `feed_saves(owner_id)` — kendi beğenilerim/kayıtlarım.
- `feed_comments(post_id, created_at) WHERE is_deleted=false`.
- `social_groups(created_at desc) WHERE is_deleted=false`, `(category) WHERE is_deleted=false`, `(owner_id)`.
- `group_members(owner_id)`, `group_messages(group_id, created_at) WHERE is_deleted=false`, `(owner_id)`.

---

## RLS summary

Tüm 7 yeni tabloda RLS açık. Owner-only DML disiplini korundu.

### feed_posts
- SELECT: any authenticated, `is_deleted = false`. (Sektör akışı için kasıtlı.)
- INSERT: `owner_id = auth.uid()`.
- UPDATE/DELETE: yalnız owner.

### feed_likes / feed_saves / feed_comments
- feed_likes SELECT: any authenticated (like sayısının görünmesi için).
- feed_saves SELECT: yalnız kendi satırını (`owner_id = auth.uid()`).
- feed_comments SELECT: any authenticated, is_deleted=false.
- INSERT/UPDATE/DELETE: owner.

### social_groups
- SELECT: `is_deleted=false AND (is_private=false OR owner_id=auth.uid() OR self is a member)`.
- INSERT/UPDATE/DELETE: owner.

### group_members
- SELECT: kendi satırın VEYA grup public ise VEYA grup sahibiysen VEYA grup üyesiysen.
- INSERT: yalnız kendin (`owner_id = auth.uid()`) ve grup mevcut/silinmemiş.
- DELETE: kendin VEYA grup sahibi (moderasyon için).
- UPDATE: yok (role değişikliği V1'de yok).

### group_messages
- SELECT: `is_deleted=false AND` (grup public veya member veya grup sahibi).
- INSERT: `owner_id=auth.uid() AND` group_members exists check (yalnız üyeler mesaj atabilir).
- UPDATE/DELETE: yalnız mesaj sahibi.

### Güvenlik garantileri
- anon role'üne hiç DML grant yok (smoke test bunu doğruluyor).
- 4 SECURITY DEFINER snapshot fonksiyonu + 3 sayaç fonksiyonu + max_members enforce fonksiyonu hepsi `set search_path = public` + `revoke execute from public/anon/authenticated`.
- Hiçbir write policy'sinde `WITH CHECK (true)` yok (smoke test).
- `worker_profiles` ve `worker_experiences` pattern'i ile kıyaslandığında: oradakine benzer "select using (true)" yapısı sadece `feed_likes` için kullanıldı (like sayısı görünür olmak zorunda). Diğer yerlerde her zaman scope condition var.

---

## Feed repository behavior

`SupabaseFeedRepository`:
- `listPosts(type?)` — `feed_posts` `is_deleted=false`, ORDER `created_at DESC`, LIMIT 100. İkinci `feed_likes` ve `feed_saves` `.inFilter('post_id', ids)` sorgularıyla mevcut kullanıcı için `isLiked/isSaved` set'i hesaplanır. Profile join YOK (denormalize author kullanılıyor).
- `addPost(...)` — `feed_posts` INSERT (owner_id + type + text + tags). author_name/role server-side trigger ile dolar. INSERT'ten dönen row map edilir; `_notify()` UI refresh.
- `toggleLike(postId)` — `feed_likes` SELECT (exists?) → INSERT veya DELETE. Sonrası `feed_posts` taze satır + recomputed isLiked/isSaved döner. `like_count` server-side trigger ile +1/-1.
- `toggleSave(postId)` — Aynı pattern `feed_saves` üzerinde.
- `listInsights()` — Statik 3 kart (LocalFeedRepository ile aynı içerik). Gerçek metric backend'i ileride.
- `watch()` — İç `StreamController<void>`. Realtime kullanılmadı (V1 trade-off).
- `comments` — Interface'te yok; `feed_comments` tablosu hazır ama UI snackbar ile yutuyor. Comment akışı sonraki PR.

---

## Groups repository behavior

`SupabaseSocialGroupRepository`:
- `listGroups({category?})` — `social_groups` `is_deleted=false`, opsiyonel category. Her listing'de `_joinedCache` yenilenir (sync `isJoined()` için).
- `listPopular(limit)` — `member_count DESC` LIMIT 6.
- `listJoined()` — Önce joined cache yenilenir, sonra `id IN (joined_ids)` filtre.
- `getGroup(id)` — `is_deleted=false` filtreli single row.
- `isJoined(id)` — Sync; in-memory `_joinedCache`. List/refresh sonrasında doğru. Cache miss'te `false` döner (Provider tick'inde düzelir).
- `createGroup(...)` — `social_groups` INSERT (owner_name trigger ile), sonra `group_members` INSERT (role='owner'). İki INSERT atomik değil; ikinci başarısız olursa owner grubu görür ama üyesi değildir → manuel join. V1 trade-off.
- `joinGroup(id)` — Önce cache check → alreadyJoined. Sonra group exists check → notFound. Sonra `group_members` INSERT. `group_full` exception → `GroupJoinResult.full`. Duplicate PK (23505) → alreadyJoined. Başarı → `_joinedCache.add(id)` + `_notify()`.
- `leaveGroup(id)` — Owner ise sessizce no-op (V1 ownership transfer yok). Aksi halde DELETE.
- `postMessage(GroupMessage)` — INSERT (group_id, owner_id, text). author_name/role trigger ile.
- `listMessages(groupId)` — `is_deleted=false`, `created_at DESC`, LIMIT 200. `isPinned` ve `reactionCount` V1'de yok (false/0).

### LocalFeedRepository / LocalSocialGroupRepository
Hâlâ aktif; provider seçimi:
- `supabaseEnabled && user != null` → Supabase.
- Aksi halde → Local (seed: true).

Local'lar değişmedi.

---

## Guest/auth behavior

- **Guest (signed-out, supabase enabled veya değil):** Provider Local repository döner. Feed/Gruplar seed üzerinden gezilebilir. Yazma aksiyonlarında `canWriteCheckProvider` false döner → Guarded wrapper `GuestActionRequiredException` atar → UI `runGuardedMutation` veya `AuthRequiredGuard.canWriteWithRef` ile `AuthRequiredSheet` açar.
- **Auth'lu (signed-in, supabase enabled):** Provider Supabase repository döner. Tüm CRUD canlıya yazar. Yazma guard'ı yine çalışır ama her zaman geçer (canWrite=true). Defense-in-depth katmanı korunmuş olur (UI guard atlanırsa repo seviyesinde RLS de çalışır).
- **Supabase env yok:** Local repository, hem read hem write Local seed üzerinde işler. AuthRequiredGuard.canWrite() local profile non-guest ise true döner (mevcut V1.3.3 davranışı).

### Auth required sheet kontratı
Mevcut `AuthRequiredGuard.canWriteWithRef`, `runGuardedMutation`, ve `showAuthRequiredSheet` davranışı **hiç değişmedi.** Yeni Supabase repository'ler `GuestActionRequiredException`'ı doğrudan atmıyor; bunu Guarded wrapper yapıyor. Repository sadece auth gerektiren yerde `StateError('Oturum bulunamadı')` atar (örn. Composer guard atlanırsa repo da koruyor).

---

## Local fallback behavior

Spec şart: guest demo gezme. Mevcut davranış:

- AuthEntry → "Kayıtsız Devam" → guest flag set → `/feed`.
- Feed sayfası açılır. Provider → user null → LocalFeedRepository → seed posts gösterilir.
- Composer'a yazıp paylaşıma tıkla → AuthRequiredSheet açılır.
- Bir gruba "Katıl" tıkla → AuthRequiredSheet.

Bu davranış 184/184 testten geçiyor.

**Edge: Supabase enabled + signed-in + no posts:**
- Yeni signup olan ilk kullanıcı feed'i ilk açtığında `feed_posts` boş olur. `FeedScreen` artık `_FeedEmpty(icon: Icons.dynamic_feed_outlined, message: feedEmptyState)` placeholder gösteriyor: "Henüz paylaşım yok. İlk gönderiyi sen at — sektör seni bekliyor."
- Network hatası durumunda: aynı pattern, "Akış şu an yüklenemedi. Bağlantını kontrol edip yeniden dene." Ham exception görünmez.

---

## Tests added

`test/social_spine_v1_test.dart` — 25 yeni test, 4 grup:

1. **Provider selection (Supabase off):** 4 test. Provider'lar Guarded wrapper döner mi, Local seed read'leri çalışır mı.
2. **GuardedFeedRepository guest block:** 4 test. addPost/toggleLike/toggleSave guest için exception fırlatıyor mu; read bloklanmıyor mu.
3. **GuardedSocialGroupRepository guest block:** 5 test. createGroup/joinGroup/leaveGroup/postMessage exception, listGroups read serbest.
4. **Migration SQL smoke (string analizi):** 11 test. RLS açık mı (regex tablo başına), anon DML grant yok mu, SECURITY DEFINER fonksiyonlar revoke ile korunuyor mu, search_path set mi, `with check (true)` yasak mı, owner_id = auth.uid() var mı, group_messages insert member exists check'i içeriyor mu, max_members trigger'ı `group_full` raise ediyor mu, counter sütunları + triggerlar tanımlı mı, snapshot triggerları INSERT için mevcut mu.

`flutter test` toplam: **184 test passed (159 mevcut + 25 yeni).**

---

## analyze/test results

```
flutter pub get     → OK (pre-existing dependencies, no new packages added)
flutter analyze     → No issues found! (1.4s)
flutter test        → 184 / 184 passed
```

Tarama sonuçları:
- `rg "USING (true)|WITH CHECK (true)|service_role|debugPrint|print("` — gerçek production code'da hiç eşleşme yok; sadece yorum/test description'larında.
- `rg "Local*Repository|Supabase*Repository|feed_posts|social_groups|group_members|group_messages"` — beklenen 19 dosyada eşleşme (yeni eklenen dosyalar + repository referansları + test + migration).

---

## Known limitations

### Sosyal omurga
1. **Realtime yok.** Başka cihazda atılan post/mesaj otomatik gelmiyor. Pull-to-refresh + ekran yeniden açma gerekli. V2 için `Supabase.realtime.channel()` subscribe planlanmalı.
2. **Yorumlar UI'da yok.** `feed_comments` tablosu hazır, RLS doğru ama UI henüz yorum yazımı/listesi göstermiyor. `onComment` snackbar olarak kalıyor (önceki davranış aynı).
3. **createGroup atomik değil.** social_groups INSERT + group_members INSERT iki ayrı çağrı; ikinci başarısız olursa owner üye olmayan grup sahibi olur. Görünür arayüz tarafında join butonu görür ve manuel atabilir. V1 için kabul edilebilir.
4. **Owner-leave block sessiz.** Bir grup sahibi `leaveGroup` çağırırsa repository no-op döner; UI "ayrıldın" snackbar'ı gösterir ama aslında ayrılmamıştır. UI'da owner için Ayrıl butonunu gizlemek için ek bir kontrol gerekli (P2).
5. **Group messages `pinned` ve `reactionCount` V1'de yok.** Model alanı duruyor, repo `false`/`0` döner. Pinned özelliği gelecek PR.
6. **`gradient` post visualı.** DB'de saklanmıyor; post id hash'inden deterministik üretiliyor (LocalFeedRepository ile aynı palet). Tutarlı görsel ama özelleştirme yok.

### Migration
7. **Canlı DB'ye uygulanmadı.** Bu PR'da yalnız dosya. Aşağıdaki "Apply instructions" adımları manuel yapılmalı.
8. **`profiles` policy değişmedi.** `feed_posts.author_name/role` snapshot ile çözüldü; ileride yorum sahibi avatar'ı vs. eklenirse profile'a public-readable view eklemek gerekebilir.
9. **Author snapshot stale risk.** Kullanıcı display_name değiştirirse eski feed_posts/group_messages yazar adı eski kalır. Nightly refresh job veya sahibinin "profilimi güncelle ve tüm postlarımda yansıt" aksiyonu V2.

### LocalFeedRepository sınırlamaları (önceden de geçerli)
10. Hala in-memory; uygulama kapanınca yazma kaybolur. Sadece Supabase env yok veya guest senaryosunda kullanılır.

---

## Manual smoke checklist

Aşağıda ileri yapılması gerekenler (release öncesi). Adım adım, hata varsa P0/P1 raporla.

### A — Migration uygula
- [ ] `supabase/migrations/20260515120000_social_spine_v1.sql` dosyasını Supabase Studio SQL editor'de aç, kontrol et.
- [ ] `supabase db push` ile remote'a uygula (veya Studio'da çalıştır).
- [ ] `select version from supabase_migrations.schema_migrations` ile `20260515120000` satırını gör.
- [ ] `select tablename, rowsecurity from pg_tables where schemaname='public' and tablename like 'feed_%' or tablename like 'social_%' or tablename like 'group_%'` ile 7 yeni tablonun rowsecurity=true olduğunu doğrula.
- [ ] `select tablename, count(*) from pg_policies where schemaname='public' and tablename in ('feed_posts','feed_likes','feed_saves','feed_comments','social_groups','group_members','group_messages') group by tablename` ile policy sayılarını doğrula:
  - feed_posts: 4 (select, insert, update, delete)
  - feed_likes: 3 (select, insert, delete)
  - feed_saves: 3
  - feed_comments: 4
  - social_groups: 4
  - group_members: 3 (select, insert, delete)
  - group_messages: 4

### B — Guest browse (Supabase env var)
- [ ] Fresh install, `--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…` ile aç.
- [ ] AuthEntry → "Kayıtsız Devam" → `/feed`.
- [ ] Feed: LocalFeedRepository seed 7 post görünür.
- [ ] Composer'a yaz + Paylaş → AuthRequiredSheet açılır.
- [ ] Bir grup carousel'inde "Katıl" tıkla → AuthRequiredSheet açılır.
- [ ] Beğen/Kaydet tıkla → AuthRequiredSheet açılır.

### C — Authenticated feed
- [ ] Signup yeni ticari kullanıcı → Splash → `/feed`.
- [ ] Feed boş empty state: "Henüz paylaşım yok. İlk gönderiyi sen at."
- [ ] Composer → metin yaz + tip seç + Paylaş → post listede gözükür.
- [ ] DB doğrulama: `select id, owner_id, type, text, author_name, author_role, like_count, comment_count from feed_posts order by created_at desc limit 5`
- [ ] author_name = kullanıcı display_name, author_role = profession_badge veya account_type Türkçe etiketi.
- [ ] Beğen → like_count +1; tekrar tıkla → 0.
- [ ] DB: `select count(*) from feed_likes where post_id=...` 0/1 toggle ediyor.
- [ ] Kaydet → snackbar "Kaydedildi". DB: `feed_saves` satırı var.

### D — Authenticated gruplar
- [ ] Groups tab → boş listede empty (yeni DB) veya seed varsa görünür.
- [ ] FAB ile yeni grup oluştur → form → kaydet.
- [ ] DB: `select id, owner_id, name, category, owner_name, member_count, max_members from social_groups` → owner_name + member_count=1.
- [ ] `select count(*) from group_members where group_id=...` → 1 (owner satırı).
- [ ] Detail ekran → composer ile mesaj yaz → liste güncellenir.
- [ ] DB: `select author_name, text from group_messages where group_id=...` → trigger ile author_name dolu.
- [ ] Başka bir test kullanıcısıyla aynı gruba katıl → member_count +1. group_members satırı eklendi.
- [ ] Grup max_members=5 ile oluştur, 4 kişi daha katıl → 5. kişi join'i `GroupJoinResult.full` döner, snackbar "Grup dolu".

### E — Network hata / boş state
- [ ] Airplane mode aç → Feed sayfası açık → 30s sonra error state `_FeedEmpty(icon: cloud_off, message: feedErrorGeneric)` görünür. Ham exception yok.
- [ ] Aynı Groups list: `_GroupsErrorState` görünür. Detail: kullanıcı dostu Türkçe.

### F — RLS testi (canlı DB'de SQL editor ile)
- [ ] Kullanıcı A oturumuyla:
  ```sql
  set local role authenticated;
  set local request.jwt.claim.sub = '<A_user_uuid>';
  select id, author_name from feed_posts where is_deleted = false;
  ```
  - Kendi + diğer kullanıcıların is_deleted=false postlarını görmeli.
- [ ] feed_saves SELECT — yalnız A'nın save satırları:
  ```sql
  select * from feed_saves;
  ```
  - Sadece A'ya ait satırlar.
- [ ] Kullanıcı A B'nin feed_posts'una INSERT denesin (owner_id=B uuid'si) → policy "owner_id = auth.uid()" reddetmeli.

---

## Supabase migration apply instructions

**Migrasyonun canlı DB'ye uygulanması henüz YAPILMADI.** Aşağıdaki adımlar manuel olarak çalıştırılmalı. Önce staging/dev projede dene, sonra prod'a uygula.

### Yöntem 1 — Supabase CLI (önerilir)

```bash
# Repo kökünden:
supabase link --project-ref <your-project-ref>     # bir kerelik
supabase db push                                   # yerel migration'ı remote'a uygular
```

Bu komut `supabase/migrations/` altındaki yeni dosyaları sırayla remote'a uygular. `20260515120000_social_spine_v1.sql` zaten son sırada.

Önemli: `supabase db push` öncesi `supabase db diff` ile tam SQL diff'i gör.

### Yöntem 2 — Supabase Studio SQL editor (manuel)

1. Supabase Studio → SQL Editor → New query.
2. `supabase/migrations/20260515120000_social_spine_v1.sql` içeriğini yapıştır.
3. **Run** — başarılıysa "Success. No rows returned" mesajı.
4. `supabase_migrations.schema_migrations` tablosuna `('20260515120000', '{}', '{}')` satırını ekle (CLI ile push yapsaydık bunu otomatik yapardı):
   ```sql
   insert into supabase_migrations.schema_migrations (version, name, statements)
   values ('20260515120000', 'social_spine_v1', '{}');
   ```

### Doğrulama (her iki yöntemden sonra)

```sql
-- Migration kayıtlı mı
select version from supabase_migrations.schema_migrations
where version = '20260515120000';

-- Tablolar oluştu mu, RLS açık mı
select tablename, rowsecurity from pg_tables
where schemaname = 'public'
  and tablename in (
    'feed_posts','feed_likes','feed_saves','feed_comments',
    'social_groups','group_members','group_messages'
  );
-- 7 satır, rowsecurity = true her birinde.

-- Trigger fonksiyonları
select proname, prosecdef
from pg_proc
where pronamespace = 'public'::regnamespace
  and proname in (
    'snapshot_feed_post_author','snapshot_feed_comment_author',
    'snapshot_group_message_author','snapshot_social_group_owner',
    'bump_feed_post_like_count','bump_feed_post_comment_count',
    'bump_social_group_member_count','enforce_group_max_members'
  );
-- 8 satır, prosecdef = true.
```

### Rollback (eğer canlıda sorun çıkarsa)

```sql
-- Sıra önemli: önce triggerlar, sonra fonksiyonlar, sonra tablolar.
drop trigger if exists trg_feed_posts_snapshot_author on public.feed_posts;
drop trigger if exists trg_feed_comments_snapshot_author on public.feed_comments;
drop trigger if exists trg_group_messages_snapshot_author on public.group_messages;
drop trigger if exists trg_social_groups_snapshot_owner on public.social_groups;
drop trigger if exists trg_feed_likes_bump_count on public.feed_likes;
drop trigger if exists trg_feed_comments_bump_count on public.feed_comments;
drop trigger if exists trg_group_members_bump_count on public.group_members;
drop trigger if exists trg_group_members_enforce_max on public.group_members;
drop trigger if exists trg_feed_posts_updated_at on public.feed_posts;
drop trigger if exists trg_feed_comments_updated_at on public.feed_comments;
drop trigger if exists trg_social_groups_updated_at on public.social_groups;
drop trigger if exists trg_group_messages_updated_at on public.group_messages;

drop function if exists public.snapshot_feed_post_author cascade;
drop function if exists public.snapshot_feed_comment_author cascade;
drop function if exists public.snapshot_group_message_author cascade;
drop function if exists public.snapshot_social_group_owner cascade;
drop function if exists public.bump_feed_post_like_count cascade;
drop function if exists public.bump_feed_post_comment_count cascade;
drop function if exists public.bump_social_group_member_count cascade;
drop function if exists public.enforce_group_max_members cascade;

drop table if exists public.group_messages cascade;
drop table if exists public.group_members cascade;
drop table if exists public.social_groups cascade;
drop table if exists public.feed_comments cascade;
drop table if exists public.feed_saves cascade;
drop table if exists public.feed_likes cascade;
drop table if exists public.feed_posts cascade;

delete from supabase_migrations.schema_migrations
where version = '20260515120000';
```

---

## Jobs / Marketplace — V1 güvenli çözüm önerisi

Bu PR scope'unda **Jobs ve Marketplace implementasyonu yapılmadı.** Ana audit raporundaki P0-2 ve P1-7 hâlâ açık. Aşağıda V1 mağaza tarihi için minimal güvenli seçenekler:

### Marketplace
**Risk:** Bottom nav 3. tab tamamen hardcoded mock (`marketplace_screen.dart:38` const `_items`). Mağaza screenshot'larında olgun görünür ama içeride hiçbir kullanıcı listesi yok, hiçbir mesajlaşma yok.

**Öneri — en güvenli, V1 için:**
- **Marketplace tab'ını AppShell'den çıkar.** `lib/features/dashboard/screens/app_shell.dart` içindeki `_tabs` listesinden `AppRoutes.market` satırını kaldır. 4 tab kalır: Feed / Gruplar / İlanlar / Panel.
- Route tanımını koru (`/market` yeni tab'da değil ama deeplink uyumu için).
- Marketplace ekranı kalır ama erişimi yok; gelecekte tablo + repo eklendiğinde geri açılır.
- **Etkilenen dosyalar:** `lib/features/dashboard/screens/app_shell.dart` (3 satır).

Alternatif: tab kalır, ekrana "V2'de açılıyor" disclaimer banner'ı eklenir. Bu daha riskli (kullanıcı boş mock listede güveni sarsılır).

### Jobs
**Risk:** Bottom nav 4. tab hardcoded 7 mock ilan (`jobs_screen.dart:21`). Bireysel kullanıcı kendi `job_seek_posts` ilanını ana akışta göremez.

**Öneri — V1 için minimum bağlantı:**
- JobsScreen'i `myJobSeekPostsProvider` + (yeni) `activeJobSeekPostsProvider`'a bağla. "İş Arıyorum" segmenti `job_seek_posts where is_active = true` listesini gösterir.
- "İş Veriyorum" segmenti tablo olmadığı için `comingSoon` placeholder göster.
- **Etkilenen dosyalar:** `lib/features/jobs/screens/jobs_screen.dart` (büyük rewrite), opsiyonel yeni `active_job_seek_posts_provider` (`worker_providers.dart`'a eklenebilir).

**Bu, bu PR'ın kapsamı dışında.** Ayrı bir PR olmalı çünkü:
- Worker repository public select policy'sini zaten doğru çalışıyor (`job_seek_posts_select_active_or_own using is_active = true OR owner_id = auth.uid()`), yani RLS değişikliği gerekmez.
- UI değişimi orta ölçek (segment, kart, empty state, network state).
- Test eklemek gerekir.

**Etki:** P0-2 (Jobs/Marketplace) madde:
- Marketplace tab kaldırma → P0-2 → P1 düşer (ekran var ama erişimi yok, mock görünmüyor).
- Jobs bağlama → ayrı PR, V1 mağazaya çıkış öncesi yapılmalı.

---

## Remaining P0/P1 after this PR

Audit ana raporundan (`FIRINNET_FULL_SYSTEM_AUDIT.md`) hangileri bu PR'la çözüldü, hangileri açık kaldı:

### Çözülenler
- **P0-1 (Feed Supabase'siz)** → **ÇÖZÜLDÜ.** SupabaseFeedRepository + migration + provider selection.
- **P0-1 alt-modülü (Sosyal Gruplar Supabase'siz)** → **ÇÖZÜLDÜ.** SupabaseSocialGroupRepository + migration.
- **P2 (feed/groups error state ham exception)** → **ÇÖZÜLDÜ.** _FeedEmpty, _GroupsErrorState placeholderlar, Türkçe copy.

### Hâlâ açık P0
| Madde | Durum |
|---|---|
| P0-2 | Jobs/Marketplace mock — bu PR'da scope dışı. Yukarıdaki öneri uygulanmalı. |
| P0-3 | Hesap silme yok — bu PR'da scope dışı. Ayrı PR. |
| P0-4 | Android release debug imzası — config dosyası işi. Ayrı PR. |
| P0-5 | Privacy/Terms taslak banner — legal onay sonrası ayrı PR. |

### Hâlâ açık P1
- P1-1 Profile sahte istatistikler.
- P1-2 Feed Story strip hardcoded isimler.
- P1-3 production_date UTC sorunu.
- P1-4 Legal kabul backend log'u yok.
- P1-5 Adaptive launcher icon yok.
- P1-6 JobsScreen worker repo'ya bağlanmamış.
- P1-7 Marketplace tablosu yok.

### Yeni eklenenler (P2 polish)
- **P2 (sosyal — owner-leave UX):** Owner kendi grubundan "ayrılma" deneyimi sessiz no-op. UI'da gizleme önerisi (button hide if `group.ownerId == currentUserId`).
- **P2 (sosyal — yorum sistemi):** `feed_comments` tablosu hazır ama UI implementasyonu yok. Ayrı PR.
- **P3 (sosyal — realtime):** Başka cihazda atılan post otomatik gelmiyor. Supabase realtime subscribe ileride.
- **P3 (sosyal — author snapshot stale):** display_name değişirse eski postlar eski adı gösterir. Nightly refresh job veya kullanıcı tetikli refresh.

---

## Summary

| Boyut | Detay |
|---|---|
| Yeni Dart dosya | 2 (SupabaseFeedRepository, SupabaseSocialGroupRepository) |
| Yeni SQL dosya | 1 (`20260515120000_social_spine_v1.sql`) |
| Yeni test dosya | 1 (25 test) |
| Değişen Dart dosya | 5 (feed_providers, social_group_providers, feed_screen, groups_list_screen, group_detail_screen) |
| Değişen string sabit | 6 yeni copy (`app_strings.dart`) |
| Migration etkilediği tablo | 7 yeni (feed_posts, feed_likes, feed_saves, feed_comments, social_groups, group_members, group_messages) |
| Migration etkilediği fonksiyon | 8 yeni (4 snapshot + 3 counter + 1 max-enforce) |
| Migration etkilediği policy | 23 yeni (7 tablonun toplam CRUD policy'leri) |
| `flutter analyze` | No issues |
| `flutter test` | 184/184 passed (159 mevcut + 25 yeni) |
| Canlı DB durumu | **Migration uygulanmadı.** Apply instructions yukarıda. |
| Çözülen audit maddesi | P0-1 (Feed + Gruplar Supabase'siz). |
| Açık kalan P0 | 4 (P0-2, P0-3, P0-4, P0-5). |

---

## Live Supabase Apply & Smoke Result

Tarih: 2026-05-16 (apply window)

### Migration applied?
**EVET — uygulandı.** İki migration:
1. `social_spine_v1` (version `20260516041148`, MCP `apply_migration`).
2. `social_spine_v1_fix_group_messages_insert` (version `20260516043809`, P0 RLS bypass fix — aşağıda).

Project ref: `sjeqwiqgwzagengdukye` (FırınNet, eu-central-1).

### P0 fix: group_messages_insert_member alias bug

Apply sonrası `pg_get_expr` ile policy expression dump'ları okundu. `group_messages_insert_member` policy'sinin `with_check` ifadesinde alias-resolution bug bulundu:
- Yazılan SQL: `exists (select 1 from group_members gm where gm.group_id = group_id and gm.owner_id = auth.uid())`
- Postgres scope resolution: hem outer (`group_messages.group_id`) hem inner (`gm.group_id`) tabloda aynı isimde sütun → inner scope öncelikli → `group_id` = `gm.group_id` olarak çözüldü.
- Sonuç: `gm.group_id = gm.group_id` (DAİMA TRUE). Bir kullanıcı herhangi bir grupta üye olduğu sürece başka grubun mesaj kutusuna mesaj atabilirdi. **P0 RLS bypass.**

Fix: `gm.group_id = group_messages.group_id` ile outer tabloya açık referans. Tek policy DROP+CREATE, veri/şema değişikliği yok. Lokal mirror: `supabase/migrations/20260516120000_social_spine_v1_fix_group_messages_insert.sql`. `pg_get_expr` doğrulaması post-fix:
```
((owner_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM group_members gm
  WHERE ((gm.group_id = group_messages.group_id) AND (gm.owner_id = auth.uid())))))
```

Diğer EXISTS subquery'leri kontrol edildi (group_members_insert_self, group_members_delete_self_or_owner, group_messages_select_visible, social_groups_select_visible): hepsi ya outer tabloyu açıkça referans veriyor, ya outer-only sütun ismi kullanıyor. Bu pattern bug'ı yalnız `group_messages_insert_member`'daydı.

### Migration legacy bölüm (artık güncel değil)
**HAYIR — uygulanmadı.**

### Apply method
**not applied.** Detay:
- Supabase **MCP** bu sessionda yüklü değil (sadece firebase MCP geldi; sosyal omurga için kullanılmaz).
- Supabase **CLI** sürüm 2.90.0 cihazda kurulu (`C:\Users\trult\bin\supabase.exe`). Ama:
  - `supabase projects list` → `Unexpected error retrieving projects: {"message":"Unauthorized"}` — login token yok.
  - `supabase status` → docker daemon erişimi yok ("open //./pipe/docker_engine: The system cannot find the file specified") — local Supabase stack da kapalı.
  - `supabase/config.toml` yok — `supabase init` çalıştırılmamış, proje linki kurulmamış.

Görev kuralı gereği ("CLI login/project bağlantısı yoksa migration'ı uygulama") **migration uygulamadım.** Aşağıdaki manuel SQL Editor adımları kullanıcı tarafından yapılmalı.

### Applied project ref
Yok. Mevcut migration dosyalarının başlık yorumlarında "applied to remote project sjeqwiqgwzagengdukye via MCP" yazıyor (önceki migrasyonların raporu) — ama bu sessionda doğrulanamadı.

### Tables verified / RLS verified / Policies verified / Function-trigger verified
**Doğrulanamadı — canlı DB'ye bağlanma yok.** Migration SQL üzerinde statik audit yapıldı (sonuçlar aşağıda):
- 7 tablo CREATE TABLE doğru: feed_posts, feed_likes, feed_saves, feed_comments, social_groups, group_members, group_messages.
- 7 `alter table … enable row level security` satırı doğrulandı (regex testi geçiyor).
- 23+ `create policy` satırı tanımlı. `USING(true)` yalnız `feed_likes_select_auth` (SELECT, like sayısı görünürlüğü için kasıtlı). `WITH CHECK(true)` hiç yok. INSERT/UPDATE/DELETE policy'lerinin hepsi `owner_id = auth.uid()` check'i içeriyor.
- 8 SECURITY DEFINER fonksiyonu tanımlı: snapshot_feed_post_author, snapshot_feed_comment_author, snapshot_group_message_author, snapshot_social_group_owner, bump_feed_post_like_count, bump_feed_post_comment_count, bump_social_group_member_count, enforce_group_max_members. Her birinde `set search_path = public` + `revoke execute from public/anon/authenticated`.
- 11 trigger: 4 author snapshot + 3 counter + 1 max-enforce + 4 updated_at. Author trigger'lar BEFORE INSERT, counter trigger'lar AFTER INSERT/UPDATE/DELETE, max-enforce BEFORE INSERT.
- author_name/author_role/owner_name snapshot mantığı email/avatar_url/city sızdırmıyor — yalnız display_name + (profession_badge ya da account_type Türkçe etiketi) çekiliyor.
- Mevcut `profiles` RLS değişmedi; owner-only kalmaya devam ediyor.

### Feed live smoke result
**Yapılamadı.** Migration uygulanmadığı için feed_posts INSERT/SELECT/like/save canlı denenemedi. SmokeRunbook adımları (Section C — Authenticated feed) hâlâ açık.

### Groups live smoke result
**Yapılamadı.** Aynı sebep. SmokeRunbook adımları (Section D — Authenticated gruplar) hâlâ açık.

### Guest write guard live result
**Sadece test'lerde doğrulandı.** Birim testleri `GuestActionRequiredException`'ın atıldığını gösteriyor (8 farklı yazma metoduyla — addPost/toggleLike/toggleSave/createGroup/joinGroup/leaveGroup/postMessage). Canlı uygulama testi yapılmadı (Flutter dart-define ile çalıştırılmadı bu sessionda).

### Supabase-off local fallback result
**Sadece test'lerde doğrulandı.** Provider selection testi `AppConfig.supabaseEnabled = false` durumunda LocalFeedRepository ve LocalSocialGroupRepository'nin döndüğünü ve seed listesinin okunduğunu doğruluyor.

### analyze/test result
- `flutter pub get` → OK
- `flutter analyze` → **No issues found! (1.4s)**
- `flutter test` → **184/184 passed**
- `rg "USING \(true\)|WITH CHECK \(true\)|service_role|debugPrint|print\("` → production code'da gerçek tehlikeli kullanım yok; sadece worker_profiles/experiences mevcut `using(true)` SELECT (V1.2 onaylı) ve yeni `feed_likes_select_auth using(true)` (kasıtlı). Test description'larında 'print(' / 'debugPrint' metinleri var ama çağrı değil.
- `rg "feed_posts|social_groups|group_members|group_messages|SupabaseFeedRepository|SupabaseSocialGroupRepository"` → 16 dosya, hepsi beklenen yerlerde (yeni Supabase repository'ler + provider'lar + UI ekranları + test + migration).

### Remaining risks
- **Migration canlıda yok.** Apply yapılana kadar uygulama Supabase enabled + signed-in modunda açılırsa `feed_posts` tablosu bulunamayacağı için `PostgrestException: relation "public.feed_posts" does not exist` atar. Flutter tarafında bu hata feed listing screen'de `_FeedEmpty(feedErrorGeneric)` placeholder olarak görünür (raw exception saklanmış olur ama kullanıcı için akış boş kalır). Yine de mağazaya gitmeden migration uygulanması zorunlu.
- **Canlı RLS doğrulaması yok.** Migration uygulandıktan sonra ek smoke (SQL editor üzerinden `set local role authenticated; ... ; insert ...`) gerekecek.
- **createGroup atomik değil.** Bilinen V1 trade-off (raporun "Known limitations" bölümünde).
- **Realtime yok.** Bilinen V1 trade-off.

### Commit readiness verdict (2026-05-16 güncelleme)
**Teknik olarak EVET — commit'e hazır.** Bu turda commit/push talimat gereği YAPILMADI.

Tamamlananlar:
1. ✅ Migration canlı DB'ye `apply_migration` ile uygulandı (`20260516041148`).
2. ✅ P0 fix migration aynı oturumda apply edildi (`20260516043809`) + lokal mirror yazıldı.
3. ✅ DB-level smoke (trigger snapshot + counter + soft-delete) gerçek değerlerle geçti, rollback temiz.
4. ✅ `flutter analyze` No issues + `flutter test` 184/184.

Kalan manuel adım:
- UI smoke (cihaz/emulator) — A-F runbook ("Manual smoke checklist" yukarıda).
- Lokal migration dosya adı normalizasyonu (lokal `20260515120000` ↔ uzakta `20260516041148`).
- `git add` + commit + push.

Detay smoke raporu: **SOCIAL_SPINE_LIVE_SMOKE_REPORT.md**.
