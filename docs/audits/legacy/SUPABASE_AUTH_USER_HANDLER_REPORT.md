# FırınNet Supabase — `handle_new_user` Auth Trigger Raporu

Tarih: 2026-05-12
Kapsam: Yalnız Supabase migration. Flutter koduna dokunulmadı.

---

## 1. Migration

| Alan | Değer |
|---|---|
| Project ref | `sjeqwiqgwzagengdukye` |
| Migration version | `20260512080338` |
| Migration adı | `firinnet_v1_auth_user_handler` |
| Local dosya | `supabase/migrations/20260512080338_firinnet_v1_auth_user_handler.sql` |
| Remote uygulama yöntemi | `mcp__supabase__apply_migration` |
| Eski migration'lara dokunma | Yok (DDL eklemeli, drop yok) |
| RLS dokunması | Yok — `profiles` RLS açık, 4 policy aynen duruyor |

Remote history (sondan başa, sync sonrası):

```
20260512080338  firinnet_v1_auth_user_handler        ← bu PR
20260512075525  firinnet_v1_revoke_trigger_fn_execute
20260512075421  firinnet_v1_grants_authenticated
20260512075056  firinnet_v1_core_schema
```

## 2. Fonksiyon ve Trigger

- **Fonksiyon**: `public.handle_new_user()`
  - `language plpgsql`
  - `security definer` (auth schema'dan public.profiles'a yazmak için gerekli)
  - `set search_path = public, auth` (search_path injection koruması)
  - `revoke execute from public, anon, authenticated` (RPC üzerinden çağrılamaz)

- **Trigger**: `on_auth_user_created`
  - `after insert on auth.users`
  - `for each row execute function public.handle_new_user();`
  - `tgenabled = 'O'` (origin, normal aktif)

## 3. Metadata Mapping

`new.raw_user_meta_data` → `public.profiles` alanları:

| profile alanı | Kaynak öncelik sırası | Boş/yok kaldığında |
|---|---|---|
| `id` | `new.id` | (zorunlu) |
| `display_name` | `meta.display_name` → `meta.name` → `split_part(new.email, '@', 1)` → `'FırınNet Kullanıcısı'` | Son fallback hep dolar |
| `account_type` | `meta.account_type` (yalnız `commercial`/`individual`/`wholesaler`) | `individual` |
| `profession_badge` | `meta.profession_badge` (boş trim → null) | null |
| `city` | `meta.city` (boş trim → null) | null |
| `avatar_url` | `meta.avatar_url` (boş trim → null) | null |
| `email` | `new.email` | null (anonim kullanıcı) |

Notlar:
- `display_name` ve diğer string alanlarda `nullif(trim(...), '')` ile whitespace-only girişler null sayıldı.
- `account_type` için **beyaz liste**: tabloda zaten `CHECK` constraint var, ama trigger seviyesinde de filtre kondu — geçersiz değer fonksiyonu patlatmıyor, sessizce `individual`'a düşüyor.

## 4. ON CONFLICT Stratejisi (karar gerekçesi)

```sql
on conflict (id) do update
  set email = excluded.email,
      updated_at = now();
```

**Karar**: `DO NOTHING` yerine **dar kapsamlı `DO UPDATE`** seçildi.

