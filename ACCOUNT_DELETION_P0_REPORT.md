# FırınNet — Account Deletion P0 Report

**Tarih:** 2026-05-16
**Branch:** `main`
**Proje:** FırınNet, ref `sjeqwiqgwzagengdukye`
**PR scope:** Mağaza öncesi KVKK / Google Play account-deletion compliance.

---

## Executive Summary

- ✅ **Kullanıcı uygulama içinden hesabını silebiliyor:** ProfileScreen → "Hesabımı Sil" → 2-aşamalı confirmation dialog (HESABIMI SİL keyword) → loading → Edge Function → signOut → /auth.
- ✅ **`delete-account` Edge Function deploy edildi** (v1, ACTIVE, verify_jwt=true). Caller'ın JWT'sini doğrular, **yalnız kendi user_id'siyle** `auth.admin.deleteUser` çağırır; body/query'den user_id KABUL ETMEZ.
- ✅ **`service_role` mobile app'e ASLA verilmez** — yalnız Edge runtime'da `Deno.env.get`'ten okunur.
- ✅ **CASCADE zinciri:** `profiles.id → auth.users(id) on delete cascade` + tüm tablo `owner_id → profiles(id) on delete cascade`. `auth.admin.deleteUser` → tüm bağlı veri (feed/group/dealer/recipe/worker) otomatik silinir.
- ✅ **Live smoke 7/7 PASS:** test user yarat → feed_post oluştur → confirm=false reject (400) → no-auth reject (401) → confirm=true → 200 → user 404 → CASCADE residue 0.
- ✅ Fatih kullanıcısı dokunulmadı.
- ✅ `flutter analyze` → No issues · `flutter test` → **210/210 passed** (197 önceki + 13 yeni account deletion testi).
- ✅ Yeni migration YOK; mevcut V1 cascade FK'leri kullanıldı.

---

## Current audit (öncesi)

| Kontrol | Sonuç |
|---|---|
| `deleteAccount` / `Hesap sil` referansı `lib/` `test/` `supabase/` altında | **Hiç yok** |
| `AuthRepository` abstract | signUp/signIn/signOut/updateEmail/resetPasswordForEmail mevcut |
| `supabase/functions/` klasörü | yoktu — yeni oluşturuldu |
| Cascade FK'leri | ✅ Mükemmel: 20+ tablo `on delete cascade` zinciriyle profiles'a, profiles auth.users'a bağlı |

Bu temel sayesinde **yeni migration gerekmedi**: `auth.admin.deleteUser(id)` çağrısı tüm yan veriyi temizliyor.

---

## Architecture decision

**Seçim: Supabase Edge Function (Deno) + Authorization Bearer JWT verify + service_role server-side only.**

Alternatifler ve red sebepleri:
1. **Client'tan doğrudan `service_role` ile silme** ❌ — service_role mobile binary'ye gömülürse RLS bypass, tüm projenin güvenliği biter.
2. **RPC (SQL function)** — `SECURITY DEFINER` ile `auth.admin.delete_user` çağrılamaz (auth admin postgres-level değil GoTrue REST katmanıdır). Reddedildi.
3. **Manuel "talep" akışı + admin runbook** — V1 için yeterli ama Google Play "in-app deletion" rehberini karşılamaz. Reddedildi.

Kararı destekleyen koşullar:
- MCP `deploy_edge_function` ile sürtünmesiz deploy var.
- service_role anahtarı Edge runtime ortam değişkenlerine otomatik enjekte ediliyor; ek secret yönetimi gereksiz.
- `verify_jwt: true` ile Edge runtime zaten Authorization header'ı kontrol ediyor; fonksiyon içi `auth.getUser()` ile çift katmanlı doğrulama.

---

## Edge Function behavior

**Dosya:** `supabase/functions/delete-account/index.ts` (Deno runtime)
**Slug:** `delete-account` (v1, ACTIVE, verify_jwt=true)

### Akış

