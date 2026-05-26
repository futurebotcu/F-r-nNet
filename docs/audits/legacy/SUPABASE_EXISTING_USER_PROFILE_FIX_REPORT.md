# FırınNet — Mevcut Auth Kullanıcısı Profile Fix Raporu

Tarih: 2026-05-12
Kullanıcı: `fatihkartal75@gmail.com`

**Uygulanan kurallar:**
- Flutter koduna dokunulmadı.
- Supabase schema/RLS değiştirilmedi.
- Kullanıcı silinmedi.
- Yeni signup denemesi yapılmadı.
- Token / key / secret rapora yazılmadı.

---

## 1. Tespit (önce-fotoğrafı)

`auth.users` + `public.profiles` join ile durum:

| Alan | Değer |
|---|---|
| `auth.users.id` (UID) | `abf96b42-0d17-40b1-9b0f-cbf910f9e2a4` |
| `auth.users.email` | `fatihkartal75@gmail.com` |
| `auth.users.created_at` | 2026-05-12 09:41:25 UTC |
| `auth.users.email_confirmed_at` | **null** ⚠ — onaylanmamış |
| `auth.users.raw_user_meta_data` | `{display_name: 'fatih', account_type: 'commercial', city: 'manisa', profession_badge: 'Usta Fırıncı', email_verified: false, ...}` |
| `public.profiles.id` | `abf96b42-…` ✓ aynı UID |
| `public.profiles.display_name` | `fatih` |
| `public.profiles.account_type` | `commercial` |
| `public.profiles.profession_badge` | `Usta Fırıncı` |
| `public.profiles.city` | `manisa` |
| `public.profiles.email` | `fatihkartal75@gmail.com` |
| `public.profiles.created_at` | 2026-05-12 09:41:25 UTC (auth.users ile aynı saniye) |

**Önemli gözlemler:**
- ✓ `handle_new_user` trigger **canlı şekilde çalışmış**: signup'tan ~milisaniye sonra profile satırını oluşturmuş, metadata sözleşmesini tam uygulamış.
- ✓ Signup endpoint'i sonunda çalıştı — yani rate limit zamanla resetlenmiş ya da Flutter signup formu başarıyla `/auth/v1/signup`'a ulaştı. `raw_user_meta_data`'da Flutter'ın gönderdiği sözleşme tam: `display_name`, `account_type`, `city`, `profession_badge`.
- ⚠ `email_confirmed_at` **null** — kullanıcı confirmation maili tıklamamış. Bu Supabase Auth'ta "Confirm email" ayarı ON ise login akışı için kritik (aşağıdaki §4).

## 2. Aksiyon — Profile UPDATE

Talimattaki değerlerle 5 alan idempotent güncellendi:

```sql
update public.profiles
set display_name     = 'Fatih',
    account_type     = 'commercial',
    profession_badge = 'Usta Fırıncı',
    city             = 'Manisa',
    email            = 'fatihkartal75@gmail.com'
where id = 'abf96b42-0d17-40b1-9b0f-cbf910f9e2a4'
returning id, display_name, account_type, profession_badge, city, email, created_at, updated_at;
```

Değişen değerler:
- `display_name`: `fatih` → **`Fatih`** (capitalize)
- `city`: `manisa` → **`Manisa`** (capitalize)
- `account_type`, `profession_badge`, `email`: zaten doğru, idempotent yeniden yazıldı.

`set_updated_at` trigger devreye girdi, `updated_at` ilerledi.

## 3. Aksiyon Sonrası — sonra-fotoğrafı

| Alan | Değer |
|---|---|
| `id` | `abf96b42-0d17-40b1-9b0f-cbf910f9e2a4` |
| `display_name` | `Fatih` ✓ |
| `account_type` | `commercial` ✓ |
| `profession_badge` | `Usta Fırıncı` ✓ |
| `city` | `Manisa` ✓ |
| `email` | `fatihkartal75@gmail.com` ✓ |
| `created_at` | 2026-05-12 09:41:25.548 UTC (orijinal) |
| `updated_at` | 2026-05-12 10:10:54.256 UTC (UPDATE sonrası) |

