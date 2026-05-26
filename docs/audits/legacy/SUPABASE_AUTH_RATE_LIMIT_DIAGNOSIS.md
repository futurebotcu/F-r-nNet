# FırınNet — Supabase Auth Rate Limit Teşhis Raporu

Tarih: 2026-05-12
Bağlam: Manuel UI signup denemesinde farklı e-postalarla da kullanıcı oluşmuyor; uygulama "Çok fazla deneme" hatası gösteriyor.

**Karar: Daha fazla `/auth/v1/signup` denemesi yapılmayacak.** Bu rapor mevcut backend state'i fotoğraflıyor, kök nedeni doğruluyor ve güvenli alternatif test akışını veriyor.

**Uygulanan kurallar:**
- Flutter koduna dokunulmadı.
- Supabase schema/RLS değiştirilmedi.
- Test kullanıcısı oluşturulmadı (zaten yok).
- service_role / PAT / DB password kullanılmadı.
- Anon key rapora yazılmadı.

---

## 1. Kök Neden

Supabase Auth **built-in email provider**'ının saatlik gönderim limiti vardır. `/auth/v1/signup` confirm-email akışında bir email tetikler; limit aşıldığında endpoint `429 Too Many Requests` döner. Resmi belge:
- Built-in provider için **2 email/saat** (varsayılan, free-tier).
- Limit **proje + email-gönderim** seviyesinde, başka e-posta adresi ile yeniden denemek bu limiti aşmaz.
- Çözüm: custom SMTP (SendGrid/Postmark/Resend vb.) veya Confirm Email kapatma.

Önceki turlarda 3 farklı email format'ı denendi:
- `.local` → 400 `email_address_invalid` (RFC reserved)
- özel domain `.com` → 400 `email_address_invalid` (unverified domain)
- `@example.com` → 429 `over_email_send_rate_limit`

Üçüncü denemeyle proje email gönderim quote'u tükenmiş görünüyor.

## 2. Mevcut Backend Durumu (live)

### 2.1 Son 1 saatte oluşan kullanıcı
```sql
select id, email, created_at, email_confirmed_at, raw_user_meta_data
from auth.users
where created_at > now() - interval '1 hour';
```
**Sonuç:** **0 satır.** Hiç kullanıcı yaratılmamış.

### 2.2 Son 1 saatte oluşan profile
```sql
select * from public.profiles where created_at > now() - interval '1 hour';
```
**Sonuç:** **0 satır.** handle_new_user trigger için tetikleyici insert olmadı, doğru davranış.

### 2.3 Son 1 saatlik auth audit log
```sql
select created_at, payload->>'action' as action, payload->>'actor_username' as email
from auth.audit_log_entries
where created_at > now() - interval '1 hour';
```
**Sonuç:** **0 satır.** Rate limiter signup denemelerini **pre-auth katmanında** reddetmiş, GoTrue audit log'una hiç giriş düşmemiş. Yani signup business logic'i hiç çalıştırılmadı.

### 2.4 Auth config görünürlüğü
GoTrue config'i Supabase tarafında **environment variable + management API** üzerinden tutulur, DB'de değil. `auth` schema'sındaki tablolar (users, sessions, identities, audit_log_entries, refresh_tokens, mfa_*, sso_*, oauth_*, webauthn_*) yalnız işletme verisi içerir; "Confirm email on/off" gibi ayarlar buradan okunamaz. Bu ayarı yalnız **Supabase Studio → Authentication → Providers → Email** ekranı gösterir.

