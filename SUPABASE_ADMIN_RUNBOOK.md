# FırınNet — Supabase Admin (service_role) Local Runbook

> ⚠️ **service_role** anahtarı Supabase'in tüm RLS ve auth politikalarını bypass eder. Mobile app'e ya da paylaşılan ortama ASLA verilmez. Bu runbook yalnız tek-makineli local admin işleri içindir (kullanıcı silme, auth user oluşturma, storage admin, vs.).

## Ne zaman gerekir?

- Auth Admin: `auth.users` INSERT/UPDATE/DELETE — Supabase MCP'nin OAuth scope'unda yok, sadece `service_role` ile mümkün.
- 2. test kullanıcısı simülasyonu (UI smoke veya cross-user RLS test).
- Hesap silme akışı (kullanıcı silme + cascade temizlik).
- Edge function lokal test (auth admin client gerekiyorsa).
- Storage bucket policy bypass'lı admin işler.

## Ne zaman gerekmez?

- Normal migration / policy / RLS işleri → **MCP `apply_migration` yeterli** (database:write scope'unda).
- Schema audit, `pg_get_expr`, `list_tables`, `get_advisors` → MCP read scope'unda.
- DB-level smoke (PL/pgSQL DO + rollback) → MCP `execute_sql` yeterli.

Yani bu runbook MCP'nin sınırına çarpıldığında (Auth Admin) açılır.

## Kurulum (bir kerelik)

1. Kopyala:
   ```powershell
   Copy-Item .env.admin.local.example .env.admin.local
   ```
2. Supabase Dashboard → **Project Settings → API**:
   - `service_role` (secret/hidden) → `.env.admin.local` içine `SUPABASE_SERVICE_ROLE_KEY=` satırına yapıştır.
   - `SUPABASE_URL` zaten dolu (https://sjeqwiqgwzagengdukye.supabase.co).
3. **Anahtarı hiçbir yere yazmayın:** chat, Slack, e-posta, screenshot, commit message, hata raporu. Yalnız bu dosyaya.

## Erişim sağlama testi

```powershell
.\scripts\admin\check_admin_access.ps1
```

Beklenen çıktı:
```
supabase url present: yes
admin key present: yes
Test: Auth Admin /admin/users (page=1, per_page=1, read-only)...
admin API reachable: yes
users listed on page 1: <N>
Destructive islem yapilmadi.
```

Script salt-okunur `/auth/v1/admin/users?page=1&per_page=1` çağırır. Anahtar konsola yazılmaz; sadece `present: yes/no`.

## Güvenlik kuralları

| Kural | Sebep |
|---|---|
| `.env.admin.local` git'te yok | `.gitignore` `.env.*` + explicit satır + ek `.env.admin.local` satırı |
| service_role Flutter app'e geçmez | `--dart-define` ile verilirse APK'da kalır, decompile edilebilir → RLS bypass |
| service_role Logs/screenshots/chat'e yazmaz | Tek leak = projenin tüm RLS'i delik |
| Destructive admin işlemler ayrıca onay ister | drop / truncate / delete-all / user delete / storage delete |
| Üretim ortamında bu mekanizma yok | Üretim için ayrı server-side process + rotation gerekir |

## Anahtar kullanılan/kullanılmayan yerler

- **MCP** (`mcp__supabase__*`): OAuth `database:write` scope'u yeterli — `service_role` GEREKMEZ. Bu, Claude'un günlük çalışma yolu.
- **Auth Admin REST** (`/auth/v1/admin/*`): `service_role` ZORUNLU. `scripts/admin/check_admin_access.ps1` bunu kullanır.
- **Flutter app** (`supabase_flutter`): yalnız `SUPABASE_ANON_KEY` (publishable). `service_role` ASLA verilmez (`.env.local` ile karıştırılmaz).

## Sızıntı/leak protokolü

Eğer service_role yanlışlıkla:
- chat / log / commit message / screenshot'a düşerse:
  1. **Hemen** Supabase Dashboard → Project Settings → API → **Rotate `service_role` key**.
  2. Eski anahtarla yapılan herhangi bir aktivite için audit log incele.
  3. `.env.admin.local` dosyasını yeni anahtarla güncelle.

## İlgili dosyalar

- `.env.admin.local.example` — template
- `.env.admin.local` — gerçek (ignored)
- `scripts/admin/check_admin_access.ps1` — read-only erişim testi
- `SUPABASE_LOCAL_RUNBOOK.md` — normal anon (Flutter app) için runner
- `SUPABASE_MCP_CONNECTION_REPORT.md` — MCP yetkileri (anon-eşdeğer, service_role gerektirmez)
