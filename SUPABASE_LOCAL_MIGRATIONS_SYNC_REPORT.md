# Supabase Local Migrations Sync — Rapor

Tarih: 2026-05-12
Amaç: Remote'a uygulanmış 3 migration'ı local repo'ya kaynak-kontrol kopyası olarak indirmek. Remote DB'ye **dokunmamak**.

---

## 1. Oluşturulan Dosyalar

`C:\dev\firinnet\supabase\` klasörü ve altındaki `migrations\` alt klasörü oluşturuldu (önceden yoktu).

| Dosya | Boyut | İçerik |
|---|---|---|
| `supabase/migrations/20260512075056_firinnet_v1_core_schema.sql` | 21.981 B | 9 tablo, 7 fonksiyon, 10 trigger, 36 RLS policy, 27 ikincil index, `pgcrypto` ensure |
| `supabase/migrations/20260512075421_firinnet_v1_grants_authenticated.sql` | 1.035 B | `usage on schema public` ve V1 tablolarında authenticated CRUD grant + `alter default privileges` |
| `supabase/migrations/20260512075525_firinnet_v1_revoke_trigger_fn_execute.sql` | 1.075 B | Trigger function ve totals helper'a `revoke all execute` (public/anon/authenticated) |

Her dosyanın başına aşağıdaki başlık koyuldu:
- migration adı + versiyonu
- "applied to remote project sjeqwiqgwzagengdukye via MCP apply_migration on 2026-05-12"
- "DO NOT re-apply to remote; remote already records this version."

## 2. Remote Migration History Eşleşmesi

`mcp__supabase__list_migrations` çıktısı (rapor anı):

```
20260512075056 - firinnet_v1_core_schema
20260512075421 - firinnet_v1_grants_authenticated
20260512075525 - firinnet_v1_revoke_trigger_fn_execute
```

Local dosya adları:

```
20260512075056_firinnet_v1_core_schema.sql
20260512075421_firinnet_v1_grants_authenticated.sql
20260512075525_firinnet_v1_revoke_trigger_fn_execute.sql
```

Eşleşme: **3/3 birebir** (`version_name` formatı Supabase CLI standardıyla uyumlu — ileride `supabase db pull/push` ya da `supabase migration list` ile düz kullanılabilir).

## 3. Local Dosyalar Remote'a Yeniden Uygulanmadı

Bu sync turunda **hiçbir DDL/DML remote'a gönderilmedi.** Sadece şu tool'lar kullanıldı:

- `Write` (yalnız local dosya oluşturma)
- `Bash` (`ls` ile dosya listesi)
- `mcp__supabase__list_migrations` (read-only, history doğrulaması)
- `Grep` (yapısal yerel kontrol)

`mcp__supabase__apply_migration` veya `execute_sql` çağrılmadı. Remote schema state'inde değişiklik **yok** (önceki rapordaki son durum geçerli).

> Not: Bu dosyalar yeni boş bir Supabase projesinde sırayla çalıştırılırsa aynı schema'yı kuracak şekilde yazıldı (idempotent değil — `create table` reset edilmiş DB varsayar). Mevcut remote'a tekrar uygulanırsa duplicate-object hataları döner — bu beklenen davranış, koruma katmanıdır.

## 4. Yapısal Kontrol (Yerel)

`20260512075056_firinnet_v1_core_schema.sql` üzerinde örüntü sayımları:

| Yapı | Beklenen | Bulunan |
|---|---|---|
| `create table` | 9 | **9** ✓ |
| `enable row level security` | 9 | **9** ✓ |
| `create policy` | 36 (9 × 4) | **36** ✓ |
| `create index` (ikincil) | 27 | **27** ✓ |
| `create trigger` | 10 | **10** ✓ |
| `$$` fonksiyon kapanış işareti | 7 | **7** ✓ |

> Önceki `SUPABASE_SCHEMA_V1_REPORT.md` raporunda "25 ikincil indeks" yazılmıştı — doğru sayı **27**'dir (3+3+2+4+4+4+3+4=27). Sync sırasında remote'tan tekrar sayılarak düzeltildi; remote'taki gerçek değer de 27.

`20260512075421_firinnet_v1_grants_authenticated.sql` ve `20260512075525_firinnet_v1_revoke_trigger_fn_execute.sql` küçük, satır satır karşılaştırma ile remote uygulanan SQL'in birebir kopyası.

## 5. Güvenlik Notları

- ⛔ Hiçbir dosyada token, service_role key, anon key, publishable key, JWT secret veya database password yok.
- ⛔ `C:\Users\trult\.claude.json`'daki MCP env değişkenlerine dokunulmadı.
- ⛔ `.env`, `flutter` config, `lib/` altına hiçbir secret yazılmadı.
- ⛔ `git push`, `git commit` çağrılmadı. Dosyalar yalnız diskte.
- ⛔ Remote DB'ye DDL/DML gönderilmedi (yalnız read: `list_migrations`).
- ✓ Migration başlıkları "DO NOT re-apply to remote" uyarısı içeriyor.
- ✓ Dosya adları Supabase CLI'nin `<timestamp>_<name>.sql` örüntüsüyle uyumlu, böylece ileride `supabase migration repair` ile history `applied` olarak işaretlenebilir.

## 6. Bilinen Sınırlamalar

- Yerel `supabase/config.toml` **oluşturulmadı** (kullanıcı talep etmedi). `supabase init` yapmadan local stack çalıştırılamaz. İhtiyaç olursa ayrı turda eklenir.
- `supabase` CLI bu makinede çalıştırılmadı; gerçek `supabase db diff` ya da `pgtap` testi yapılmadı. Yapısal kontrol grep tabanlı.
- Auth user tarafına otomatik profil oluşturan `handle_new_user` triggerı **hâlâ yok** — Flutter signup'tan önce yeni bir migration olarak eklenmeli (sıradaki adım).

## 7. Sonraki Adım

1. **Supabase CLI'yi bağla (opsiyonel ama önerilir):**
   - `supabase init` (yalnız `config.toml` oluşturur, migrationlara dokunmaz)
   - `supabase link --project-ref sjeqwiqgwzagengdukye` (token interaktif veya env'den; **anahtar dosyaya gömülmez**)
   - `supabase migration list` — local 3 dosyanın remote'da `applied` göründüğünü kontrol et
   - Gerekirse `supabase migration repair --status applied 20260512075056 20260512075421 20260512075525` (sadece state işaretler, DDL çalıştırmaz)

2. **Yeni migration eklemek için:**
   - `supabase migration new <ad>` ya da elle `YYYYMMDDHHMMSS_<ad>.sql` dosyası oluştur
   - Önce `mcp__supabase__apply_migration` ile remote'a uygula (mevcut akış)
   - Aynı içeriği `supabase/migrations/` altına bu kuralla yansıt (sync devam ettirilir)

3. **Sıradaki migration önerisi:** `handle_new_user` triggerı — `auth.users` insertinden `public.profiles` satırı oluşturur. Bu olmadan Flutter signup → profile oluşmaz.

4. **Flutter bağlama:** Ayrı PR. `supabase_flutter` paketi + yalnız publishable key.

---

## EK: Dosya konumları

```
C:\dev\firinnet\
├── supabase\
│   └── migrations\
│       ├── 20260512075056_firinnet_v1_core_schema.sql
│       ├── 20260512075421_firinnet_v1_grants_authenticated.sql
│       └── 20260512075525_firinnet_v1_revoke_trigger_fn_execute.sql
├── SUPABASE_SCHEMA_V1_REPORT.md
└── SUPABASE_LOCAL_MIGRATIONS_SYNC_REPORT.md   ← bu dosya
```
