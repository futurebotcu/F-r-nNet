# FırınNet — App Review Notes (Draft)

> App Store Connect → "App Review Information → Notes" alanına girilecek metin
> taslağı. Reviewer'ın app'i hızlı anlaması + ret riskini azaltmak için.

## App Hakkında (reviewer için)
FırınNet, fırıncılar, fırın ustaları ve toptancılar için mesleki bir sosyal ağ +
işletme aracıdır. Modüller: Akış (Feed), Gruplar, Malzeme Pazarı (Market),
İş İlanları (Usta Arıyor / iş arıyorum), Fırın Paneli (üretim/fire), Bayi Defteri
(teslimat/tahsilat/bakiye), Reçete Hesaplama, Hikayeler (Stories).

## Giriş ve Erişim
- **Guest mode var:** Açılışta "Kayıtsız devam et" ile reviewer login olmadan
  akışı, pazarı, ilanları ve grupları gezebilir.
- Yazma aksiyonları (post, yorum, ilan, defter kaydı) hesap gerektirir; bu
  durumda nazik bir "hesap oluştur / giriş yap" sayfası açılır (auth sheet).
- **Email/şifre ile giriş** birincil yöntemdir.
- **iOS'ta üçüncü-taraf sosyal login (Google/Apple) gösterilmez** (bu sürümde
  iOS auth ekranı yalnız email/şifre + guest sunar). Sebep: Sign in with Apple
  entegrasyonu henüz aktif değil; tamamlanana dek iOS'ta sosyal login gizli.

## Demo Hesap (tam özellik için)
```
EMAIL:    <to be provided>
PASSWORD: <to be provided>
```
> Reviewer yazma akışlarını test edecekse yukarıdaki demo hesabı doldur. Guest
> mode okuma/gezme için yeterlidir.

## Önemli Notlar
- **Ödeme/abonelik YOK.** In-App Purchase, dijital satış veya paywall yok.
- **Hesap silme app içinde mevcut:** Ayarlar → Hesabı Sil (Guideline 5.1.1(v)).
  Ayrıca web: https://futurebotcu.github.io/F-r-nNet/account-deletion/
- **Gizlilik politikası:** https://futurebotcu.github.io/F-r-nNet/privacy/
- **Tracking yok**, reklam yok, analytics SDK yok.
- Backend: Supabase (canlı). Veriler kullanıcıya özel, satır-bazlı güvenlik (RLS)
  ile izole.

## Bilinmesi Gereken Riskler (dürüst durum — submission öncesi gözden geçir)
- **UGC moderasyon/report/block:** Bu sürümde kullanıcılar yalnız KENDİ içeriğini
  silebiliyor; başkasının içeriğini **şikayet/report** veya kullanıcı **engelleme/block**
  mekanizması HENÜZ YOK. Apple Guideline 1.2 gereği UGC uygulamalarında bu
  beklenir → submission öncesi eklenmesi önerilir (bkz. APP_STORE_RUNBOOK "Known
  Apple Review Risks"). Reviewer'a bu durumu önceden bildirmek ret/iade sürecini
  kısaltabilir, ancak en güvenlisi özelliği eklemektir.
