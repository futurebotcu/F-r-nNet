# FırınNet — App Store Screenshot Checklist

> Windows'ta yalnız **plan** yapılabilir. Gerçek App Store screenshot'ları
> iOS simulator (Mac) veya gerçek iPhone/iPad gerektirir. Android/emulator
> görselleri yalnız kompozisyon taslağı için kullanılabilir, App Store'a
> yüklenmez.

## Gerekli Cihaz Boyutları (App Store Connect)
App Store, en az şu boyutlardan görsel ister (Apple zaman zaman günceller):
| Cihaz sınıfı | Çözünürlük (portrait) | Zorunlu mu |
|---|---|---|
| iPhone 6.9" / 6.7" (Pro Max sınıfı) | 1290×2796 / 1284×2778 | ✅ (en büyük iPhone zorunlu) |
| iPhone 6.5" | 1242×2688 | önerilir |
| iPhone 5.5" | 1242×2208 | (eski; çoğu durumda opsiyonel) |
| iPad Pro 12.9" (varsa iPad desteği) | 2048×2732 | iPad sunuluyorsa zorunlu |

> App **portrait** öncelikli (Info.plist tüm yönleri açık ama UI dikey tasarlanmış).
> Her dilde ayrı set gerekebilir; birincil dil tr.

## Çekilecek Ekranlar (öncelik sırası)
- [ ] 1. Auth / guest giriş — "FırınNet'e hoş geldin" + "Kayıtsız devam et"
- [ ] 2. Feed (akış) — birkaç post görünür
- [ ] 3. Story viewer / story row
- [ ] 4. Profil
- [ ] 5. Gruplar (Gruplar listesi)
- [ ] 6. Market (malzeme pazarı ilan listesi)
- [ ] 7. İş İlanları (Usta Arıyor)
- [ ] 8. Fırın Paneli (üretim/fire)
- [ ] 9. Bayi Defteri (teslimat/tahsilat/bakiye)
- [ ] 10. Reçete / hesaplama ekranı
- [ ] 11. Ayarlar / Hesap Silme

## Notlar
- İlk 1-3 görsel App Store'da en görünür olanlar → en güçlü ekranları seç
  (Feed + Bayi Defteri + Reçete hesaplama önerilir).
- Metin overlay/pazarlama şablonu opsiyonel; sade gerçek-ekran da kabul.
- Gerçek veri kullanılacaksa kişisel/üçüncü-taraf bilgi içermesin (demo seed).
- **Mac aşaması:** simulator'da `flutter run` → ekran görüntüsü, veya gerçek
  cihazda çekim. Windows'ta bu liste + kompozisyon kararları hazırlanır.