1. `OPTIONS` → CORS preflight 200.
2. Method ≠ `POST` → `405 method_not_allowed`.
3. `Authorization` header yok veya `Bearer ` ile başlamıyor → `401 unauthorized`.
4. Body parse → `body.confirm !== true` → `400 confirm_required`.
5. `Deno.env.get('SUPABASE_URL'/'SUPABASE_ANON_KEY'/'SUPABASE_SERVICE_ROLE_KEY')` — biri eksikse `500 misconfigured`.
6. Caller JWT verify: anon key ile `createClient`, Authorization header forward, `auth.getUser()`. Hata veya null user → `401 unauthorized`.
7. Admin client (service_role) ile `auth.admin.deleteUser(callerId)`. Caller'ın **kendi id'si** kullanılır; body/query'den user_id alınmaz.
8. Hata → `500 delete_failed` (generic).
9. Başarı → `200 { "ok": true }`.

### Loglama disiplini
- `console.log` çağrısı YOK.
- Anahtarlar, JWT, user_id, email konsola yazılmaz.
- Hata yanıtları opaque kod (örn. `"unauthorized"`); detail dış dünyaya sızdırılmaz.

### Caller bypass koruması
- Body'de `user_id` field'ı KABUL EDİLMEZ — fonksiyon onu hiç okumaz.
- `auth.admin.deleteUser(callerId)` çağrısı yalnız JWT'den çıkartılan id'yle yapılır. User A, User B'yi silemez.

---

## Flutter UI behavior

**Konum:** `ProfileScreen` → "Hesap" bölümünün sonu, "Profilden Çık" butonunun altında.

### Akış

1. **CTA** `Icons.delete_forever_outlined` + `AppStrings.accountDeleteCta` ("Hesabımı Sil"), `AppColors.danger`.
2. `_onDeleteAccountPressed`:
   - `!AppConfig.supabaseEnabled` → snackbar `accountDeleteUnsupportedOffline` + return (Supabase off durumda function yok).
   - `authRepo == null || currentUser == null` → snackbar `accountDeleteRequireAuth` + return.
   - `showDialog<bool>` ile `_DeleteAccountConfirmDialog` (barrierDismissible=false).
3. **Confirmation dialog** (`_DeleteAccountConfirmDialog` StatefulWidget):
   - Title: "Hesabını silmek istiyor musun?"
   - Body: net data-loss açıklaması (profil + reçete + bayi + fire + sosyal omurga silinir).
   - TextField: `textCapitalization: TextCapitalization.characters`, `autocorrect: false`, `enableSuggestions: false`.
   - Confirm button (`AppColors.danger`) yalnız `value.trim().toUpperCase() == "HESABIMI SİL"` iken **enabled**.
   - "Vazgeç" her zaman açık.
4. Onay alınırsa:
   - `_DeleteAccountLoading` dialog (barrierDismissible=false).
   - `authRepo.deleteAccount()` → SupabaseAuthRepository → `functions.invoke('delete-account', body: {'confirm': true})`.
   - Function 200 ise client `auth.signOut()` (best-effort; JWT zaten server-side geçersiz).
5. Cleanup:
   - Loading dialog `Navigator.pop` (rootNavigator).
   - `guestModeProvider.setGuest(false)`.
   - `profileControllerProvider.notifier.clear()`.
   - Snackbar `accountDeleteSuccessSnack` ("Hesabın silindi.")
   - `context.go(AppRoutes.authEntry)`.
6. Hata olursa: loading kapanır, snackbar `accountDeleteErrorGeneric` Türkçe; sayfa açık kalır.

### Tek-tıkla silme yok
- 2-step UI guard: ilk tıkla dialog açılır, sonra keyword onayı + onaylama tuşu.
- Function-level: `confirm: true` body olmayan istek 400 reddedilir (defense-in-depth).

---

## Data deletion cascade map

