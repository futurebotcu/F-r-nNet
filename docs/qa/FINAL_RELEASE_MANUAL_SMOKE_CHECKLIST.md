# FırınNet — Final Release Manual Smoke Checklist

Tarih: 2026-06-12 · Faz 1 Hardening sonrası gerçek-cihaz/emülatör doğrulama listesi.
Kullanım: her satırı gerçek hesapla test et; ❌ çıkan P0/P1 olarak raporlanır.

## Auth / Session
- [ ] Temiz kurulum → açılış → AuthEntry görünür
- [ ] E-posta/şifre ile giriş → feed'e düşer
- [ ] Google ile giriş (Android) → feed'e düşer
- [ ] Logout → AuthEntry; tekrar login → feed
- [ ] App'i öldür/aç (session restore) → giriş ekranına ATMAZ
- [ ] Guest "Kayıtsız Devam Et" → feed (read-only), write'ta AuthRequiredSheet
- [ ] Profile eksik kullanıcı → session korunur, profil tamamlamaya gider
- [ ] Token refresh / app resume sonrası: feed/gruplar/market/mesajlar **boşalmaz** (provider select fix doğrulaması)

## Feed / Comments / UGC
- [ ] Feed yüklenir; loading → içerik; boş durumda anlamlı empty state
- [ ] Text post; image post; video post
- [ ] Yorum yaz; beğen/kaydet; kendi postunu sil (confirm)
- [ ] Başkasının postu ⋮ → Şikayet et → "alındı"; tekrar → "zaten şikayet ettin"
- [ ] Kullanıcı engelle → postları feed'den kaybolur, yorumları placeholder
- [ ] Settings → Engellediğim kullanıcılar → Engeli kaldır → içerik geri gelir
- [ ] **Feed boundary:** "eleman aranıyor"/"makine satılık"/"toptan satış" → yönlendirme sheet'i; "eleman bulmak zor"/soru → serbest
- [ ] Yorumda küfür → engellenir (banner)

## Gruplar
- [ ] Grup listesi; gruba gir → composer görünür (üye), join CTA (non-member)
- [ ] Grup text; image; video gönder → bubble + tap viewer/player
- [ ] App background/foreground sonrası composer + medya **kaybolmaz**
- [ ] Çık/tekrar gir → composer durur
- [ ] Grup mesajına uzun bas → şikayet/engelle; engellenen → placeholder

## Generic Chat
- [ ] Profil/market/iş bağlamından sohbet başlat
- [ ] Text/image/video gönder → bubble + viewer/player; unread badge
- [ ] Upload hata → mesaj kaybolmaz, retry; signOut OLMAZ

## Market / İlanlar
- [ ] Market liste/detay; ilan oluştur/düzenle/sil; medya
- [ ] İlanı şikayet et / satıcıyı engelle; satıcıya mesaj
- [ ] İş ilanı liste/detay/oluştur; iş ilanına uzun bas → şikayet
- [ ] Çift-tap form submit → tek kayıt (disabled state)

## Panel / Bayi
- [ ] Panel quick actions; mesaj badge
- [ ] Bayi liste/ekle/düzenle; aktif/pasif; hareket (teslimat/ödeme/iade)
- [ ] Gün sonu raporu; bakiye/borç-alacak hesabı doğru; PDF/paylaş
- [ ] Çift-tap koruması; veri kaybı yok

## Medya edge case
- [ ] Picker iptal → güvenli; permission denied → açıklama
- [ ] Büyük video (>25MB) → "çok büyük" uyarısı, mesaj kaybolmaz
- [ ] Yavaş ağ upload → persistent şerit; başarı/başarısızlık net

## Sistem
- [ ] Ağ kapalı → açık: hata state'i, session **düşmez**
- [ ] App restart sonrası tutarlı
- [ ] Settings/Privacy/Terms erişilebilir; Delete account akışı (2-aşama onay)
- [ ] Hiçbir akışta KIRMIZI EKRAN; beklenmedik logout; yanlış "hesap gerekli"

## iOS özel (TestFlight öncesi)
- [ ] Video kaydında mikrofon izni sheet'i çıkar (NSMicrophoneUsageDescription — bu sprintte eklendi)
- [ ] App icon marka (P0 bloker — onaylı icon bekliyor)