### 2.5 Advisor (security)
2 uyarı (her ikisi de bizim olmayan, Supabase'in kendi yardımcısı `public.rls_auto_enable()`):
- `anon_security_definer_function_executable`
- `authenticated_security_definer_function_executable`

Auth ile alakası yok. `auth_leaked_password_protection` uyarısı bu seferki çekimde gözükmedi (önceki çekimde vardı; muhtemelen sadece bazı turlarda örnekleniyor).

## 3. Bu Bir Flutter Hatası Değildir

| İddia | Kanıt |
|---|---|
| Flutter `SupabaseAuthRepository.signUp()` yanlış mı çağırıyor? | Hayır — REST API doğrudan curl ile aynı sözleşme denenince de aynı 429 döndü; SDK katmanı atlandığında bile rate-limit aktif. |
| Metadata sözleşmesi mi bozuk? | Hayır — endpoint metadata'ya hiç bakmadan rate-limit'le reddediyor. |
| Schema/trigger mi sorun çıkarıyor? | Hayır — handle_new_user trigger sadece auth.users INSERT olduğunda fire eder; rate-limit nedeniyle INSERT hiç gerçekleşmedi. |
| RLS/grant mi engelliyor? | Hayır — RLS authenticated rolüne göre filtreler, signup öncesi rate-limit auth iç katmanı. |

**Sonuç:** Flutter uygulaması ve V1 schema sağlıklı. Sorun yalnızca Supabase Auth'un free-tier email gönderim hız sınırı.

## 4. Güvenli Manuel Test Yolu (önerilen)

Aşağıdaki adımlar **email göndermez**, dolayısıyla rate-limit'i tetiklemez ve bekleme gerektirmez.

### 4.1 Dashboard'dan auto-confirmed test kullanıcısı oluştur
1. https://supabase.com/dashboard/project/sjeqwiqgwzagengdukye/auth/users
2. **"Add user"** → **"Create new user"**
3. Form:
   - Email: `ahmet@example.com` (veya tercih ettiğiniz başka geçerli email)
   - Password: en az 6 karakter (örn. `Smoke12345`)
   - **"Auto Confirm User"** kutusunu işaretle (email tetiklenmez, kullanıcı doğrulanmış olur)
4. Create.

> Bu akış Supabase Studio'nun admin yetkisiyle yapıldığı için email rate limit'e takılmaz. Kullanıcı tarafında konfigürasyon kalmaz.

### 4.2 handle_new_user trigger çalıştı mı doğrula
MCP veya Studio SQL Editor'da:
```sql
select id, display_name, account_type, city, profession_badge, email
from public.profiles
where email = 'ahmet@example.com';
```
**Beklenen:** 1 satır. `display_name = 'ahmet'` (email prefix fallback), `account_type = 'individual'` (metadata yok, default).

### 4.3 İsteğe bağlı: profil metadata'sını test için tamamla
Add User formu raw_user_meta_data alanı sunmaz; bu yüzden trigger fallback'leriyle minimal profile oluşur. Tasarımın gerçek metadata akışını test etmek için **bu test kullanıcısı özelinde** profili SQL ile güncelle:

```sql
update public.profiles
set display_name = 'Ahmet Usta',
    account_type = 'commercial',
    profession_badge = 'Usta Fırıncı',
    city = 'Konya'
where email = 'ahmet@example.com';
```
RLS bu UPDATE'i MCP service-role context'te bypass eder. Üretim akışında bu güncelleme client'tan, RLS scope'unda yapılır.

### 4.4 Flutter uygulamasından login
```powershell
flutter run ^
  --dart-define=SUPABASE_URL=https://sjeqwiqgwzagengdukye.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=<publishable_anon_key>
```
- Splash → /login
- Email: `ahmet@example.com`, şifre: yukarıda verdiğiniz
- **Giriş Yap** → /panel açılır
- Ticari panel kartları görünür (Fırın Paneli featured, Bayi Paneli, İlanlarım, Mesajlar)
- Profilden Çık → /login → tekrar giriş → state aynı

### 4.5 Cleanup (manuel test sonrası)
Dashboard → Auth → Users → kullanıcıyı seç → Delete user. Cascade ile `public.profiles` satırı düşer.

## 5. Kalıcı Çözümler (proje sahibi seçer)

### Seçenek A — Geliştirme için Confirm Email kapat
- **Yer:** Studio → Authentication → Providers → Email
- **"Confirm email"** OFF → Save
- Sonuç: signup direkt user yaratır, confirmation maili gönderilmez, rate-limit'e takılmaz. Production öncesi yeniden açılır.
- Risk: Üretim açısından email kontrolü zayıflar; sadece dev/test stage'i için.

### Seçenek B — Custom SMTP kur
- **Yer:** Studio → Project Settings → Authentication → SMTP Settings
- SendGrid / Postmark / Resend / kendi SMTP'n.
- Sonuç: free-tier built-in provider'ın 2/saat limiti kalkar.
- Risk: Üçüncü taraf hesap gerekir; en doğru üretim çözümü.

### Seçenek C — Sadece 1 saat bekle
- Limit otomatik resetlenir. Daha fazla bombardıman bunu uzatabilir; **şu andan itibaren signup denemesi yapılmamalı**.

## 6. Bekleyen İş

- **Kod tarafında bekleyen iş yok.** Flutter Auth+Profile entegrasyonu canlı (önceki rapor: `SUPABASE_FLUTTER_AUTH_INTEGRATION_REPORT.md`).
- **Backend tarafında bekleyen iş yok.** Schema/RLS/trigger'lar yeşil; önceki tüm raporlar geçerli.
- Bir sonraki adım proje sahibinin Seçenek A/B/C arasında tercihidir; bu rapor karar almaz.

## 7. Aksiyon Listesi (sizin için)

- [ ] Dashboard'tan auto-confirmed user oluştur (§4.1)
- [ ] Profile trigger ile satır oluştuğunu doğrula (§4.2)
- [ ] İsteğe bağlı: metadata'yı SQL ile tamamla (§4.3)
- [ ] Flutter'ı `--dart-define=…` ile çalıştır, login + /panel akışını test et (§4.4)
- [ ] Test sonrası kullanıcıyı sil (§4.5)
- [ ] Confirm Email'i tercih ettiğin moda al (§5)
