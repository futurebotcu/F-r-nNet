# FırınNet — Supabase Auth REST Smoke Raporu

Tarih: 2026-05-12
Sonuç özeti:

| Aşama | Durum |
|---|---|
| REST `/auth/v1/signup` canlı doğrulaması | ❌ **BLOCKED** — Supabase free-tier email/domain rate limit |
| `handle_new_user` trigger | ✓ aktif (önceki testlerle ve canlı doğrulamayla kanıtlı) |
| `auth_email_sync` trigger | ✓ aktif |
| `profiles` RLS + policy | ✓ açık, 4 policy |
| V1 tablo veri durumu | ✓ tüm tablolar 0 satır (artık veri yok) |
| `flutter analyze` | ✓ temiz |
| `flutter test` | ✓ 42/42 geçti |
| Flutter kod değişikliği | ❌ — bu turda hiçbir kod değişmedi |

**Bu rapor Supabase publishable anon key değerini içermez. Hiçbir key/secret repoya, log'a veya dosyaya yazılmadı.**

---

## 1. Neden Otomatik REST Signup Şu Anda Güvenilir Değil

REST endpoint'i `POST /auth/v1/signup` üç defa farklı email format'ı ile denendi:

| Email örneği | HTTP | error_code |
|---|---|---|
| `live-smoke-<ts>@firinnet.local` | 400 | `email_address_invalid` |
| `live-smoke-<ts>@firinnet-test.com` | 400 | `email_address_invalid` |
| `live-smoke-<ts>@example.com` | 429 | `over_email_send_rate_limit` |

**Yorum:**
- `.local` ve özel domain'ler Supabase Auth tarafından RFC reserved/unverified domain politikasıyla reddedildi.
- `example.com` denemesi sunucu tarafından kabul edildi ama email confirmation maili **gönderilemediği için** kullanıcı oluşturulmadan reddedildi (free-tier email send rate limit, ~3/saat).
- `auth.users` üzerinde sorgu sonucu: yarım/orphan kayıt yok — Supabase signup endpoint'i atomik, başarısız mail gönderiminde user yaratmıyor.

> **Bunlar Flutter app hatası değil, schema hatası değil, RLS hatası değil.** Supabase projesinde:
> - Auth → Email auth → **Confirm email** açık
> - Email gönderim provider'ı default (free-tier limit'li)
>
> Bu üretim açısından doğru bir default; smoke akışını engelliyor, ama uygulamada yanlış bir şey yok.

## 2. Yarım Test Kullanıcısı Var Mı?

```sql
select id, email, created_at
from auth.users
where email like 'live-smoke-%'
   or email like '%@firinnet.local'
   or email like '%@firinnet-test.com'
order by created_at desc;
```

**Sonuç:** boş set. Cleanup gerekli değil — Supabase signup başarısız olduğunda user oluşturmadı.

## 3. Backend Doğrulamaları (live)

Tek sorgu çıktısı:

```
handle_new_user_state    : O   (origin, enabled)
email_sync_state         : O   (origin, enabled)
profiles_rls             : true
profiles_policy_count    : 4
profiles_rows            : 0
bakeries_rows            : 0
products_rows            : 0
recipes_rows             : 0
production_rows          : 0
dealers_rows             : 0
deliveries_rows          : 0
items_rows               : 0
waste_rows               : 0
```

- `on_auth_user_created` trigger'ı `auth.users` üzerinde dinliyor → yeni kullanıcı INSERT olduğunda profile satırını oluşturmaya hazır.
- `on_auth_user_email_updated` trigger'ı `auth.users.email` UPDATE'inde profiles.email senkron edecek.
- 9 V1 tablo da boş — önceki tüm test verileri temizlenmiş.

> Trigger'ların **gerçek** sözleşmeyi yürüttüğü `SUPABASE_AUTH_USER_HANDLER_REPORT.md` ve `SUPABASE_AUTH_EMAIL_SYNC_REPORT.md`'de end-to-end kanıtlandı: Ahmet Usta / commercial / Konya örneği, geçersiz account_type fallback'i, ON CONFLICT semantiği, email update senkronu — hepsi yeşil.