```
auth.users          ← delete-account function
  └─ profiles                    (on delete cascade)
       ├─ bakeries               (on delete cascade)
       │    ├─ bakery_products
       │    ├─ recipe_calculations
       │    ├─ production_entries
       │    ├─ dealers
       │    │    ├─ dealer_deliveries  ─ dealer_delivery_items
       │    │    ├─ dealer_transactions
       │    │    ├─ dealer_prices
       │    │    └─ dealer_notes
       │    └─ waste_entries
       ├─ worker_profiles
       ├─ worker_experiences
       ├─ job_seek_posts
       ├─ feed_posts             ─ feed_likes / feed_saves / feed_comments
       ├─ social_groups          ─ group_members / group_messages
       ├─ feed_likes (kendi)
       ├─ feed_saves (kendi)
       ├─ group_members (kendi)
       └─ group_messages (kendi)
```

Tüm satırlar `auth.users` silinmesinden zincirleme temizlenir; manuel cleanup gerekmez.

---

## Security notes

| Kontrol | Durum |
|---|---|
| service_role anahtarı `lib/` altında | ❌ Yok (hardcoded JWT pattern testle koruma altında) |
| service_role yalnız Deno.env.get'ten | ✅ |
| Function verify_jwt | ✅ true |
| Function ek `auth.getUser()` doğrulaması | ✅ (defense-in-depth) |
| Caller başkasını silebilir mi? | ❌ `body/query/user_id` okunmuyor; callerId yalnız JWT'den |
| confirm=true zorunlu | ✅ (400 reddedildi) |
| no auth header | ✅ 401 |
| Console.log secret sızıntısı | ❌ Yok |
| Hata mesajları opaque | ✅ Kod döndürür, detail değil |
| 2-step UI confirmation | ✅ Keyword required |
| Offline (Supabase disabled) durumda akış | ✅ Erken exit + snackbar |

---

## Test user live smoke (7/7 PASS)

Script: `scripts/admin/account_deletion_smoke.ps1`

| # | Test | Sonuç | Detay |
|---|---|---|---|
| 1 | Test user yarat (Admin API) | ✅ PASS | `200` |
| 2 | Sign-in (user JWT) | ✅ PASS | `200` |
| 3 | Pre-delete: user feed_post oluşturur | ✅ PASS | `201` |
| 4 | **Negative:** confirm=false reddedildi | ✅ PASS | `400` |
| 5 | **Negative:** no auth header reddedildi | ✅ PASS | `401` |
| 6 | **Positive:** delete-account 200 + ok=true | ✅ PASS | `200` |
| 7 | Verify: auth.users[user_id] gone | ✅ PASS | `404` |

### MCP bağımsız teyit

```
auth_users_total           : 1   ← Fatih korunmuş
auth_users_smoke_residue   : 0
profiles_total             : 1
profiles_smoke_residue     : 0
feed_posts_total           : 0
feed_posts_smoke_residue   : 0
social_groups_total        : 0
group_members_total        : 0
group_messages_total       : 0
feed_likes_total           : 0
feed_saves_total           : 0
```

Pre-delete eklenen `feed_post` CASCADE ile temizlendi; Fatih kullanıcısı + 1 bakery verisi dokunulmadı.

### Secret hijyeni
- `service_role` anahtarı **konsola yazılmadı** (sadece `present: yes` masking).
- Test user UUID'i bilinçli olarak yazdırılmadı.
- Cleanup için ek silme komutu gönderilmedi — function'ın kendisi cascade temizliği yaptı.

---

## analyze / test result

```
flutter pub get   → OK
flutter analyze   → No issues found! (0.8s)
flutter test      → 210 / 210 passed
  - account_deletion_p0_test.dart: 13 yeni test (PASS)
  - auth_provider_reactive_test.dart: +1 metod stub (PASS)
  - Diğer 196 mevcut test: PASS
```

