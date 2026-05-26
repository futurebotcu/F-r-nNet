# Auth Profile Create Failure — Root Cause Report

**Tarih:** 2026-05-16
**Ekran:** Profil Oluştur (`CreateProfileScreen`)
**Kullanıcı görünen hata (SnackBar):** `Failed to decode error response`

---

## 1. Belirti

`Kaydol / Profil Oluştur` butonuna basıldığında:
- Hesap oluşturulmuyor.
- Ekranda ham İngilizce hata olarak `Failed to decode error response` SnackBar'ı çıkıyor.
- Kullanıcıya gösterilemez (Türkçe değil, bilgisiz, eyleme yönlendirmiyor).

## 2. Logcat / SDK gerçek hata

String `Failed to decode error response` Dart kodumuzda yok. Kaynağı:

```
~/AppData/Local/Pub/Cache/hosted/pub.dev/gotrue-2.20.0/lib/src/fetch.dart:69-76
```

Tetik koşulu (`GotrueFetch._handleError`):
1. HTTP status `>= 500` DEĞİL (5xx olsa `AuthRetryableFetchException` atılırdı, başka mesaj).
2. Response body boş değil.
3. `jsonDecode(response.body)` patlıyor → `AuthUnknownException(message: 'Failed to decode error response')`.

Yani Supabase Auth (GoTrue) endpoint'ine yapılan request **4xx + non-JSON (HTML/plain) body** ile dönmüş.

## 3. Endpoint / operation

`SupabaseAuthRepository.signUp` → `_client.auth.signUp(email, password, data: metadata)` →
`POST <SUPABASE_URL>/auth/v1/signup`

## 4. Root cause

`.env.local` içindeki `SUPABASE_URL` **Supabase Dashboard URL'i**, API URL'i değil.

Tespit edilen shape (değer yazılmadan):
- `contains supabase.com`     → yes (kullanılan host yanlış)
- `contains /project/`        → yes (host'tan sonra path var — Supabase API hostlarında olmaz)
- `ends with .supabase.co host` → NO
- `length`                    → 59 (doğru API URL'i ~40 char olur)

Yani URL şu şekilde:
```
https://supabase.com/dashboard/project/<project-ref>
```

Doğrusu:
```
https://<project-ref>.supabase.co
```

### Neden init aşamasında patlamadı?

`Supabase.initialize(url:, anonKey:)` URL'i sadece string olarak saklar; reachability/format doğrulaması yapmaz. İlk auth çağrısına kadar hata sessiz kalır.

### Mekanik zinciri

1. `signUp` → `POST https://supabase.com/dashboard/project/<ref>/auth/v1/signup`
2. `supabase.com` bu path için **HTML 4xx** döndürür (404/405 vb.).
3. `gotrue/fetch.dart`: status 4xx, body HTML → `jsonDecode` patlar → `AuthUnknownException("Failed to decode error response")`.
4. `SupabaseAuthRepository.signUp` catch: `throw Exception(translateAuthError(e))`.
5. `auth_error_translator.dart`:
   - `error is AuthApiException` → false
   - `error is AuthException` → true (`AuthUnknownException extends AuthException`)
   - `error.message.isEmpty` → false (mesaj var)
   - **Ham mesaj geri döner ve UI'a basılır.**

## 5. Yan etkilerin değerlendirmesi (bu hatadan SORUMLU DEĞİL)

Request hiç Supabase'e ulaşmadığı için aşağıdakiler bu vakada suçlu değil — ama hijack edilmemesi için doğrulandı:
- `public.profiles` schema: kolonlar (`id, display_name, account_type CHECK (commercial|individual|wholesaler), profession_badge, city, avatar_url, email`) UI'ın gönderdiği metadata ile uyumlu. ✅
- `handle_new_user` trigger: `display_name` fallback zinciri + `account_type` whitelist + `on conflict do update only email/updated_at` defansif. ✅
- RLS: profile insert client'tan değil, trigger SECURITY DEFINER ile yapılır. ✅
- Client metadata payload (`display_name`, `account_type`, `profession_badge`, `city`): trigger ile bire bir eşleşiyor. ✅

## 6. Fix plan

### A. (Yapılandırma — kullanıcı tarafında)
`.env.local` içindeki `SUPABASE_URL` değerini Supabase Dashboard → Project Settings → API → **Project URL** alanından kopyalanan API URL ile değiştir.
Format: `https://<project-ref>.supabase.co` — sonunda `.supabase.co`, path YOK, trailing slash YOK.

### B. (Kod — defansif iyileştirme)
1. `auth_error_translator.dart` → `AuthUnknownException` ve `AuthRetryableFetchException` durumlarını yakala, ham SDK mesajını UI'a basma. Türkçe, eyleme yönlendiren mesaj göster.
2. `main.dart` / `AppConfig` → debug build'de URL shape doğrulaması (assertion). Yanlış URL ile yola çıkmayı baştan engelle.

### C. Kullanıcıya gösterilecek doğru Türkçe mesajlar

| Senaryo | Mesaj |
|---|---|
| `user_already_exists` / "already registered" | Bu e-posta zaten kayıtlı. Giriş yapmayı dene. |
| `weak_password` / "password" | Şifre çok zayıf. En az 6 karakter olmalı. |
| `email_not_confirmed` / "not confirmed" | E-posta adresin henüz onaylanmadı. Gelen kutunu kontrol et. |
| `invalid_credentials` / "invalid login" | E-posta veya şifre hatalı. |
| rate limit | Çok fazla deneme. Birkaç dakika sonra tekrar dene. |
| ağ / `SocketException` / `Failed host lookup` | İnternet bağlantısı yok. Bağlantını kontrol et. |
| `AuthRetryableFetchException` (5xx / geçici) | Sunucuya ulaşılamadı. Birkaç saniye sonra tekrar dene. |
| `AuthUnknownException` ("Failed to decode error response", URL/yapılandırma sorunu, beklenmedik gateway) | Sunucu bağlantısı yapılandırılamadı. Lütfen daha sonra tekrar dene. |
| Diğer her şey | Beklenmeyen bir hata oluştu. Tekrar dene. |

## 7. Doğrulama

- `flutter analyze` (translator + assertion sonrası).
- Yanlış URL ile build → SnackBar artık "Sunucu bağlantısı yapılandırılamadı..." göstermeli (raw `Failed to decode` değil).
- Doğru URL ile build → signup başarılı; profile satırı trigger'la oluşur.

## 8. Kapsam dışı (bu raporda yapılmaz)

- Service_role kullanımı — yok.
- Fatih hesabını silme/değiştirme — yok.
- Release AAB — yok.
- Commit/push — yok.
- Production env değişikliği — yok (sadece local `.env.local`).
