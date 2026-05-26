# FırınNet — Test Kullanıcı Email Onay Raporu

Tarih: 2026-05-12
Kullanıcı: `fatihkartal75@gmail.com` (id `abf96b42-0d17-40b1-9b0f-cbf910f9e2a4`)

**Uygulanan kurallar:**
- Flutter koduna dokunulmadı.
- Supabase schema/RLS değiştirilmedi.
- Kullanıcı silinmedi.
- Token / key / secret rapora yazılmadı.

---

## 1. Aksiyon

### 1.1 İlk deneme — `confirmed_at` generated column
İstenen orijinal SQL:
```sql
update auth.users
set email_confirmed_at = now(),
    confirmed_at       = now()
where id = 'abf96b42-0d17-40b1-9b0f-cbf910f9e2a4';
```
**Sonuç:** `ERROR 428C9: column "confirmed_at" can only be updated to DEFAULT`.
`auth.users.confirmed_at` Supabase'de **generated column**'dur (`coalesce(email_confirmed_at, phone_confirmed_at)` türetimi). Manuel set edilemez; sadece `email_confirmed_at` veya `phone_confirmed_at` yazıldığında otomatik dolar.

### 1.2 Düzeltilmiş UPDATE
```sql
update auth.users
set email_confirmed_at = now()
where id = 'abf96b42-0d17-40b1-9b0f-cbf910f9e2a4'
returning id, email, email_confirmed_at, confirmed_at, updated_at;
```
**Sonuç:** 1 satır etkilendi, `confirmed_at` generated column tarafından otomatik dolduruldu.

## 2. Doğrulama (sonra-fotoğrafı)

| Alan | Beklenen | Bulunan |
|---|---|---|
| `auth.users.email_confirmed_at` | not null | **2026-05-12 10:15:37 UTC** ✓ |
| `auth.users.confirmed_at` (generated) | not null | **2026-05-12 10:15:37 UTC** ✓ |
| `auth.users.email` | fatihkartal75@gmail.com | ✓ |
| `public.profiles.display_name` | Fatih | **Fatih** ✓ |
| `public.profiles.account_type` | commercial | **commercial** ✓ |
| `public.profiles.profession_badge` | Usta Fırıncı | **Usta Fırıncı** ✓ |
| `public.profiles.city` | Manisa | **Manisa** ✓ |
| `public.profiles.email` | fatihkartal75@gmail.com | ✓ |

Profile satırı önceki turdaki UPDATE'ten beri **dokunulmadı**; bütünlük korunmuş.

## 3. Etki: Flutter Login

Şimdi `signInWithPassword` çağrısı `email_not_confirmed` hatasını **döndürmeyecek**. `SupabaseAuthRepository.signIn` kullanıcıyı doğrudan oturum açar, `ProfileController` `authStateChanges` aracılığıyla profile satırını fetch eder, `/panel` Ticari kart seti açılır.

## 4. Manuel Login Adımları (sizin için)

```powershell
flutter run ^
  --dart-define=SUPABASE_URL=https://sjeqwiqgwzagengdukye.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=<publishable_anon_key>
```

1. Splash → `/login`
2. Email: `fatihkartal75@gmail.com`, Şifre: signup'ta verdiğiniz
3. **Giriş Yap** → `/panel` açılır (Ticari kart seti: Fırın Paneli featured + Bayi Paneli + İlanlarım + Mesajlar)
4. Feed header → avatar tap → Profile screen
   - Hero: avatar "F" + **Fatih** + **Usta Fırıncı** + Hesap: **Ticari** + Şehir: **Manisa**
5. **Profilden Çık** → `/login` → aynı email/şifre ile tekrar giriş → state aynı yüklenmeli (profile fetch Supabase'den)

## 5. Bekleyen Aksiyonlar (sizde)

- [ ] Yukarıdaki manuel login akışını test et
- [ ] Beklenen sonuç sağlanmazsa hangi noktada bozuldu raporla (login mi, /panel mi, profile hero mu)
- [ ] Test bitince **siz** kullanıcıyı silersiniz — bu rapor silmedi (kuralınız)

---

## EK: Genel durum

- `auth.users`: 1 satır (Fatih, onaylı, hazır).
- `public.profiles`: 1 satır (Fatih, tam sözleşmede).
- V1 diğer tablolar: hepsi 0 satır.
- Schema, RLS, trigger sözleşmeleri yeşil.
- Flutter Auth+Profile entegrasyonu canlı (önceki rapor: `SUPABASE_FLUTTER_AUTH_INTEGRATION_REPORT.md`).

Bir sonraki PR önerisi: **Fırın Paneli + Bayi Yönetimi local repository'lerini Supabase'e bağlama** (mevcut Local impl yedek olarak korunur).