## 4. Flutter Kod Sağlığı

| Kontrol | Sonuç |
|---|---|
| `flutter analyze` | `No issues found! (ran in 0.4s)` |
| `flutter test` | `00:01 +42: All tests passed!` (8 dosya, 42 test) |
| Flutter kaynak dosyalarına dokunma | **Yok** — bu turda hiçbir `.dart` dosyası değişmedi |

## 5. Email Rate Limit Bilgisi (Davranış Notu)

Şu anki Supabase ayarlarıyla:
- Yeni signup → confirmation maili tetiklenir
- Free-tier 1 saatte ~3 email gönderebilir
- Limit aşılınca yeni signup `429 over_email_send_rate_limit` döner
- Limit bir saat içinde otomatik resetlenir

İki çözüm (proje sahibi seçer):

1. **Dashboard ayarı (önerilen geliştirme akışı için):** Supabase Studio → Authentication → Providers → Email → **"Confirm email" OFF**. Bu yapıldığında signup direkt user yaratır, mail gönderilmez, rate limit'e takılmaz. Üretimde tekrar açılır.
2. **SMTP provider kurulumu:** Authentication → SMTP Settings → kendi SMTP'n ile (SendGrid/Postmark/Resend vb.). Free-tier limit kalkar.

> Bu rapor üzerinde **hiçbir değişiklik yapılmadı** — yalnız önerilerdir. Karar proje sahibinindir.

## 6. Manuel UI Smoke İçin Güvenli Yol

Otomatik REST smoke şu an engelli; manuel akış için adımlar (anon key'i dart-define ile ver, repo'ya hiç yazma):

### 6.1 Hazırlık (tek seferlik, isteğe bağlı)
- Supabase Studio → Auth → Confirm email **OFF** (geliştirme için).
- Veya gerçek bir kişisel email kullan, confirmation tıklat.

### 6.2 Çalıştırma
```
flutter run ^
  --dart-define=SUPABASE_URL=https://sjeqwiqgwzagengdukye.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=<publishable_anon_key>
```
Anon key MCP üzerinden `get_publishable_keys` ile alınır; dart-define'a paste edilir; herhangi bir dosyaya yazılmaz.

### 6.3 Test akışı (UI)
1. Splash → **/login**
2. "Profil Oluştur" → form:
   - Hesap türü: Ticari
   - Profil adı: Ahmet Usta
   - Şehir: Konya
   - E-posta: gerçek bir email (gmail vb.) ya da confirm-off ile herhangi
   - Şifre: en az 6 karakter
   - Meslek rozeti: Usta Fırıncı
3. Kaydet → **/panel** açılır
4. Backend doğrulama (paralel terminal'de MCP veya Supabase Studio):
   - `select * from auth.users where email = …`
   - `select * from public.profiles where id = …`
   - `account_type='commercial'`, `city='Konya'`, `profession_badge='Usta Fırıncı'`, `display_name='Ahmet Usta'`
5. **Profilden Çık** → /login
6. Aynı email/şifreyle giriş → **/panel** açılır, kart Ticari set
7. Cleanup: `delete from auth.users where email = …` (cascade ile profile da düşer)

### 6.4 Anahtarsız fallback
```
flutter run
```
- Splash → /onboarding (eski akış)
- "Profil Oluştur" formunda şifre alanı **yok**
- "Kayıtsız Devam Et" guest → /feed
- Mock akış bozulmamış (zaten `flutter test`te 42 testin tümü geçiyor)

## 7. Sonuç

- **App / schema / RLS / kod tarafında hata yok**; bu turda hiçbir kod değişmedi.
- Otomatik REST signup smoke yalnız Supabase free-tier email rate limit'i nedeniyle tamamlanamadı.
- Trigger ve RLS önceki turlarda gerçek auth.users INSERT yoluyla end-to-end doğrulanmıştı; o sonuçlar hâlâ geçerli.
- `flutter analyze` ve `flutter test` (42/42) hâlâ yeşil — bu PR'a regresyon yok.
- Manuel UI smoke için yukarıdaki adımlar yeterli; rate limit'e takılmamak için "Confirm email" geçici kapatılabilir veya gerçek email kullanılır.
