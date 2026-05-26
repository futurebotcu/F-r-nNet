# Supabase MCP Connection Report — FırınNet

**Tarih:** 2026-05-16
**Repo:** `C:\dev\firinnet` (firin_defter / FırınNet)
**Branch:** `main` (origin/main ile aynı seviyede; lokal değişiklikler commit'lenmedi)

## 1. Repo verified

- `pubspec.yaml` → `name: firin_defter`, `description: "FırınNet - Fırıncılar için local-first defter uygulaması."`
- Yol: `C:\dev\firinnet` (memory'deki [[project_firinnet_paths]] ile tutarlı)
- ✅ FırınNet repo'su; başka proje değil

## 2. MCP server configured

- Config dosyası: `C:\dev\firinnet\.mcp.json` (project-scoped, repo içinde)
- Server URL: `https://mcp.supabase.com/mcp?project_ref=sjeqwiqgwzagengdukye`
- Transport: HTTP
- Secret / token / Authorization header: **YOK** — sadece public project_ref query param
- Bağlantı modeli: OAuth (Supabase hesabıyla browser onayı; access token MCP runtime tarafında tutulur, repo'ya/.env'e/Flutter'a/markdown'a yazılmaz — [[feedback_supabase_token_isolation]] kuralına uygun)

## 3. Auth status

- ✅ OAuth flow tamamlandı (browser onayı verildi)
- ✅ `list_organizations`, `list_projects`, `get_project`, `list_tables` çağrıları başarıyla döndü
- Not: `claude mcp list` health-check çıktısı URL'ye `?project_ref=` eklendikten sonra "Needs authentication" gösterdi; gerçek MCP API çağrıları auth'lu çalıştığı için bu kozmetik bir health-check farkı, fonksiyonel bir blocker değil

## 4. Project ref

- **FırınNet ref:** `sjeqwiqgwzagengdukye`
- Name: `FırınNet`
- Organization: `futurebotcu's Org` (slug: `njeolfmhlazqqhfjwbps`)
- Region: `eu-central-1`
- Status: `ACTIVE_HEALTHY`
- Postgres: `17.6.1.121` (engine 17, GA channel)
- Created: 2026-05-12

### Dokunulmayacak diğer projeler (yanlış hedefe karşı kilit)

| Name | Ref | Region | Status |
|---|---|---|---|
| ustaskorla | `vvawcuvwwcqsflkojggp` | eu-west-1 | ACTIVE_HEALTHY |
| noblara | `xgkkslbeuydbbcvlhsli` | ap-northeast-1 | ACTIVE_HEALTHY |
| futurebotcu's Project | `lzhaccimqkocakcietiv` | ap-northeast-2 | INACTIVE |
| motorum | `czejmspupmntliyxiluq` | eu-central-1 | ACTIVE_HEALTHY |

`.mcp.json` `?project_ref=sjeqwiqgwzagengdukye` ile kilitlendi → MCP çağrıları yalnız FırınNet'i hedefler.

## 5. Project scoped?

- ✅ Evet. `.mcp.json` URL'sinde `project_ref=sjeqwiqgwzagengdukye` parametresi mevcut.
- Token/key/Authorization header **eklenmedi**.

## 6. Schema readable?

- ✅ `public` schema okunuyor. 15 tablo tespit edildi:

| Tablo | RLS | Rows | Not |
|---|---|---|---|
| `public.profiles` | ✅ | 1 | V1 user profile (id = auth.users.id) |
| `public.bakeries` | ✅ | 1 | Fırın işletme kaydı (owner_id = auth.uid()) |
| `public.bakery_products` | ✅ | 0 | Ürün listesi |
| `public.recipe_calculations` | ✅ | 0 | Reçete hesaplama (trigger-doldurulur) |
| `public.waste_entries` | ✅ | 1 | Fire/iade kaydı (estimated_loss trigger) |
| `public.production_entries` | ✅ | 0 | Günlük üretim |
| `public.dealers` | ✅ | 0 | Bayi/market/bakkal |
| `public.dealer_deliveries` | ✅ | 0 | Teslimat üst kaydı |
| `public.dealer_delivery_items` | ✅ | 0 | Teslimat kalemleri |
| `public.dealer_transactions` | ✅ | 0 | (V1.2 alanı?) |
| `public.dealer_prices` | ✅ | 0 | (V1.2 alanı?) |
| `public.dealer_notes` | ✅ | 0 | (V1.2 alanı?) |
| `public.worker_profiles` | ✅ | 0 | İş arayan profili |
| `public.worker_experiences` | ✅ | 0 | İş tecrübeleri |
| `public.job_seek_posts` | ✅ | 0 | İş ilanları |

- ✅ Tüm tablolarda RLS aktif (read-only `list_tables` ile teyit edildi)
- SQL çalıştırılmadı, migration uygulanmadı

## 7. Ready for migration audit?

- ✅ Evet. Read-only MCP yolu (`list_tables` verbose, `list_migrations`, `list_extensions`, `get_advisors`, `get_logs`) açık.
- Sıradaki adım: V1 core schema + V1.1 reçete + lokal `supabase/migrations/20260515120000_social_spine_v1.sql` ile remote durumun karşılaştırılması.

## 8. Missing steps

- (yok — bağlantı kurma kapsamında tüm adımlar tamam)
- Bilgi: `claude mcp list` health-check görüntüsü URL'de query param olunca "Needs authentication" gösteriyor; isteğe bağlı kozmetik düzeltme istenirse incelenebilir, fonksiyonel etkisi yok.

## Özet

| Madde | Durum |
|---|---|
| MCP auth | ✅ Tamam |
| FırınNet project_ref | ✅ `sjeqwiqgwzagengdukye` |
| `.mcp.json` project_ref kilidi | ✅ Kilitlendi |
| Migration audit'e hazır | ✅ Hazır |

---

## Update — 2026-05-16 (post-migration)

Bu bağlantı üzerinden aşağıdaki işler yapıldı:

- ✅ `social_spine_v1` migration (`20260516041148`) MCP `apply_migration` ile uygulandı (7 yeni public tablo: feed_posts/likes/saves/comments + social_groups + group_members/messages).
- 🟥 Apply sonrası `group_messages_insert_member` policy'sinde **P0 RLS bypass** tespit edildi (`gm.group_id = gm.group_id` daima TRUE — alias resolution bug).
- ✅ Düzeltme migration `social_spine_v1_fix_group_messages_insert` (`20260516043809`) apply edildi ve `pg_get_expr` ile doğrulandı.
- ✅ DB-level smoke (PL/pgSQL DO + RAISE EXCEPTION ile rollback) — snapshot trigger, like/comment/member counter, soft-delete UPDATE branch hepsi gerçek değerlerle geçti.
- ✅ `mcp__supabase__get_advisors` security: yalnız önceden bilinen 2 WARN (proje dışı `rls_auto_enable` + `auth_leaked_password_protection`); yeni P0/P1 yok.
- ✅ `flutter pub get` + `flutter analyze` (No issues) + `flutter test` (184/184).

Detay: [`SOCIAL_SPINE_LIVE_SMOKE_REPORT.md`](./SOCIAL_SPINE_LIVE_SMOKE_REPORT.md)

Public schema'da toplam **22 tablo** (15 core V1 + 7 social spine), hepsinde RLS açık. Core 15'in veri sayıları korunuyor.
