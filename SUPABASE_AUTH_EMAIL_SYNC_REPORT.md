# FırınNet Supabase — `auth_email_sync` Raporu

Tarih: 2026-05-12
Kapsam: Yalnız Supabase migration. Flutter koduna dokunulmadı.

---

## 1. Migration

| Alan | Değer |
|---|---|
| Project ref | `sjeqwiqgwzagengdukye` |
| Version | `20260512080804` |
| Ad | `firinnet_v1_auth_email_sync` |
| Local mirror | `supabase/migrations/20260512080804_firinnet_v1_auth_email_sync.sql` |
| Uygulama yöntemi | `mcp__supabase__apply_migration` (tek seferlik, idempotent değil) |
| Eski migration'lara dokunma | Yok |
| Drop / reset | Yok |
| RLS gevşemesi | Yok (`profiles.rowsecurity=true`, policy sayısı 4 sabit) |

Remote history (sondan başa):

```
20260512080804  firinnet_v1_auth_email_sync          ← bu PR
20260512080338  firinnet_v1_auth_user_handler
20260512075525  firinnet_v1_revoke_trigger_fn_execute
20260512075421  firinnet_v1_grants_authenticated
20260512075056  firinnet_v1_core_schema
```

## 2. Function ve Trigger

**Fonksiyon: `public.sync_profile_email()`**
- `language plpgsql`
- `security definer`
- `set search_path = public, auth`
- Tek iş: `UPDATE public.profiles SET email = new.email, updated_at = now() WHERE id = new.id;`
- Sadece tek satıra dokunur; aşağıya kademeli yan etki yok.