Profile artık tam sözleşmede; Flutter `/panel` ekranı `account_type=commercial` üzerinden Ticari kart setini render edecek.

## 4. Login Öncesi Kritik Not — Email Confirmation

`auth.users.email_confirmed_at = null` olduğu için **Supabase Auth ayarı "Confirm email" ON ise** Flutter'da `signIn` çağrısı şu hata ile dönecektir:

```
AuthApiException: email_not_confirmed
```

Bu durumda `SupabaseAuthRepository` TR mesajı verir:
> "E-posta adresin henüz onaylanmadı. Gelen kutunu kontrol et."

Üç çözüm seçeneği (en kolaydan en üretim-uyumluya):

### Seçenek A — MCP ile manuel onay (tek satır SQL, en hızlı)
Aşağıdaki sorguyu çalıştırmamı isterseniz onaylanır. **Şu an yapmadım** — kullanıcıyı silmeme kuralına paralel olarak izinsiz state değişimi de yapmadım. Onaylarsanız çalıştırırım:
```sql
update auth.users
set email_confirmed_at = now(),
    confirmed_at       = now()
where id = 'abf96b42-0d17-40b1-9b0f-cbf910f9e2a4';
```

### Seçenek B — Studio'dan onay
- https://supabase.com/dashboard/project/sjeqwiqgwzagengdukye/auth/users
- Kullanıcıyı seç → `…` menü → **Send magic link** veya **Confirm user**.

### Seçenek C — Confirm Email global OFF
- Studio → Auth → Providers → Email → "Confirm email" OFF → Save.
- Sonra Flutter `signIn` çalışır (mevcut kullanıcılar için bile, çünkü artık confirmation gerekmez).
- Üretim öncesi yeniden ON yapılır.

> Eğer "Confirm email" zaten **OFF** ise login direkt çalışır — bu durumda §4 atlanır.

## 5. Manuel UI Login Akışı

```powershell
flutter run ^
  --dart-define=SUPABASE_URL=https://sjeqwiqgwzagengdukye.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=<publishable_anon_key>
```

Beklenen akış:
1. Splash → `/login`
2. Email: `fatihkartal75@gmail.com`, şifre: signup sırasında verdiğiniz
3. **Giriş Yap** →
   - Email confirmed ise → `/panel` açılır, Ticari kart seti (Fırın Paneli featured, Bayi Paneli, İlanlarım, Mesajlar)
   - Email confirmed değilse → SnackBar "E-posta adresin henüz onaylanmadı." → §4'teki bir seçeneği uygula
4. Profile Hero: avatar="F" + "Fatih" + "Usta Fırıncı" + "Hesap: Ticari" + "Şehir: Manisa"
5. **Profilden Çık** → `/login` → tekrar giriş ile state aynı kalmalı (profile fetch yeniden Supabase'den çekilir, hardcoded değil)

## 6. Bekleyen Aksiyonlar (sizde)

- [ ] §4'ten bir seçenek uygula (email confirmed durumuna göre)
- [ ] Flutter'ı `--dart-define=…` ile çalıştır
- [ ] Login akışını yukarıdaki adımlarla doğrula
- [ ] Manuel test bitince **siz** kullanıcıyı silersiniz (bu rapor silmedi, kuralınıza uygun)

---

## EK: Genel sağlık özeti

- `auth.users`: 1 satır (Fatih). Başka test kullanıcısı yok.
- `public.profiles`: 1 satır (Fatih), trigger ile tutarlı.
- V1 diğer tablolar (bakeries, dealers, vb.): hepsi 0 satır — temiz.
- Flutter analyze + test: 44/44 son turdaki yeşil duruma denk.
- Schema, RLS, trigger sözleşmeleri canlı doğrulandı (üretim akışı çalışıyor).
