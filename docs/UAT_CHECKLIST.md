# FırınNet — UAT Checklist (Kapalı/Açık Test)

> Cihaz: Galaxy A34 (gerçek) + emülatör. Build: önce debug smoke, sonra
> **signed release/profile** (minify+R8 + push + Crashlytics teyidi).
> Her senaryo sonrası: crash yok, donma yok, Türkçe hata anlaşılır.

## 0. Build / Release ön-koşul
- [ ] Signed AAB üretildi (key.properties + keystore; fail-fast config).
- [ ] Release/profile build cihazda açılıyor (minify sonrası beyaz ekran yok).
- [ ] ProGuard Firebase/GMS keep → push + Crashlytics çalışıyor.

## 1. Guest (Kayıtsız Devam)
- [ ] Splash → "Kayıtsız Devam" → Topluluk/Pazar/İlanlar browse açılıyor.
- [ ] Yazma denemesi (post/teklif/yorum) → giriş yönlendirme (GuestActionRequired).
- [ ] Deep-link `/panel`, `/dealers`, `/debt-expense`, `/pazar/magazam` → `/auth` (FN-008).
- [ ] Public görseller (feed/market/story/avatar) görüntüleniyor (getPublicUrl).

## 2. Bireysel (Usta)
- [ ] Google/email ile giriş → profil oluştur/tamamla.
- [ ] Mesleki CV merkezi (bio + kayıtlar + görünürlük) çalışıyor.
- [ ] İş arama ilanı oluştur/düzenle.
- [ ] Sosyal: post/yorum/beğeni/repost; sayaçlar doğru (client UPDATE ile değişmez, FN-011).
- [ ] Avatar yükle → 5MB üstü reddediliyor (MediaLimits), normal görsel yükleniyor.
- [ ] **Hesabını sil → başarılı** (D-1 cascade; şoför değilse de).

## 3. Ticari / Fırıncı
- [ ] Panel + Fırın paneli (üretim/reçete/gün sonu/rapor).
- [ ] Bayi yönetimi: bayi ekle/düzenle/pasif.
- [ ] **Gün sonu / aralık raporu — gece vardiyası tarihi doğru** (00:00–03:00 teslimat bugüne, FN-004).
- [ ] Borç & Gider defteri: borç/gider/personel ekle; ağ kapalı → "Tekrar dene" (FN-007).
- [ ] Şoför daveti oluştur → generic mesaj + saatlik rate-limit (FN-012).
- [ ] amount işaret: payment/return negatif girilemez (FN-016).

## 4. Tedarikçi (B2B)
- [ ] Mağaza oluştur/düzenle; ürün + kampanya ekle.
- [ ] Kampanya **tarih seçici** (serbest metin yok); süresi geçmiş kampanya listede yok (FN-006).
- [ ] Form **çift-submit guard** (hızlı çift tık tek kayıt, FN-017).
- [ ] Teklif Ağı: açık talebe teklif ver; **aynı talebe 2. teklif reddi** (FN-015).
- [ ] Görsel yükle → boyut limiti çalışıyor (MediaLimits).

## 5. B2B Alıcı akışı
- [ ] Teklif talebi oluştur (anonim) → tedarikçilerden teklif gel.
- [ ] Teklifi kabul et → talep Teklif Ağı'ndan **çıkıyor**, yeni teklif gelmiyor (FN-014).
- [ ] Kabul sonrası "İlgileniyorum" / lead mesajı çalışıyor (status korundu).
- [ ] Tedarikçi reply `status/accepted`'i değiştiremiyor (FN-003, server-enforced).

## 6. Şoför (half / full)
- [ ] Davet kabul → atanmış bayiler görünüyor (normal defter).
- [ ] **Yarı yetki:** teslimat/tahsilat/iade ekle; fiyat/silme/düzeltme → temiz red.
- [ ] **Tam yetki:** fiyat ekle + işlem sil + düzeltme.
- [ ] **Not ekle → patron defterinde görünüyor** (owner_id=patron, FN-009).
- [ ] Atanmamış bayide işlem → reddediliyor.
- [ ] **Şoför hesabını sil → başarılı** (D-1; şoför kaydı/atama cascade, patron finansalı korunur).

## 7. Push (FCM)
- [ ] Login → cihaz token kaydı (user_push_tokens).
- [ ] Uygulama arka plandayken bildirim **cihaza düşüyor**.
- [ ] Bildirime tıkla → app açılıyor → `/notifications` (caller-auth webhook canlı).
- [ ] Logout → token deactive.

## 8. Bayi Defteri (detay)
- [ ] Teslimat/tahsilat/iade/düzeltme kayıtları + bakiye doğru.
- [ ] Şoför kayıtları patron raporuna doğru yansıyor (driver_id atfı).
- [ ] Gün sonu plain-text paylaşım.

## 9. Hesap silme / KVKK
- [ ] Settings + Profil → "Hesabımı Sil" 2-aşamalı dialog ("HESABIMI SİL").
- [ ] Silme → çıkış + veri zinciri (cascade) temizleniyor.
- [ ] Şoför + davet-edilmiş kullanıcı dahil **tüm roller** silebiliyor (D-1).
- [ ] Privacy/Terms/Topluluk Kuralları ekranları açılıyor.

## 10. Crashlytics smoke (release/profile)
- [ ] Release/profile build'de collection açık (debug'da kapalı).
- [ ] Test crash tetikle (geçici test butonu veya `throw`) → Firebase Console
      Crashlytics'te **kayıt görünüyor** (~birkaç dk).
- [ ] Crash kaydında **PII/secret yok** (yalnız stack + cihaz tanılama; userId yok).
- [ ] Smoke sonrası test crash kodu kaldırıldı.

## 11. Quota / kota izleme (test süresince)
- [ ] **Storage:** medya yüklemeleri sonrası bucket boyutu izleniyor (free 1GB).
      Pick resize (maxWidth+q85) + 5MB cap (MediaLimits) ile büyüme sınırlı.
- [ ] **Edge function invoke:** her bildirim = 1 webhook; yoğunlukta Supabase
      free (~500K/ay) izlenir.
- [ ] **DB satır sayısı:** notifications / deliveries / feed büyümesi.
- [ ] **Push:** FCM ücretsiz; anormal hacim yok.

## 12. Genel UX / dayanıklılık
- [ ] Offline / ağ kesintisi: finansal ekranlar görünür hata + retry.
- [ ] Geri tuşu / navigation stack tutarlı.
- [ ] Empty state'ler yönlendirici; Türkçe metinler anlaşılır.
- [ ] UGC: engelleme / şikayet / içerik gizleme.