### Yeni test grupları (13 test)
1. **AuthRepository.deleteAccount interface (1):** abstract metod compile-time zorunlu.
2. **ProfileScreen delete account UI source (5):** CTA + 2-step dialog + loading + signOut+redirect + offline guard.
3. **delete-account Edge Function source (5):** service_role Deno.env'den, caller JWT zorunlu, confirm=true zorunlu, callerId kullanımı, verify_jwt + admin client ayrımı.
4. **Flutter lib/ secret hygiene (2):** hardcoded JWT pattern yok; Bearer service_role literal kullanımı yok.

---

## Files changed

| Dosya | Tür | Açıklama |
|---|---|---|
| `lib/core/constants/app_strings.dart` | M | 11 yeni Türkçe copy (`accountDelete*`) |
| `lib/features/auth/repositories/auth_repository.dart` | M | `deleteAccount` abstract metodu + mimari doc |
| `lib/features/auth/repositories/supabase_auth_repository.dart` | M | Supabase impl: function invoke + signOut |
| `lib/features/profile/screens/profile_screen.dart` | M | Hesabı Sil CTA + 2-step dialog + loading widget |
| `supabase/functions/delete-account/index.ts` | A | Edge Function (Deno) — JWT verify + admin delete |
| `scripts/admin/account_deletion_smoke.ps1` | A | Live smoke runner (negative + positive + cascade) |
| `test/account_deletion_p0_test.dart` | A | 13 yeni test |
| `test/auth_provider_reactive_test.dart` | M | `_FakeAuthRepository` deleteAccount stub |
| `ACCOUNT_DELETION_P0_REPORT.md` | A | Bu rapor |

**Migration veya schema değişikliği:** YOK (mevcut cascade kullanıldı).

---

## Remaining limitations

| ID | Konu | Çözüm |
|---|---|---|
| V2-D1 | Re-authentication adımı (silmeden önce password tekrar girme) | UI iyileştirme PR'ı |
| V2-D2 | "Hesabımı dışa aktar" (KVKK Article 20 — data portability) | Ayrı PR |
| V2-D3 | Silme öncesi e-posta onay linki (double opt-in) | Ayrı PR |
| V2-D4 | Storage bucket'ta kullanıcıya ait dosyalar (V2'de bucket açılırsa) | V2 ile birlikte ele alınır |
| V2-D5 | Audit log: silme tarihi, IP, vs. (compliance) | Ayrı tablo + RLS |
| P2 | "Hesabı geri al" 30-gün soft-delete | Mevcut hard-delete + cascade tercih edildi (V1) |

V1 için bunların hiçbiri Google Play account-deletion rehberinin minimum gereklerini bloklamaz.

---

## Store compliance impact

**Google Play (Aralık 2023+):** Hesabı olan kullanıcılar uygulama içinden hesaplarını silebilmeli.

| Madde | Önce | Sonra |
|---|---|---|
| Uygulama içi hesap silme | ❌ Yok | ✅ Var (`ProfileScreen → Hesabımı Sil`) |
| Silme akışı 2 adımlı onay | — | ✅ Keyword + danger button |
| Silinen verinin neler olduğu açıklaması | — | ✅ Dialog body'sinde net |
| Backend'de kalıcı silme | — | ✅ `auth.admin.deleteUser` + cascade |
| Mobile binary'de service_role | ❌ Yok | ✅ Hâlâ yok (Edge'de kalır) |
| Reviewer için doc | — | ✅ Bu rapor |

**KVKK:** Veri sahibi hesabını sildiğinde kişisel verisi 30 gün içinde silinmeli. Bu akış anlık silme yapar; süre gereği fazlasıyla karşılanır.

---

## Açık P0'lar (bu PR scope dışı)

- **P0-4** Android release signing config (`android/key.properties` + `signingConfig`) — ayrı PR
- **P0-5** Privacy/Terms taslak banner — legal metin onayı sonrası ayrı PR
- **Manuel açık iş:** UI smoke (env runner ile — DB tarafı zaten doğrulandı)
