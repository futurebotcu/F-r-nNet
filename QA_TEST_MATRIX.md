# FirinNet Release QA Test Matrix

Bu matris, her build sonrasinda uygulamanin acildigini, ana tablarin
calistigini ve temel guest akislarinin bozulmadigini dogrulamak icin kullanilir.

Oncelik tanimlari:

- **P0:** Release blocker. Basarisizsa release durdurulur.
- **P1:** Onemli. Release karari verilmeden degerlendirilir.
- **P2:** Sonraki asamada derinlestirilecek kapsam.

| ID | Alan | Öncelik | Tür | Ön Koşul | Adımlar | Beklenen Sonuç | Otomasyon | Durum |
|---|---|---|---|---|---|---|---|---|
| BOOT-001 | App boot / splash | P0 | Smoke | Debug APK kurulu | Uygulamayi baslat | Uygulama crash olmadan acilir ve splash gorunur | Maestro | Otomatik |
| BOOT-002 | App boot / splash | P0 | Smoke | Guest oturumu hazir veya auth ekraninda guest secilebilir | Splash sonrasini bekle; gerekirse `Kayıtsız devam et` sec | Feed ekrani gorunur | Maestro | Otomatik |
| FEED-001 | Feed | P0 | Smoke | Feed acik | Header ve feed icerigini kontrol et | `FırınNet` basligi gorunur | Maestro | Otomatik |
| NAV-001 | Bottom navigation | P0 | Smoke | Feed acik | Alt navigasyonu kontrol et | Feed, Gruplar, Market, İlanlar ve Panel etiketleri gorunur | Maestro | Otomatik |
| GROUP-001 | Gruplar | P0 | Smoke | Ana shell acik | Gruplar tabina dokun | `Sektör Grupları` ekrani gorunur | Maestro | Otomatik |
| MARKET-001 | Market | P0 | Smoke | Ana shell acik | Market tabina dokun | `Market` ekrani gorunur | Maestro | Otomatik |
| JOBS-001 | İş İlanları | P0 | Smoke | Ana shell acik | İlanlar tabina dokun | `İş İlanları` ekrani gorunur | Maestro | Otomatik |
| PANEL-001 | Panel | P0 | Smoke | Ana shell acik | Panel tabina dokun | `Panel` veya `Merhaba` basligi gorunur | Maestro | Otomatik |
| NAV-002 | Bottom navigation | P0 | Smoke | Panel acik | Feed tabina dokun | Feed yeniden acilir ve `FırınNet` gorunur | Maestro | Otomatik |
| COMPOSER-001 | Inline composer | P0 | Smoke | Feed acik | Feed ust icerigini kontrol et | `Bugün ne paylaşmak istersin?` inline composer metni gorunur | Maestro | Otomatik |
| MARKET-002 | Empty states | P0 | Regression | Market verisi bos | Market tabini ac | Empty state ve `İlk ilanı oluştur` CTA gorunur | Flutter widget/manual | Kosullu |
| JOBS-002 | Empty states | P0 | Regression | Is ilani verisi bos | İlanlar tabini ac | Uygun bos durum mesaji gorunur; ekran crash etmez | Flutter widget/manual | Kosullu |
| GUARD-001 | Guest guard | P0 | Regression | Guest mod; yazma aksiyonu mevcut | Market veya ilan ekleme aksiyonuna dokun | Login/guest guard acilir; yazma ekranina izinsiz gecilmez | Flutter test | Otomatik |
| PROFILE-001 | Profile/avatar | P0 | Smoke | Feed acik | Header avatarina dokun; geri don | Profil veya guest profil akisi crash olmadan acilir | Manuel | Bekliyor |
| NAV-003 | Regression smoke | P0 | Soak smoke | Guest mod | Feed > Gruplar > Market > İlanlar > Panel > Feed gecislerini yap | Temel navigasyonda exception, donma veya crash olmaz | Maestro | Otomatik |
| FEED-002 | Feed | P1 | Regression | Feed acik | Pull-to-refresh yap | Loading tamamlanir; feed kullanilabilir kalir | Manuel | Bekliyor |
| FEED-003 | Feed | P1 | Regression | Feed verisi bos | Feed ac | Feed empty state anlamli metinle gorunur | Flutter widget/manual | Kosullu |
| GROUP-002 | Gruplar | P1 | Regression | Guest mod | Grup olusturma aksiyonuna dokun | Guest guard gorunur | Flutter test/manual | Kismi |
| GROUP-003 | Gruplar | P1 | Smoke | Gruplar acik | Arama alanina metin gir; temizle | Liste filtrelenir ve ekran crash etmez | Manuel | Bekliyor |
| MARKET-003 | Market | P1 | Regression | Market acik | Filtreleri ac; bir filtre sec; temizle | Filtre durumu ve liste tutarli kalir | Flutter test/manual | Kismi |
| JOBS-003 | İş İlanları | P1 | Regression | İlanlar acik | Usta Arıyor ve İş Arıyor segmentleri arasinda gec | Her iki segment acilir; ekran crash etmez | Flutter test/manual | Kismi |
| PANEL-002 | Panel | P1 | Smoke | Guest mod | Panel tabini ac; ilk kullanilabilir karta dokun | Kart dogru ekrana gider veya kontrollu bilgi verir | Manuel | Bekliyor |
| COMPOSER-002 | Inline composer | P1 | Regression | Guest mod; Feed acik | Inline composer ana alanina dokun | Guest guard gorunur; composer'a izinsiz gecilmez | Flutter test | Otomatik |
| PROFILE-002 | Profile/avatar | P1 | Regression | Auth kullanici | Avatar aksiyonuna dokun | Kullanicinin public profil rotasi acilir | Flutter test/manual | Kismi |
| LEGAL-001 | Settings/legal | P1 | Smoke | Ayarlar ekranina erisim | Kosullar ve Gizlilik ekranlarini ac | Metinler gorunur; geri navigasyon calisir | Manuel | Bekliyor |
| REG-001 | Regression smoke | P1 | Static | Repo hazir | `flutter analyze` calistir | Analyzer issue raporlamaz | PowerShell | Otomatik |
| REG-002 | Regression smoke | P1 | Automated | Repo hazir | `flutter test` calistir | Tum Flutter testleri gecer | PowerShell | Otomatik |
| REG-003 | Regression smoke | P2 | Build | Android toolchain hazir | Debug APK build et | APK basariyla uretilir | PowerShell | Otomatik |
| DEEP-001 | Future deeper flows | P2 | E2E | Test hesabi ve Supabase test ortami | Login, profil tamamlama ve logout akisini calistir | Oturum ve profil durumlari tutarli kalir | Gelecek Maestro | Planli |
| DEEP-002 | Future deeper flows | P2 | E2E | Auth kullanici | Feed post olustur, duzenle ve sil | CRUD ve feed refresh tutarli calisir | Gelecek Maestro | Planli |
| DEEP-003 | Future deeper flows | P2 | E2E | Auth kullanici ve grup | Gruba katil, mesaj yaz, ayril | Yetki ve uyelik davranisi dogru calisir | Gelecek Maestro | Planli |
| DEEP-004 | Future deeper flows | P2 | E2E | Auth ticari kullanici | Market ilani olustur, duzenle ve pasife al | Ilan yasam dongusu tutarli calisir | Gelecek Maestro | Planli |
| DEEP-005 | Future deeper flows | P2 | E2E | Uygun roller | Is ilani olustur ve mesajlasma baslat | Rol guard ve mesajlasma akisi dogru calisir | Gelecek Maestro | Planli |

## Release Karari

Release adayi icin tum P0 senaryolari gecmelidir. Kosullu veri senaryolari
(Market ve Is Ilanlari empty state gibi) uygun fixture veya bos test ortami
hazir oldugunda ayrica calistirilir.