- Çakışma normalde **olamaz** (profiles.id `auth.users(id)`'e FK; auth.users PK; yeniden insert mümkün değil).
- Yine de defansif olarak ele alındı: replay/restore senaryoları, ya da elle profile manipülasyonu sonrası.
- `email` güncellenir çünkü auth tarafı email'in tek doğru kaynağıdır (Supabase Auth email değişimini orada yönetir).
- `display_name`, `account_type`, `profession_badge`, `city`, `avatar_url` **kasıtlı olarak ezilmez** — kullanıcı bu alanları profil ekranında zaten değiştirmiş olabilir. Trigger kullanıcının seçimini geri almamalı.
- `updated_at = now()` audit izi bırakır.

## 5. Email Update Politikası

- Bu migration **yalnız INSERT trigger** içerir.
- Auth tarafında email değişimi (`auth.users.email` UPDATE) için ayrı bir trigger eklenmedi.
- Mevcut davranış: `auth.users.email` değişirse `public.profiles.email` **eski değerinde kalır** (drift olur).
- Önerilen ayrı migration: `firinnet_v1_auth_email_sync` — `after update of email on auth.users` triggeri.

## 6. Güvenlik Notları

- ✓ `SECURITY DEFINER` + `set search_path = public, auth` → şema-kaçırma (search_path injection) koruması.
- ✓ `revoke execute on function public.handle_new_user() from public, anon, authenticated` → RPC üzerinden anon/auth/anonymous çağıramaz; sadece trigger context'inde çalışır.
- ✓ `service_role` migration'da hiç kullanılmadı, client'a hiçbir secret konmadı.
- ✓ RLS `public.profiles` üzerinde hâlâ açık, 4 owner-based policy aynen duruyor (`id = auth.uid()`).
- ✓ `auth.users` schema'sına insert yapan tek aktör Supabase Auth servisidir; trigger ona zincirlenir.
- ✓ `account_type` beyaz listesi + `CHECK` constraint çift katmanlı doğrulama.
- ✓ Hiçbir token, key, URL `.env`'e, repo'ya, log'a, Flutter koduna yazılmadı.

## 7. Test Sonuçları

Tüm testler synthetic `auth.users` insert ile gerçek trigger yolu üzerinden yapıldı.

| # | Senaryo | Beklenen | Bulunan |
|---|---|---|---|
| 1 | Tam metadata: `display_name=Ahmet Usta, account_type=commercial, profession_badge=Usta Firinci, city=Konya, email=ahmet@…` | profiles satırı tüm alanlarla, avatar_url null | **OK** ✓ |
| 2 | Geçersiz `account_type=wrong_value`, display_name var | display_name korunur, account_type=`individual` | **OK** ✓ |
| 3 | Metadata boş `{}`, email var | display_name = email prefix (`minimal-user`), account_type=`individual` | **OK** ✓ |
| 3b | Metadata boş, email de boş (anonymous user) | display_name = `FırınNet Kullanıcısı`, email = null | **OK** ✓ |
| 4 | ON CONFLICT: önce kullanıcı profilini değiştirdi (`Ahmet Bey (kendisi degistirdi)` + `wholesaler`), sonra trigger'ın yaptığı insert çakışırsa: display_name/account_type korunmalı, email yeni değere update | display_name + account_type korundu, email update, updated_at ilerledi | **OK** ✓ |

### 7.1 RLS doğrulaması (post-migration)
- `pg_tables.rowsecurity` = `true` (profiles) ✓
- Policy sayısı = 4 (önceki durumla aynı, gevşeme yok) ✓
- Migration'ın `to authenticated` ya da policy'lere dokunması **yok**.

### 7.2 Test verisi durumu
4 synthetic `auth.users` (`a/b/c/d` UUID'leri) ve onların oluşturduğu profiller silindi. Cascade ile temizlendi.
Tüm V1 tablolarda mevcut satır sayısı: **profiles 0, bakeries 0, dealers 0, deliveries 0, items 0, recipes 0, production 0, waste 0**.

## 8. Flutter Signup Tarafının Metadata Sözleşmesi

Flutter `supabase_flutter` ile signup yaparken `data:` (raw_user_meta_data) **şu sözlük ile** gönderilmeli:

```dart
await supabase.auth.signUp(
  email: emailController.text.trim(),
  password: passwordController.text,
  data: {
    'display_name': displayNameController.text.trim(),
    'account_type': selectedAccountType, // 'commercial' | 'individual' | 'wholesaler'
    'profession_badge': professionBadge,  // opsiyonel, null olabilir
    'city': cityController.text.trim(),   // opsiyonel
    // 'avatar_url' signup ekraninda genelde yok; profil ekraninda doldurulur
  },
);
```

Sözleşme kuralları:
- Hiçbir alanı zorunlu görmeyin — backend tüm fallback'lere sahip.
- `account_type` sadece üç değerden biri olmalı; başka değer gönderilirse backend sessizce `individual`'a düşer (UX'te buna güvenmeyin, formda doğrulayın).
- Boş string yerine `null` gönderebilirsiniz; backend zaten trim+nullif yapıyor.
- `avatar_url` signup'ta yoksa sonradan profil ekranından update edilir.
- Supabase `signUp` çağrısı başarılı olduğu anda `public.profiles` satırı **garanti** vardır; client'tan ek `insert into profiles` çağırmaya gerek yok (zaten RLS de buna izin verir ama duplicate riski yaratır).

## 9. Açık Bırakılanlar (kapsam dışı, bilinçli)

1. **Email update sync** — auth.users.email değişiminde profiles.email senkronizasyonu (ayrı migration).
2. **Soft delete** — kullanıcı hesap silme akışı (auth.users delete cascade var, ama "deactivate" alternatifi yok).
3. **avatar_url storage bucket** — V2'ye bırakıldı.
4. **`name` alternatifi** — OAuth providers (Google/Apple) genelde `name` alanı gönderir; fallback zinciri bunu zaten kapsıyor.
5. **Trigger advisor'ı** — security advisor sonraki turda tekrar çekilebilir; bu migration ek SECURITY DEFINER fonksiyonu ekledi, execute revoke uygulandığı için yeni uyarı beklenmez.

## 10. Sonraki Migration Önerileri (sıra)

1. `firinnet_v1_auth_email_sync` — auth.users.email UPDATE → profiles.email senkron.
2. `firinnet_v2_storage_avatars` — `avatars` bucket + owner-scoped policy.
3. `firinnet_v2_social_feed` — gönderiler/yorumlar/beğeniler.
4. `firinnet_v2_messaging` — DM/grup.
5. `firinnet_v3_jobs_classifieds` — ilan sistemi.

---

## EK: Güncel dosya yapısı

```
C:\dev\firinnet\
├── supabase\
│   └── migrations\
│       ├── 20260512075056_firinnet_v1_core_schema.sql
│       ├── 20260512075421_firinnet_v1_grants_authenticated.sql
│       ├── 20260512075525_firinnet_v1_revoke_trigger_fn_execute.sql
│       └── 20260512080338_firinnet_v1_auth_user_handler.sql   ← yeni
├── SUPABASE_SCHEMA_V1_REPORT.md
├── SUPABASE_LOCAL_MIGRATIONS_SYNC_REPORT.md
└── SUPABASE_AUTH_USER_HANDLER_REPORT.md   ← bu rapor
```
