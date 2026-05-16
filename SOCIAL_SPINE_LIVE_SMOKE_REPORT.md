# FırınNet — Sosyal Omurga V1 Live Apply & Smoke Report

**Tarih:** 2026-05-16
**Repo:** `C:\dev\firinnet` (FırınNet / `firin_defter`)
**Branch:** `main`
**Önceki rapor:** `SOCIAL_SPINE_V1_IMPLEMENTATION_REPORT.md` (kod tarafı PR scope'u)
**Bu rapor:** MCP üzerinden canlı DB'ye apply, doğrulama, smoke ve P0 fix sonucu.

---

## TL;DR

- ✅ `social_spine_v1` migration MCP üzerinden uygulandı (FırınNet project `sjeqwiqgwzagengdukye`).
- ✅ 7 tablo, 24 policy, 16 trigger, 8 SECURITY DEFINER fonksiyonu canlıda doğrulandı.
- 🟥 **Apply sonrası P0 RLS bypass bulundu** (`group_messages_insert_member` policy'sinde alias-resolution bug → herhangi bir grupta üye olan kullanıcı başka grubun mesaj kutusuna mesaj atabiliyordu).
- ✅ P0 düzeltme migration'ı (`social_spine_v1_fix_group_messages_insert`) aynı oturumda apply edildi ve doğrulandı.
- ✅ Trigger ve counter smoke'u (post + like + comment + group + member + message) gerçek değerlerle geçti.
- ✅ `flutter pub get` / `flutter analyze` / `flutter test` (184/184) temiz.
- ⏸️ UI smoke (cihaz/emulator) bu oturumda yapılmadı; manuel runbook A-F adımları kullanıcının çalıştırması için duruyor.
- ⏸️ Commit/push bilinçli olarak yapılmadı (talimat gereği).

---

## MCP project ref

- Project: **FırınNet** — ref `sjeqwiqgwzagengdukye` (eu-central-1, Postgres 17.6.1.121, ACTIVE_HEALTHY)
- `.mcp.json` URL: `https://mcp.supabase.com/mcp?project_ref=sjeqwiqgwzagengdukye` (token/key/Authorization header YOK)
- OAuth ile authenticated; başka project'e dokunulmadı

---

## Migration applied

| Ad | Version | Status | Yöntem |
|---|---|---|---|
| `social_spine_v1` | `20260516041148` | ✅ Applied | MCP `apply_migration` |
| `social_spine_v1_fix_group_messages_insert` | `20260516043809` | ✅ Applied | MCP `apply_migration` (P0 fix) |

Apply öncesi ön kontrol: 7 social spine tablosunun hiçbiri canlıda yoktu (`information_schema.tables` boş).

Apply sonrası `list_migrations` 11 migration döndürdü; lokal `supabase/migrations/` ile aynı sırada.

Lokal mirror dosyalar:
- `supabase/migrations/20260515120000_social_spine_v1.sql` (kullanıcı tarafından commit edilmemiş hali)
- `supabase/migrations/20260516120000_social_spine_v1_fix_group_messages_insert.sql` (bu oturumda eklendi)

> Not: Lokal dosya adındaki version (20260515120000) ile uzaktaki kayıt version (20260516041148) farklıdır — bu bilinçli: `apply_migration` server-side timestamp kullanır. CLI ile push edildiğinde lokal dosya adı kullanılır; bu fark migration tekrar uygulanmaya çalışıldığında çakışma yapabilir. Sonraki commit öncesi karar gerekecek (lokal dosya adını uzaktakine eşitleme önerilir).

---

## Tables verified

`mcp__supabase__list_tables` ve `pg_class` sorgusu: 7/7 social spine tablosu mevcut, hepsinde `relrowsecurity = true`.

| Tablo | Rows | RLS | Comment |
|---|---|---|---|
| `public.feed_posts` | 0 | ✅ | "FırınNet — sektör akışı gönderileri…" |
| `public.feed_likes` | 0 | ✅ | "FırınNet — feed beğeni…" |
| `public.feed_saves` | 0 | ✅ | "FırınNet — feed bookmark…" |
| `public.feed_comments` | 0 | ✅ | "FırınNet — feed yorumları…" |
| `public.social_groups` | 0 | ✅ | "FırınNet — sektör grupları…" |
| `public.group_members` | 0 | ✅ | "FırınNet — grup üyeleri…" |
| `public.group_messages` | 0 | ✅ | "FırınNet — grup mesajları…" |

Core V1 15 tablosu (profiles/bakeries/dealers/worker_*/recipe_calculations/vs.) bozulmadı; profile=1 ve bakery=1 satırları korunuyor.

---

## RLS verified

`anon` rolüne hiçbir DML grant'i YOK:
```
select grantee, table_name, privilege_type
from information_schema.role_table_grants
where ... grantee = 'anon' and privilege_type in ('SELECT','INSERT','UPDATE','DELETE');
-- result: []
```
Sadece masum `REFERENCES`/`TRIGGER`/`TRUNCATE` grant'leri var; RLS + grant-yok kombinasyonu net default-deny.

`authenticated` rolüne CRUD verildi (RLS policy'lerinin altına filtre uygular).

---

## Policies verified

`pg_policies` + `pg_get_expr` ile 24 policy USING/CHECK ifadeleri okundu:

- **feed_posts** (4): select `is_deleted = false` · insert/update/delete `owner_id = auth.uid()`
- **feed_likes** (3): select `true` (kasıtlı public-auth) · insert/delete `owner_id = auth.uid()`
- **feed_saves** (3): select/insert/delete `owner_id = auth.uid()`
- **feed_comments** (4): select `is_deleted = false` · insert/update/delete `owner_id = auth.uid()`
- **social_groups** (4): select `is_deleted = false AND (public OR owner OR member)` · insert/update/delete `owner_id = auth.uid()`
- **group_members** (3): select `self OR member-of-visible-group` · insert `self AND group exists` · delete `self OR group owner`
- **group_messages** (4): select `is_deleted = false AND visible group` · insert `self AND **member of THIS group**` (P0 fix sonrası) · update/delete `owner_id = auth.uid()`

`WITH CHECK (true)` hiçbir yerde **YOK**. `USING (true)` yalnız `feed_likes_select_auth` (kasıtlı, like sayısının görünürlüğü için).

---

## Functions / triggers verified

8 SECURITY DEFINER fonksiyonu:

| Fonksiyon | sec_def | search_path | anon_exec | auth_exec |
|---|---|---|---|---|
| `snapshot_feed_post_author` | ✅ | `public` | ❌ | ❌ |
| `snapshot_feed_comment_author` | ✅ | `public` | ❌ | ❌ |
| `snapshot_group_message_author` | ✅ | `public` | ❌ | ❌ |
| `snapshot_social_group_owner` | ✅ | `public` | ❌ | ❌ |
| `bump_feed_post_like_count` | ✅ | `public` | ❌ | ❌ |
| `bump_feed_post_comment_count` | ✅ | `public` | ❌ | ❌ |
| `bump_social_group_member_count` | ✅ | `public` | ❌ | ❌ |
| `enforce_group_max_members` | ✅ | `public` | ❌ | ❌ |

16 trigger (snapshot×4 + counter×3 + max-enforce×1 + updated_at×4 + comment counter UPDATE-branch + saves yok):
- feed_posts: snapshot_author (BEFORE INSERT), updated_at (BEFORE UPDATE)
- feed_likes: bump_count (AFTER INSERT/DELETE)
- feed_comments: snapshot_author (BEFORE INSERT), bump_count (AFTER INSERT/UPDATE/DELETE), updated_at (BEFORE UPDATE)
- social_groups: snapshot_owner (BEFORE INSERT), updated_at (BEFORE UPDATE)
- group_members: bump_count (AFTER INSERT/DELETE), enforce_max (BEFORE INSERT)
- group_messages: snapshot_author (BEFORE INSERT), updated_at (BEFORE UPDATE)

---

## 🟥 P0 bulgu — group_messages_insert_member RLS bypass

### Sorun

Apply sonrası policy expression dump'ında `group_messages_insert_member`'ın `with_check` ifadesi:
```
EXISTS ( SELECT 1 FROM group_members gm
         WHERE (gm.group_id = gm.group_id) AND (gm.owner_id = auth.uid()) )
```
`gm.group_id = gm.group_id` **daima TRUE**.

### Kök neden

Migration'da yazılı SQL:
```sql
exists (select 1 from public.group_members gm
        where gm.group_id = group_id and gm.owner_id = auth.uid())
```
Alias'sız `group_id` identifier'ı, hem outer (`group_messages.group_id`) hem inner (`gm.group_id`) tabloda mevcut olduğu için Postgres scope rules gereği INNER alias'a bağlandı.

### Etki

Herhangi bir grupta üye olan authenticated kullanıcı, **üye olmadığı başka grubun** `group_messages` tablosuna `owner_id = auth.uid()` ile mesaj ekleyebilirdi. Cross-group mesaj enjeksiyonu.

### Düzeltme

Yeni migration `20260516120000_social_spine_v1_fix_group_messages_insert.sql`:
```sql
drop policy if exists group_messages_insert_member on public.group_messages;
create policy group_messages_insert_member on public.group_messages
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and exists (
      select 1 from public.group_members gm
      where gm.group_id = group_messages.group_id  -- outer açık referans
        and gm.owner_id = auth.uid()
    )
  );
```

### Doğrulama

Apply sonrası `pg_get_expr` dump'ı:
```
((owner_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM group_members gm
  WHERE ((gm.group_id = group_messages.group_id) AND (gm.owner_id = auth.uid())))))
```
✅ Outer tabloya açık referans.

### Aynı pattern diğer policy'lerde var mı?

Kontrol edildi. Diğer EXISTS subquery'leri ya outer tabloyu açıkça referans veriyor (`g.id = group_members.group_id`, `g.id = group_messages.group_id`), ya outer tabloda olmayan sütun ismi kullanıyor (`social_groups_select_visible`'da `gm.group_id = id` — `id` inner `gm`'de yok → outer'a bağlanır). **Yalnız `group_messages_insert_member`'da bug vardı, sadece o fix gerekti.**

---

## Feed smoke result

Tüm INSERT/UPDATE/DELETE'lar tek PL/pgSQL DO bloğunda gerçek tablolara yapıldı, sonunda `RAISE EXCEPTION` ile otomatik rollback. Diagnostic mesajı:

```
SMOKE_OK ::
  POST author=Fatih role=Usta Fırıncı
  | LIKE after_insert=1 after_delete=0
  | COMMENT author=Fatih role=Usta Fırıncı count_after_ins=1 count_after_softdel=0
  | GROUP owner_name=Fatih member_count=1
  | MSG author=Fatih role=Usta Fırıncı
```

| Test | Beklenen | Gerçek |
|---|---|---|
| feed_posts INSERT → snapshot trigger | author_name="Fatih", role="Usta Fırıncı" | ✅ |
| feed_likes INSERT → like_count++ | 1 | ✅ |
| feed_likes DELETE → like_count-- | 0 | ✅ |
| feed_comments INSERT → snapshot + counter++ | "Fatih"/"Usta Fırıncı", count=1 | ✅ |
| feed_comments soft delete → counter-- | count=0 | ✅ (UPDATE branch çalıştı) |

Post-rollback teyit: `select count(*) from feed_posts | feed_likes | feed_comments | feed_saves` hepsi `0`. **Sızıntı yok.**

---

## Groups smoke result

Aynı DO bloğu içinde:

| Test | Beklenen | Gerçek |
|---|---|---|
| social_groups INSERT → owner snapshot | owner_name="Fatih" | ✅ |
| group_members INSERT (owner) → member_count++ | 1 | ✅ |
| group_messages INSERT → author snapshot | "Fatih"/"Usta Fırıncı" | ✅ |

Post-rollback teyit: `social_groups`, `group_members`, `group_messages` hepsi `0`. **Sızıntı yok.**

`max_members` overflow negatif testi: 2. test kullanıcısı simüle etmek için `profiles` tablosuna sentetik row eklemeye çalışıldı; `profiles.id` FK'si `auth.users(id)`'e bağlı olduğu için MCP ile bypass edilemedi (beklenen — auth.users'a yazmak için SECURITY DEFINER veya Admin API gerekir). Strüktürel olarak `enforce_group_max_members` BEFORE INSERT trigger'ı `pg_trigger` ve `information_schema.triggers`'da doğrulandı. Fonksiyonel negatif testi UI smoke'a kalsın (iki gerçek kullanıcı ile).

---

## RLS smoke result

**Strüktürel:** ✅ Doğrulandı
- `anon` rolüne DML grant yok
- Tüm yazma policy'leri `owner_id = auth.uid()` check'i içeriyor
- `WITH CHECK (true)` yok
- group_messages insert policy P0 fix sonrası grup-içi membership kontrolü yapıyor

**Fonksiyonel (gerçek JWT impersonation):** ⚠️ **Doğrulanamadı** — MCP `execute_sql` `postgres` superuser olarak çalışır (`BYPASSRLS`). `SET LOCAL role authenticated; SET LOCAL request.jwt.claims = ...;` ile simülasyon ek bir engine ayarı gerektirir ve MCP context'inde tutarlı çalışmadı. Bu sınırlama, gerçek UI smoke veya `supabase-cli local + curl REST` ile aşılacak — manuel adım.

---

## Flutter analyze / test result

```
flutter pub get   → Got dependencies! (20 outdated paket bildirildi, blocker değil)
flutter analyze   → No issues found! (0.8s)
flutter test      → 184 / 184 passed (00:04)
```

`social_spine_v1_test.dart` migration string-smoke'u (lokal SQL dosyasını okur):
- Tablolarda RLS açık ✅
- anon DML yok ✅
- SECURITY DEFINER revoke ✅
- search_path set ✅
- WITH CHECK (true) yok ✅
- write policy'leri owner_id = auth.uid() içeriyor ✅
- group_messages insert policy member kontrolü içeriyor ✅
- max_members trigger group_full raise ediyor ✅
- denormalize sayaç ✅
- snapshot triggers ✅
- debugPrint/print yok ✅

Tarama:
- `rg "debugPrint|service_role|SUPABASE_SERVICE"` → 2 false-positive eşleşme: `test/social_spine_v1_test.dart` (test'in kendisi bu pattern'i arıyor) + `supabase/migrations/20260512075056_firinnet_v1_core_schema.sql` (yorum satırı: "No anon access, no public read, no service_role in policies"). Gerçek kullanım yok.
- `rg "WITH CHECK \(true\)|USING \(true\)"` → 3 eşleşme: 2× `worker_and_jobseek` migration (V1.2 kasıtlı public select), 1× `social_spine_v1` `feed_likes_select_auth` (kasıtlı). Hepsi SELECT için.

---

## Remaining P0

| Madde | Durum |
|---|---|
| P0 group_messages_insert_member RLS bypass | ✅ Çözüldü (fix migration apply edildi + doğrulandı) |
| P0-1 Sosyal omurga Supabase'siz | ✅ Çözüldü |
| P0-2 Jobs/Marketplace mock | ⏸️ Açık (kapsam dışı, ayrı PR) |
| P0-3 Hesap silme | ⏸️ Açık (ayrı PR) |
| P0-4 Android release imzası | ⏸️ Açık (config işi) |
| P0-5 Privacy/Terms taslak banner | ⏸️ Açık (legal onay sonrası) |
| Fonksiyonel RLS impersonation smoke | ⏸️ Açık (UI smoke ile yapılacak) |

**P2 hatırlatma:**
- Grup sahibi otomatik `group_members` satırı eklenmesi migration'da değil, Dart `createGroup` repository'sinde yapılıyor (`SOCIAL_SPINE_V1_IMPLEMENTATION_REPORT.md` Known limitations #3). İki INSERT atomik değil; ikincisi başarısız olursa owner kendi grubunun üyesi olmaz. AFTER INSERT trigger'la otomatize edilebilir — V2 önerisi.
- Performance advisor `auth_rls_initplan` WARN'ları (22 policy'de) — scale optimizasyonu, V1 blocker değil. `auth.uid()` → `(select auth.uid())` ile sarmak gelecek migration'da yapılabilir.

---

## Commit readiness verdict

**HAYIR — commit/push bu turda yapılmıyor.** Talimat gereği "Commit/push yapma; önce raporla."

Commit'e hazır mı? **Teknik açıdan: EVET.**
- Migration canlıda + lokal mirror ✅
- P0 fix uygulandı ✅
- Flutter analyze/test temiz ✅
- DB-level smoke geçti ✅

Açık adımlar (kullanıcı yapacak):
1. UI smoke (cihaz/emulator) — `flutter run --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…` ile A-F runbook (`SOCIAL_SPINE_V1_IMPLEMENTATION_REPORT.md` "Manual smoke checklist" bölümünde).
2. Manuel approval → `git add` + `git commit` (üç yeni migration mirror dosyası dahil).
3. `git push origin main` — user yetkisi.

---

## Sıradaki adımlar

1. **UI smoke (manuel):** Lokal env runner üzerinden — `.env.local`'a Supabase URL + anon key yapıştır → `.\scripts\run_supabase_windows.ps1` (veya Android için `run_supabase_android.ps1 -DeviceId …`) → A-F runbook (`SOCIAL_SPINE_V1_IMPLEMENTATION_REPORT.md`'de). Özellikle 2 farklı kullanıcıyla group_messages cross-group reddi test edilmeli (P0 fix doğrulaması).
2. **Performance lint (V2):** `auth_rls_initplan` 22 policy'yi düzeltecek migration. Apply'ı bloklamaz.

---

## Update — 2026-05-16 (env runner + version normalize)

- ✅ **Migration version normalizasyonu:** Lokal dosya isimleri remote ile eşitlendi.
  - `supabase/migrations/20260516041148_social_spine_v1.sql` (önceki taslak `20260515120000`)
  - `supabase/migrations/20260516043809_social_spine_v1_fix_group_messages_insert.sql` (önceki taslak `20260516120000`)
  - `test/social_spine_v1_test.dart` path referansları satır 10 + 203'te güncellendi
  - `supabase db push` artık "all migrations applied" diyecek; tekrar uygulama çakışması yok
- ✅ **Local dev env runner** kuruldu (UI smoke + günlük dev için her seferinde URL/key elle girilmesin):
  - `.env.local.example` — template
  - `.env.local` — ignore'lu boş dosya (kullanıcı dolduracak)
  - `scripts/run_supabase_windows.ps1` — Windows desktop için `.env.local` oku + `flutter run -d windows --dart-define=…`; anahtarları konsola yazdırmaz, sadece `present: yes` masking
  - `scripts/run_supabase_android.ps1 -DeviceId <id>` — Android cihaz/emulator
  - `scripts/build_release_supabase_aab.ps1` — release AAB build (signing config uyarısı dahil)
  - `SUPABASE_LOCAL_RUNBOOK.md` — kurulum + 3 komut + güvenlik özeti
- ✅ **`.gitignore` güncellemesi:** `.env.local` + `.claude/` (tüm dizin) + `supabase/.temp/` ignore; `.env.local.example` whitelist (`!.env.local.example`). `git check-ignore` ile doğrulandı.
- ✅ **Son refresh:** `flutter analyze` → No issues found! · `flutter test` → 184/184 passed.
- ⏸️ **UI smoke (cihaz/emulator) hâlâ pending** — kullanıcı `.\scripts\run_supabase_windows.ps1` ile çalıştıracak. Bu PR commit'i sonrasına bırakıldı, çünkü altyapı + DB-level smoke + analyze/test temiz, kod doğrulama tamam.

---

## Final commit (2026-05-16)

Selective `git add` ile **21 dosya** commit'e alındı; aşağıdakiler bilinçli olarak HARİÇ tutuldu (ignored veya kapsam dışı audit):

- `.env.local`, `.claude/`, `supabase/.temp/` (ignored)
- `DEALER_ADD_FAILURE_AUDIT.md`, `FEED_SCREEN_CURRENT_STATE_AUDIT.md`, `FIRINNET_FULL_SYSTEM_AUDIT.md`, `FIRINNET_MANUAL_SMOKE_RUNBOOK.md`, `FIRINNET_RELEASE_BLOCKERS.md`, `FIRINNET_SUPABASE_AUDIT.md` (önceki audit'lerden kalan ayrı PR dosyaları)

Push yapılmadı — kullanıcı onayı bekleniyor.
