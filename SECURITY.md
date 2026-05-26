# Güvenlik Politikası / Security Policy

FırınNet, kullanıcıların hesap, defter ve sosyal verilerini Supabase
üzerinde tutar. Güvenlik bizim için kritik öncelik — açık bulan
araştırmacılara sorumlu açıklama (responsible disclosure) süreciyle
teşekkür ederiz.

## Desteklenen sürümler

| Sürüm | Durum |
|---|---|
| `main` (aktif geliştirme) | ✅ Güvenlik düzeltmeleri uygulanır |
| `v0.1.x` (V1 release hattı) | ✅ Güvenlik düzeltmeleri uygulanır |
| Önceki sprint snapshot'ları | ❌ Desteklenmez |

## Güvenlik açığı bildirimi

**Lütfen güvenlik açıklarını PUBLIC GitHub Issue'da açmayın.** Açık
issue, henüz düzeltilmemiş bir açığı saldırganlara duyurabilir.

Bunun yerine **iki yoldan biri** kullanılmalı:

### 1. GitHub Security Advisories (tercih edilen)

Repo sayfasında **Security → Advisories → Report a vulnerability**
butonu üzerinden private advisory oluşturulabilir. Bu rota:
- bilgileri yalnızca repo sahibine gösterir,
- coordinated disclosure'ı kolaylaştırır,
- CVE atanması gerekiyorsa otomatik akış sağlar.

### 2. E-posta

Security Advisories erişimi yoksa veya tercih edilmiyorsa:

📧 **fatihkartal75@gmail.com**

Konu satırı önerisi: `[FırınNet Security] <kısa başlık>`

## Bildirilmesi beklenen konular

Aşağıdaki kategorilerden birine giren her bulgu raporlanmalı:

- **Auth / Session**: hesap ele geçirme, oturum yenileme atakları,
  guest guard bypass, OAuth callback exploitation.
- **Account deletion**: `delete-account` Edge Function'ın yetki
  doğrulamasını atlatma, başka kullanıcıyı silme.
- **Supabase RLS**: yanlış yapılandırılmış policy nedeniyle başka
  kullanıcının verisini okuma/yazma.
- **Data exposure**: profil, mesaj, bayi defteri, reçete, market ilanı,
  iş ilanı, story gibi içeriklerin yetkisiz okunması.
- **Storage bucket permissions**: `feed-media`, `market-media`,
  `story-media`, `avatars` bucket'larında yetkisiz erişim.
- **Secret leakage**: repo, build artifact, log veya client binary
  içinde `service_role` veya başka bir backend sırrının görünmesi.
- **firinnet_id sızıntısı**: kullanıcı-özel `FN-YYYY-NNNNNN` ID'sinin
  public yüzeylerde (profil snapshot RPC, search, share link, public
  query) görünür hale gelmesi.
- **KVKK / GDPR uyum riskleri**: kişisel veri toplama/işleme/silme
  kurallarına aykırı davranış.
- **Mobile-specific**: Android deep-link hijacking, iOS URL scheme
  saldırıları, intent redirection.
- **Dependency vulnerabilities**: kullanılan pub paketlerinde aktif
  olarak istismar edilen güvenlik açıkları.

## Beklenebilecek yanıt süreleri

| Durum | Hedef |
|---|---|
| İlk yanıt | 72 saat içinde |
| Etki analizi + düzeltme planı | 7 gün içinde |
| Kritik açıklarda hotfix | mümkün olduğunca hızlı |
| Düşük öncelikli bulgular | sonraki sprint penceresi |

## Kapsam dışı

- Sosyal mühendislik raporları (phishing, spear-phishing).
- Üçüncü parti servislerin (Supabase, Google, Apple) kendi platform
  hataları — direkt ilgili sağlayıcıya bildirin.
- Henüz exploit edilebilir olmayan teorik bulgular (lütfen kanıt
  içeren PoC ekleyin).
- Public Supabase project URL veya anon key'in görünmesi — anon key
  client-side için tasarlanmıştır; gerçek koruma RLS katmanındadır.

## Teşekkür

Sorumlu bildirim yapan araştırmacılara CHANGELOG'da (veya advisory
metninde) opsiyonel olarak teşekkür ediyoruz. İsim/anonim tercihiniz
size ait.
