# FirinNet Release QA Test Matrix

Bu matris, her build sonrasinda uygulamanin acildigini, ana tablarin
calistigini ve temel guest akislarinin bozulmadigini dogrulamak icin kullanilir.

Patrol ana P0 E2E smoke otomasyonudur. Maestro ayni akisi ek sinyal olarak
calistiran advisory hattir; Windows native driver/gRPC sonucu release
kararini tek basina bloke etmez.

Oncelik tanimlari:

- **P0:** Release blocker. Basarisizsa release durdurulur.
- **P1:** Onemli. Release karari verilmeden degerlendirilir.
- **P2:** Sonraki asamada derinlestirilecek kapsam.

| ID | Alan | Öncelik | Tür | Ön Koşul | Adımlar | Beklenen Sonuç | Otomasyon | Durum |
|---|---|---|---|---|---|---|---|---|
| BOOT-001 | App boot / splash | P0 | Smoke | Android emulator hazir | Uygulamayi baslat | Uygulama crash olmadan acilir ve splash gorunur | Patrol; Maestro advisory | Otomatik |
| BOOT-002 | App boot / splash | P0 | Smoke | Temiz app data | Splash sonrasini bekle; `Kayıtsız devam et` sec | Feed ekrani gorunur | Patrol; Maestro advisory | Otomatik |
| FEED-001 | Feed | P0 | Smoke | Feed acik | Header ve feed icerigini kontrol et | `FırınNet` basligi gorunur | Patrol; Maestro advisory | Otomatik |
| NAV-001 | Bottom navigation | P0 | Smoke | Feed acik | Alt navigasyonu kontrol et | Feed, Gruplar, Market, İlanlar ve Panel etiketleri gorunur | Patrol; Maestro advisory | Otomatik |
| GROUP-001 | Gruplar | P0 | Smoke | Ana shell acik | Gruplar tabina dokun | `Sektör Grupları` ekrani gorunur | Patrol; Maestro advisory | Otomatik |
| MARKET-001 | Market | P0 | Smoke | Ana shell acik | Market tabina dokun | `Market` ekrani gorunur | Patrol; Maestro advisory | Otomatik |
| JOBS-001 | İş İlanları | P0 | Smoke | Ana shell acik | İlanlar tabina dokun | `İş İlanları` ekrani gorunur | Patrol; Maestro advisory | Otomatik |
| PANEL-001 | Panel | P0 | Smoke | Ana shell acik | Panel tabina dokun | `Panel` veya `Merhaba` basligi gorunur | Patrol; Maestro advisory | Otomatik |
| NAV-002 | Bottom navigation | P0 | Smoke | Panel acik | Feed tabina dokun | Feed yeniden acilir ve `FırınNet` gorunur | Patrol; Maestro advisory | Otomatik |
| COMPOSER-001 | Inline composer | P0 | Smoke | Feed acik | Feed ust icerigini kontrol et | `Bugün ne paylaşmak istersin?` inline composer metni gorunur | Patrol 01 + 02; Maestro advisory | Otomatik |
| MARKET-002 | Empty states | P0 | Regression | Local guest mod; Market verisi bos | Market tabini ac | Empty state ve `İlk ilanı oluştur` CTA gorunur | Patrol 02 | Otomatik |
| JOBS-002 | Empty states | P0 | Regression | Local guest mod; is ilani verisi bos | İlanlar tabini ac; iki segmenti kontrol et | Her iki segmentin empty state mesaji gorunur; ekran crash etmez | Patrol 02 | Otomatik |
| GUARD-001 | Guest guard | P0 | Regression | Guest mod; Feed acik | Inline composer `Paylaş` aksiyonuna dokun | Login/guest guard acilir; composer route'una izinsiz gecilmez | Patrol 02 + Flutter test | Otomatik |
| PROFILE-001 | Profile/avatar | P0 | Smoke | Guest mod; Feed acik | Header avatarina dokun; guest fallback'i kontrol et; Feed'e don | Profil fallback akisi crash olmadan auth entry'ye gider ve Feed'e donulebilir | Patrol 02 | Otomatik |
| NAV-003 | Regression smoke | P0 | Soak smoke | Guest mod | Feed > Gruplar > Market > İlanlar > Panel > Feed gecislerini yap | Temel navigasyonda exception, donma veya crash olmaz | Patrol; Maestro advisory | Otomatik |
| GOLDEN-001 | Feed | P1 | Visual regression | Pinned Flutter/Windows golden ortami | Feed baseline ile render sonucunu karsilastir | Header, segment, inline composer, post karti ve bottom nav degismez | Flutter golden | Otomatik |
| GOLDEN-002 | Gruplar | P1 | Visual regression | Pinned Flutter/Windows golden ortami | Gruplar baseline ile render sonucunu karsilastir | Header, arama, filtre chipleri, grup kartlari ve bottom nav degismez | Flutter golden | Otomatik |
| GOLDEN-003 | Market | P1 | Visual regression | Guest/local bos Market | Market empty baseline ile render sonucunu karsilastir | Baslik, kategori chipleri, empty state, CTA ve bottom nav degismez | Flutter golden | Otomatik |
| GOLDEN-004 | İş İlanları | P1 | Visual regression | Guest/local bos ilan verisi | Is Ilanlari empty baseline ile render sonucunu karsilastir | Baslik, segmentler, empty state ve bottom nav degismez | Flutter golden | Otomatik |
| GOLDEN-005 | Panel | P1 | Visual regression | Guest profil | Panel baseline ile render sonucunu karsilastir | Misafir header, rol alani, sektor kartlari ve bottom nav degismez | Flutter golden | Otomatik |
| FEED-002 | Feed | P1 | Regression | Feed acik | Pull-to-refresh yap | Loading tamamlanir; feed kullanilabilir kalir | Manuel | Bekliyor |
| FEED-003 | Feed | P1 | Regression | Feed verisi bos | Feed ac | Feed empty state anlamli metinle gorunur | Flutter widget/manual | Kosullu |
| GROUP-002 | Gruplar | P1 | Regression | Guest mod | Grup olusturma aksiyonuna dokun | Guest guard gorunur | Flutter test/manual | Kismi |
| GROUP-003 | Gruplar | P1 | Smoke | Gruplar acik | Arama alanina metin gir; temizle | Liste filtrelenir ve ekran crash etmez | Manuel | Bekliyor |
| GROUP-004 | Gruplar | P1 | Regression | Guest mod; Gruplar acik | Bir public grup kartinda `Katıl` aksiyonuna dokun | Guest guard gorunur; gercek uyelik olusmaz | Patrol 03 | Otomatik |
| MARKET-003 | Market | P1 | Regression | Market acik | Filtreleri ac; bir filtre sec; temizle | Filtre durumu ve liste tutarli kalir | Flutter test/manual | Kismi |
| MARKET-004 | Market | P1 | Regression | Guest mod; Market bos | `İlk ilanı oluştur` CTA'sina dokun | Guest guard gorunur; ilan formuna izinsiz gecilmez | Patrol 03 | Otomatik |
| JOBS-003 | İş İlanları | P1 | Regression | İlanlar acik | Usta Arıyor ve İş Arıyor segmentleri arasinda gec | Her iki segment acilir; ekran crash etmez | Flutter test/manual | Kismi |
| JOBS-004 | İş İlanları | P1 | Regression | Guest mod; İlanlar acik | Header create aksiyonuna dokun | Guest guard gorunur; ilan formuna izinsiz gecilmez | Patrol 03 | Otomatik |
| PANEL-002 | Panel | P1 | Smoke | Guest mod | Panel tabini ac; ilk kullanilabilir karta dokun | Kart dogru ekrana gider veya kontrollu bilgi verir | Manuel | Bekliyor |
| COMPOSER-002 | Inline composer | P1 | Regression | Guest mod; Feed acik | Inline composer yazma aksiyonuna dokun | Guest guard gorunur; composer'a izinsiz gecilmez | Patrol 02 + Flutter test | Otomatik |
| PROFILE-002 | Profile/avatar | P1 | Regression | Auth kullanici | Avatar aksiyonuna dokun | Kullanicinin public profil rotasi acilir | Flutter test/manual | Kismi |
| SETTINGS-001 | Profile/settings | P1 | Smoke | Guest mod; Feed acik | Avatar aksiyonuna dokun | Guest profile/settings fallback auth entry'yi crash olmadan acar | Patrol 03 | Otomatik |
| LEGAL-001 | Settings/legal | P1 | Smoke | Guest profile fallback acik | Kullanim Sartlari ve Gizlilik Politikasi ekranlarini ac; geri don | Iki legal ekran acilir; geri navigasyon calisir | Patrol 03 | Otomatik |
| REG-001 | Regression smoke | P1 | Static | Repo hazir | `flutter analyze` calistir | Analyzer issue raporlamaz | PowerShell | Otomatik |
| REG-002 | Regression smoke | P1 | Automated | Repo hazir | `flutter test` calistir | Tum Flutter testleri gecer | PowerShell | Otomatik |
| REG-003 | Regression smoke | P2 | Build | Android toolchain hazir | Debug APK build et | APK basariyla uretilir | PowerShell | Otomatik |
| DEEP-001 | Future deeper flows | P2 | E2E | Test hesabi ve Supabase test ortami | Login, profil tamamlama ve logout akisini calistir | Oturum ve profil durumlari tutarli kalir | Gelecek Patrol | Planli |
| DEEP-002 | Future deeper flows | P2 | E2E | Auth kullanici | Feed post olustur, duzenle ve sil | CRUD ve feed refresh tutarli calisir | Gelecek Patrol | Planli |
| DEEP-003 | Future deeper flows | P2 | E2E | Auth kullanici ve grup | Gruba katil, mesaj yaz, ayril | Yetki ve uyelik davranisi dogru calisir | Gelecek Patrol | Planli |
| DEEP-004 | Future deeper flows | P2 | E2E | Auth ticari kullanici | Market ilani olustur, duzenle ve pasife al | Ilan yasam dongusu tutarli calisir | Gelecek Patrol | Planli |
| DEEP-005 | Future deeper flows | P2 | E2E | Uygun roller | Is ilani olustur ve mesajlasma baslat | Rol guard ve mesajlasma akisi dogru calisir | Gelecek Patrol | Planli |

## Release Karari

Release adayi icin tum P0 senaryolari gecmelidir. Kosullu veri senaryolari
(Market ve Is Ilanlari empty state gibi) uygun fixture veya bos test ortami
hazir oldugunda ayrica calistirilir.