**Trigger: `on_auth_user_email_updated`**
- `after update of email on auth.users`
- `for each row`
- `when (old.email is distinct from new.email)` → email gerçekten değişmediyse fonksiyon **çağrılmaz** (no-op update'lerinde gereksiz yazma yok)
- `tgenabled = 'O'` (origin, aktif)

> `update of email` cümleciği, başka kolonların update edildiği auth.users UPDATE'lerinde trigger'ın hiç değerlendirilmesini bile engeller — micro-optimizasyon.

## 3. Güvenlik / Revoke

| Önlem | Durum |
|---|---|
| `SECURITY DEFINER` + sabit `search_path` | ✓ — search_path injection korumalı |
| `revoke execute on function public.sync_profile_email() from public` | ✓ |
| `revoke execute … from anon` | ✓ |
| `revoke execute … from authenticated` | ✓ — RPC `/rest/v1/rpc/sync_profile_email` çağrılamaz |
| `service_role` client'a yansıtma | Yok — token yalnız MCP env |
| RLS gevşetme | Yok — `profiles` 4 policy, hepsi `to authenticated` + `id = auth.uid()` |
| Public read/write açma | Yok |
| Token / key dosyaya yazma | Yok |

## 4. Test Sonuçları

Synthetic `auth.users` ile gerçek trigger yolu kullanıldı.

| # | Adım | Beklenen | Bulunan |
|---|---|---|---|
| 1 | `auth.users` INSERT (`eski@firinnet.local`, metadata: display_name='Email Test', account_type='commercial') | `handle_new_user` profil oluşturur, email=`eski@…`, updated_at=created_at | **OK** ✓ |
| 2 | `UPDATE auth.users SET email='yeni@firinnet.local'` | `sync_profile_email` çalışır; profiles.email=`yeni@…`, updated_at > created_at | **OK** ✓ (updated_at_advanced=true) |
| 3 | Aynı email ile tekrar `UPDATE` (no-op) | WHEN clause yüzünden trigger fire **etmemeli**; profiles.updated_at değişmemeli | **OK** ✓ (ts_unchanged=true, 0.5s sleep'e rağmen aynı ts) |
| 4 | RLS post-check | `profiles.rowsecurity=true`, 4 policy | **OK** ✓ |
| 5 | Trigger varlık | `pg_trigger.tgenabled='O'` | **OK** ✓ |

### Test verisi temizliği
- Synthetic user (`eeeeeeee-…`) silindi, cascade ile profili de düştü.
- Doğrulama: `profiles=0`, test domainli `auth.users` satırı sayısı **0**.

## 5. Etkileşim: `handle_new_user` ile sınır

| Olay | İlgili trigger | Davranış |
|---|---|---|
| `INSERT INTO auth.users` | `on_auth_user_created` → `handle_new_user()` | Yeni profile satırı; ON CONFLICT yalnız email/updated_at update |
| `UPDATE auth.users SET email=…` | `on_auth_user_email_updated` → `sync_profile_email()` | profiles.email + updated_at güncellenir |
| `UPDATE auth.users SET <başka alan>` | hiçbiri | profiles dokunulmaz (trigger `OF email` ile dar) |

İki trigger birbirini etkilemiyor; aynı UPDATE içinde email değiştiğinde sadece email-sync triggeri çalışır (handle_new_user yalnız INSERT'e bağlı).

## 6. Flutter Tarafına Etkisi

- Mevcut Flutter kodu (henüz Supabase'e bağlı değil) **etkilenmez**.
- Bağlandıktan sonra:
  - Email değiştirme akışı Supabase Auth UI'larından gelir: `supabase.auth.updateUser(UserAttributes(email: 'yeni@…'))`. Bu çağrı `auth.users.email`'i günceller → trigger devreye girer → profiles.email otomatik senkron.
  - Flutter tarafında `public.profiles` üzerinde manuel email update **gerekmez** (zaten RLS bunu kullanıcının kendi satırında zaten izin verir, ama gereksiz çift kayıt yaratır).
  - Email change confirmation akışında Supabase önce `email_change` alanını set eder, kullanıcı onay verince `email` final değerine yazılır → trigger o aşamada ateşlenir.

Sözleşme: Flutter UI sadece `auth.updateUser` çağırır; `profiles.email`'e direkt yazmaz.

## 7. Açık Bırakılanlar (kapsam dışı, bilinçli)

- **auth.users.delete**: cascade FK ile profiles satırı zaten otomatik düşüyor; ayrı trigger gerekmiyor.
- **auth.users.phone / metadata değişimi**: ayrı sync trigger'ı yok (bu PR sadece email).
- **Email değişim audit log'u**: ayrı `email_change_log` tablosu yok; isterseniz V2'de eklenir.
- **Realtime publication**: `profiles` Realtime'a ekli değil; gerekirse ayrı migration.

## 8. Sonraki Migration Önerileri

1. `firinnet_v2_storage_avatars` — avatars bucket + owner-scoped policy.
2. `firinnet_v2_realtime_profile_self` — kullanıcı kendi profilinin değişimini Realtime ile alabilsin (opsiyonel UX iyileştirmesi).
3. `firinnet_v2_social_feed` — gönderiler.
4. Flutter `supabase_flutter` bağlama PR'ı (ayrı tur).

---

## EK: Güncel dosya yapısı

```
C:\dev\firinnet\
├── supabase\
│   └── migrations\
│       ├── 20260512075056_firinnet_v1_core_schema.sql
│       ├── 20260512075421_firinnet_v1_grants_authenticated.sql
│       ├── 20260512075525_firinnet_v1_revoke_trigger_fn_execute.sql
│       ├── 20260512080338_firinnet_v1_auth_user_handler.sql
│       └── 20260512080804_firinnet_v1_auth_email_sync.sql   ← yeni
├── SUPABASE_SCHEMA_V1_REPORT.md
├── SUPABASE_LOCAL_MIGRATIONS_SYNC_REPORT.md
├── SUPABASE_AUTH_USER_HANDLER_REPORT.md
└── SUPABASE_AUTH_EMAIL_SYNC_REPORT.md   ← bu rapor
```
