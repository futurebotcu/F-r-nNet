# FırınNet Usability Gap Audit

## Genel verdict

FırınNet'in bayi defteri; bayi listeleme, arama/filtreleme, teslimat, iade,
tahsilat, düzeltme, not, gün sonu, dönem raporu, paylaşım ve bayi bazlı PDF
konularında closed beta için güçlü bir temel sunuyor.

Closed beta öncesi iki çekirdek boşluk kapatılmalı:

1. Eklenen bayi kaydı uygulama içinden düzenlenemiyor ve aktif/pasif durumu
   yönetilemiyor. Repository desteği bulunsa da kullanıcı yüzeyi yok.
2. Bayi defterine özel ürün ekleme/katalog yönetimi yok. Fiyat ve teslimat
   akışları sabit `AppProducts.defaults` listesine bağlı.

"Ürün" kavramı uygulamada üç ayrı anlama geliyor: üretim reçetesi, bayi
defteri satış kalemi ve Market ilanı. Reçete veya ilan oluşturmak, bayi
defterine satılabilir ürün eklemek anlamına gelmiyor. Bu ayrım ilk kullanımda
yeterince açıklanmıyor.

Fiyat kayıtları append-only çalışıyor: yeni fiyat yeni bir `validFrom` kaydı
olarak ekleniyor; eski hareketlerin `unitPrice` ve `lineTotal` değerleri
değiştirilmiyor. Bu sprintte fiyat davranışı, veri modeli ve hesaplama mantığı
değiştirilmedi. Önceki yarım çalışmadaki güvenli fiyat copy düzeltmesi korundu.

Mevcut çalışma durumu:

- `USABILITY_GAP_AUDIT.md` vardı, ancak `.gitignore` içindeki `/*_AUDIT.md`
  kuralı nedeniyle izlenmiyordu.
- Genel verdict ile P1/P2, bayi, ürün, fiyat, hareket, rapor, empty state,
  risk ve sprint sırası başlıkları vardı.
- P0 değerlendirmesi, bayi düzenleme/aktiflik, ürün kataloğu, tarih seçimi,
  form validasyonları, guest guard kapsamı ve rapor export ayrımı eksikti.
- "Raporlarda PDF yok" ifadesi fazla geneldi; bayi detayında hesap özeti PDF'i
  var, toplu rapor/gün sonu için dosya export'u yok.
- Önceki denemede audit ile açıkça ilişkilendirilebilen uygulama değişikliği
  `lib/core/constants/app_strings.dart` içindeki üç fiyat sheet metnidir.
- Worktree'de audit dışı çok sayıda önceden var olan değişiklik bulunduğu için
  bunlar bu sprintin değişikliği olarak değerlendirilmedi veya geri alınmadı.

## P0 Eksikler

Closed beta öncesi çözülmesi gerekenler:

| ID | Alan | Öncelik | Problem | Kullanıcı Etkisi | Önerilen Çözüm | Kod Değişikliği Gerekir mi? |
| --- | --- | --- | --- | --- | --- | --- |
| UX-01 | Bayi yönetimi | P0 | Bayi ekleme var; mevcut bayi için düzenleme, aktif/pasif değiştirme veya güvenli arşivleme yüzeyi yok. Repository'de `setActive` bulunmasına rağmen UI'dan erişilemiyor. | Yanlış ad, telefon, bölge veya not düzeltilemez; ayrılan bayi aktif listede kalır. Kullanıcı aynı bayiyi yeniden açarak mükerrer kayıt oluşturabilir. | Mevcut model ve repository sözleşmesini kullanan bayi düzenleme ve aktif/pasif aksiyonu için ayrı, dar kapsamlı sprint. Fiziksel silme yerine arşivleme tercih edilmeli. | Evet. Route/model/schema değiştirmeden yapılabilir; bu audit sprintinde yapılmadı. |
| UX-02 | Ürün ekleme | P0 | Bayi defterine özel ürün ekleme/katalog yönetimi yok; fiyat ve teslimat seçimi sabit `AppProducts.defaults` listesiyle sınırlı. Reçete ve Market ilanı bu ihtiyacı karşılamıyor. | Closed beta katılımcısı kendi ürününü seçemez; yanlış ürüne kayıt açabilir veya defteri kullanamaz. | Önce ürün sahipliği, birim, aktiflik ve fiyat kapsamını tanımlayan ayrı ürün-katalog keşif sprinti; ardından veri/model kararı. | Evet. Veri modeli gerektirebilir; bu sprintte kesinlikle yapılmamalı. |

## P1 Eksikler

Closed beta kalitesini artıracak önemli işler:

| ID | Alan | Öncelik | Problem | Kullanıcı Etkisi | Önerilen Çözüm | Kod Değişikliği Gerekir mi? |
| --- | --- | --- | --- | --- | --- | --- |
| UX-03 | Ürün kavramı | P1 | Reçete, bayi satış ürünü ve Market ilanı aynı "ürün ekleme" beklentisi altında kolayca karışıyor. | Kullanıcı doğru ekranı bulamaz veya yanlış kaydın satışta kullanılacağını sanır. | Ekran girişlerinde kısa kapsam metni: "üretim reçetesi", "bayiye satılan ürün/fiyat", "Market ilanı". | Evet, küçük copy işi. |
| UX-04 | Bayi formu | P1 | Yalnız bayi adı zorunlu. Telefon biçimi doğrulanmıyor; il/ilçe, iletişim kişisi ve çalışma tipi için neden gerekli oldukları açıklanmıyor. | Eksik veya hatalı iletişim bilgisi, filtreleme ve saha takibinde veri kalitesini düşürür. | Telefon için kullanıcı dostu biçim kontrolü; zorunlu/opsiyonel alanları görünür belirtme; çalışma tipi helper text'i. | Evet, form validasyonu/copy. |
| UX-05 | Fiyat görünürlüğü | P1 | Fiyat listesi geçmiş ve güncel kayıtları aynı görsel ağırlıkta gösteriyor; aynı ürünün tekrarları arasında "güncel" etiketi yok. | Kullanıcı hangi fiyatın şu an kullanılacağını yanlış okuyabilir. | Ürün bazında güncel kaydı işaretle; geçmişi ikincil göster. Hesaplama davranışını değiştirme. | Evet, yalnız sunum katmanı. Ayrı fiyat UX sprinti önerilir. |
| UX-06 | Fiyat geçerlilik tarihi | P1 | Yeni fiyatın `validFrom` değeri otomatik olarak kayıt anı; kullanıcı ileri tarihli veya gün başından geçerli fiyat seçemiyor. | Ertesi gün uygulanacak zam önceden girilemez; gün içinde saat bazlı kayıt iş beklentisiyle uyuşmayabilir. | Davranış kararı, timezone ve geçmiş hareket etkisi ayrı veri-risk sprintinde tanımlanmalı. | Evet, riskli veri davranışı; bu sprintte yapılmadı. |
| UX-07 | Hareket tarihi | P1 | Teslimat, iade, tahsilat ve düzeltme kayıtları `DateTime.now()` ile oluşuyor; işlem tarihi seçilemiyor. | Geç girilen saha hareketi yanlış güne düşer; gün sonu ve dönem raporu gerçeği yansıtmaz. | Geri tarih giriş kuralları ve gün sonu etkisini belirleyen ayrı hareket-tarihi sprinti. | Evet, hesaplama/rapor etkili; bu sprintte yapılmadı. |
| UX-08 | Hata telafisi | P1 | Hareket satırında düzenle/sil/geri al yok. "Düzeltme" var ancak hangi hatada nasıl kullanılacağı açıklanmıyor. | Yanlış ürün, miktar veya tahsilat girişinde kullanıcı bakiyeyi nasıl güvenle düzelteceğini bilemez. | Append-only düzeltme politikasını açıkla; neden zorunlu not istendiğini ve artı/eksi etkisini önizle. | Evet. Önce UX/politika, sonra kontrollü uygulama. |
| UX-09 | Toplu rapor export | P1 | Bayi bazlı hesap özeti PDF'i var; ancak Gün Sonu ve toplu Bayi Bazlı Rapor yalnız ekran/metin paylaşımı sunuyor. | Muhasebe, arşiv veya yönetici paylaşımı için toplu dosya üretilemez. | Gün sonu/toplu rapor için CSV veya PDF kapsamını ayrı raporlama sprintinde belirle. | Evet, ayrı sprint. |
| UX-10 | İlk kullanım | P1 | Ana yüzeyler işlevsel olsa da ilk bayi, ilk fiyat ve ilk hareket sırası bütün olarak anlatılmıyor. | İlk kez giren kullanıcı fiyat eklemeden teslimata geçebilir veya hangi CTA'nın başlangıç olduğunu anlayamaz. | Üç adımlı kısa başlangıç yönlendirmesi ve görev odaklı empty state copy'si. | Evet, küçük/orta UX işi. |
| UX-11 | Rol ve müşteri dili | P1 | "Bayi", "toptan müşteri", "fırıncı", "toptancı" ve bireysel kullanıcı kavramları farklı yüzeylerde kesişiyor. | Kullanıcı Bayi Defteri'nin kendi işletme rolüne ve müşteri tipine uygun olup olmadığını kestiremez. | Rol bazlı giriş metinlerini ve "bayi/toptan müşteri" terminolojisini tek sözlükte standardize et. | Evet, copy ve bilgi mimarisi incelemesi. |

## P2 Eksikler

Sonraya bırakılabilir:

| ID | Alan | Öncelik | Problem | Kullanıcı Etkisi | Önerilen Çözüm | Kod Değişikliği Gerekir mi? |
| --- | --- | --- | --- | --- | --- | --- |
| UX-12 | Toplu fiyat | P2 | Birden fazla bayi/ürün için toplu fiyat güncelleme yok. | Çok bayi ve ürün kullanan işletmede tekrar eden iş artar. | Tekil fiyat akışı doğrulandıktan sonra önizlemeli toplu güncelleme sprinti. | Evet, riskli ve ayrı sprint. |
| UX-13 | Hareket arama | P2 | Genel hareketlerde bayi adı ve tip filtresi var; ürün, not, tutar ve özel tarih aralığı yok. | Büyük defterde eski bir kaydı bulmak yavaşlar. | Gelişmiş hareket filtresi. | Evet. |
| UX-14 | Liste yoğunluğu | P2 | Uzun fiyat/hareket/rapor listelerinde özetleme ve daraltma sınırlı. | Veri büyüdükçe tarama ve karşılaştırma zorlaşır. | Ürün/tarih gruplama, daraltılabilir geçmiş ve sabit özet. | Evet. |
| UX-15 | Bayi notları | P2 | Not ekleme var; not düzenleme, silme, sabitleme veya arama yok. | Uzun süreli kullanımda eski ve önemli notlar karışır. | Not yaşam döngüsü için ayrı küçük sprint. | Evet. |

## Bayi Yönetimi

| ID | Alan | Öncelik | Problem | Kullanıcı Etkisi | Önerilen Çözüm | Kod Değişikliği Gerekir mi? |
| --- | --- | --- | --- | --- | --- | --- |
| BAY-01 | Ekleme | Uygun | "Bayi Ekle" CTA'sı ve tek sayfalı form anlaşılır; ad doğrulaması ve guest guard var. | İlk kayıt düşük adım sayısıyla tamamlanır. | Akışı koru; UX-04 validasyonlarını ayrıca ele al. | Hayır; P1 iyileştirme ayrı. |
| BAY-02 | Liste | Uygun | Liste; ad, bölge, kişi araması ile tümü/aktif/pasif/borçlu filtrelerini sunuyor. Bakiye ve son işlem kartta okunabiliyor. | Günlük bayi bulma ve borçlu tarama hızlıdır. | Mevcut yapıyı koru. | Hayır. |
| BAY-03 | Düzenleme/aktiflik | P0 | UX-01: kullanıcı yüzeyi yok. | Hatalı ve eski kayıt yönetilemez. | Bayi düzenleme ve arşivleme sprinti. | Evet. |
| BAY-04 | Detay | Uygun | Cari bakiye, dönem metrikleri, son ödeme, fiyatlar, işlem geçmişi ve notlar aynı detay yüzeyinde. | Bayinin güncel durumu tek yerden izlenebilir. | İlk kullanım açıklamasıyla destekle. | Küçük copy yeterli. |
| BAY-05 | Guest guard | Uygun | Bayi, fiyat, hareket ve not yazımlarında UI pre-check ve guarded repository savunması var. | Guest kullanıcı yanlışlıkla kalıcı yazım yapamaz; giriş CTA'sı görür. | Patrol 02 ile regresyonu sürdür. | Hayır. |

Bayi yönetimindeki en büyük üç eksik: düzenleme yok, aktif/pasif yönetimi yok,
form veri kalitesi kontrolleri zayıf.

## Ürün Ekleme

| ID | Alan | Öncelik | Problem | Kullanıcı Etkisi | Önerilen Çözüm | Kod Değişikliği Gerekir mi? |
| --- | --- | --- | --- | --- | --- | --- |
| URN-01 | Bayi defteri ürünü | P0 | UX-02: özel ürün/katalog ekleme yok. | Kullanıcının gerçek ürün gamı kaydedilemez. | Ayrı ürün-katalog keşif ve uygulama sprinti. | Evet, muhtemelen veri modeli. |
| URN-02 | Reçete | Uygun ama farklı kapsam | Yeni Reçete; ürün adı, gramaj, malzeme, yapılış, açıklama ve görünürlük toplar. Bu üretim bilgisidir, satış kataloğu değildir. | Kullanıcı reçetenin bayi teslimatında otomatik ürün olacağını sanabilir. | Giriş copy'sinde kapsamı açıkça belirt. | Küçük copy. |
| URN-03 | Market ilanı | Uygun ama farklı kapsam | İlan formu başlık, kategori, fiyat, birim, açıklama, konum ve iletişim toplar. Bu alım/satım ilanıdır. | "Ürün ekledim" beklentisi bayi defterine taşınabilir. | "Market ilanı" terminolojisini tutarlı kullan. | Küçük copy. |
| URN-04 | Validasyon | P1 | Market fiyat/birim alanlarının bir bölümü opsiyonel ve sayı biçimi geri bildirimi sınırlı; reçete formu uzun ve hesap odaklı. | Eksik ilan veya yarıda bırakılan reçete oluşabilir. | Form bazlı validasyon/copy audit'i ayrı yürüt. | Evet, ürün modeli değiştirmeden mümkün. |

Ürün eklemedeki en büyük üç eksik: bayi kataloğunun olmaması, üç ürün
kavramının karışması, satış ürünü için kategori/birim/açıklama sahipliğinin
tanımlanmamış olması.

## Fiyat Değişimi

| ID | Alan | Öncelik | Problem | Kullanıcı Etkisi | Önerilen Çözüm | Kod Değişikliği Gerekir mi? |
| --- | --- | --- | --- | --- | --- | --- |
| FIY-01 | Geçmiş veri | Doğrulandı | Fiyat satırı append-only ekleniyor; teslimat hareketi kendi `unitPrice` ve `lineTotal` değerini taşıyor. | Yeni fiyat eski hareket tutarlarını geriye dönük bozmaz. | Bu davranışı test ve kullanıcı copy'siyle koru. | Hayır. |
| FIY-02 | Güncel/geçmiş ayrımı | P1 | UX-05: liste bütün fiyat satırlarını gösteriyor, güncel etiketi yok. | Yanlış fiyat okunabilir. | Sunum katmanında güncel fiyatı öne çıkar. | Evet, küçük/orta UI. |
| FIY-03 | Fiyat kapsamı | P1 | Bayi fiyatı, Market ilan fiyatı ve gelecekteki olası katalog fiyatı arasında ilişki yok; fakat bu ayrım kullanıcıya açıklanmıyor. | Bir yüzeydeki fiyatın diğer yüzeyleri güncellediği sanılabilir. | Her fiyat yüzeyinde kapsam helper text'i. | Küçük copy. |
| FIY-04 | Geçerlilik | P1 | UX-06: tarih/saat kullanıcı tarafından seçilemiyor. | Planlı zam ve geçmiş tarihli düzeltme yapılamaz. | Ayrı fiyat veri davranışı sprinti. | Evet, riskli. |
| FIY-05 | Toplu güncelleme | P2 | UX-12: çoklu ürün/bayi fiyatı tek tek giriliyor. | Operasyon süresi uzar ve hata ihtimali artar. | Önizleme ve onay içeren ayrı sprint. | Evet, riskli. |

Fiyat değişimindeki en büyük üç risk: güncel fiyatın geçmişten ayırt
edilememesi, geçerlilik zamanının otomatik olması, bayi/Market/katalog fiyat
kapsamlarının karışması. Bu sprintte fiyat davranışı değiştirilmedi.

## Bayi Hareketleri

| ID | Alan | Öncelik | Problem | Kullanıcı Etkisi | Önerilen Çözüm | Kod Değişikliği Gerekir mi? |
| --- | --- | --- | --- | --- | --- | --- |
| HRK-01 | İşlem ayrımı | Uygun | Teslimat, iade, ödeme ve bakiye düzeltmesi ayrı CTA/form olarak sunuluyor. | İşlem niyeti temel düzeyde nettir. | Mevcut ayrımı koru. | Hayır. |
| HRK-02 | Formlar | Uygun/P1 | Ürün, miktar, birim fiyat, ödeme yöntemi ve not alanları bağlama göre gösteriliyor; pozitif tutar kontrolleri var. Tarih alanı yok. | Günlük giriş kolay, geç giriş güvenilmez. | UX-07 hareket tarihi sprinti. | Evet. |
| HRK-03 | Düzeltme | P1 | UX-08: artı/eksi düzeltme ve zorunlu not var; ancak bakiye etkisi önizlenmiyor ve yardım metni sınırlı. | Ters yönlü düzeltme ikinci bir hataya yol açabilir. | "Bakiye şu kadar artacak/azalacak" önizlemesi ve örnek copy. | Evet, hesaplama mantığını değiştirmeden UI'da yapılabilir. |
| HRK-04 | Silme | Bilinçli kısıt/P1 | Doğrudan silme veya edit yok. Finansal iz açısından güvenli, fakat politika görünür değil. | Kullanıcı kayıtların neden değiştirilemediğini anlayamaz. | Append-only politika ve düzeltme yönergesi. | Küçük copy; daha büyük undo işi ayrı. |
| HRK-05 | Bulma | Uygun/P2 | Genel hareketler bayi adı, tip ve tarih gruplarıyla taranabiliyor; ürün/tutar/not araması yok. | Küçük veri setinde yeterli, büyüdükçe yavaş. | UX-13 gelişmiş filtre. | Evet. |

## Gün Sonu / Raporlar

| ID | Alan | Öncelik | Problem | Kullanıcı Etkisi | Önerilen Çözüm | Kod Değişikliği Gerekir mi? |
| --- | --- | --- | --- | --- | --- | --- |
| RAP-01 | Bugün özeti | Uygun | Gün Sonu; teslimat, iade, tahsilat, net değişim, bayi bazlı dağılım ve son hareketleri gösteriyor. | "Bugün ne oldu?" sorusunu karşılıyor. | Mevcut metrikleri koru. | Hayır. |
| RAP-02 | Gün kapatma | Kapsam notu | Ekran pasif, query-driven özet; kasiyer tipi gün kapatma/lock/onay işlemi değil. | Kullanıcı "gün sonu alındı" şeklinde resmi kapanış beklerse yanlış beklenti oluşur. | Başlık altına "canlı günlük özet" kapsamı ekle veya resmi kapanış ihtiyacını ayrı keşfet. | Copy için küçük; kapanış özelliği büyük sprint. |
| RAP-03 | Boş durum | Uygun | Hareket yokken açıklayıcı empty state var. | Boş rapor hata gibi algılanmaz. | Paylaş CTA'sını boş durumda pasifleştirme ihtiyacını kullanıcı testiyle doğrula. | Muhtemelen küçük UI. |
| RAP-04 | Paylaşım/export | P1 | Gün Sonu metin paylaşır; bayi hesap özeti PDF üretir; toplu dönem raporu için PDF/CSV yok. | Bireysel bayi ekstresi alınabilir, toplu arşiv alınamaz. | UX-09 rapor export sprinti. | Evet. |
| RAP-05 | Tarih aralığı | Uygun | Bayi aralık raporunda hazır dönemler ve özel tarih aralığı bulunuyor; toplu rapor 7/30 gün/bu ay segmentleriyle sınırlı. | Bayi özelinde esnek, toplu analizde daha sınırlı. | Toplu özel tarih aralığını P2 olarak değerlendir. | Evet. |

## Empty State / Copy

| ID | Alan | Öncelik | Problem | Kullanıcı Etkisi | Önerilen Çözüm | Kod Değişikliği Gerekir mi? |
| --- | --- | --- | --- | --- | --- | --- |
| CPY-01 | Bayi boş durumu | Uygun | İlk bayi ekleme CTA'sı görev odaklı. | Kullanıcı başlangıç aksiyonunu görür. | Korunmalı. | Hayır. |
| CPY-02 | Hareket/rapor boş durumu | Uygun | Hareket, filtre sonucu, gün sonu ve dönem raporu için ayrı metinler var. | "Veri yok" ile "filtre sonucu yok" ayrılır. | Korunmalı. | Hayır. |
| CPY-03 | Fiyat boş durumu | P1 | Fiyat yok mesajı mevcut, ancak ilk fiyatın teslimat birim fiyatını nasıl etkilediğini anlatmıyor. | Kullanıcı fiyat eklemeden teslimata geçebilir veya manuel fiyatın rolünü anlamaz. | Tek cümle helper text ve net CTA. | Evet, küçük copy. |
| CPY-04 | Teknik hatalar | P1 | Birçok yazma hatası kullanıcı dostu Türkçe; bazı yükleme yüzeylerinde `Fiyat: $e`, `Bakiye: $e`, `Bayi: $e` gibi ham hata metni gösteriliyor. | Teknik exception ayrıntısı kullanıcıya sızabilir ve çözüm sunmaz. | Ortak, eylem odaklı yükleme hata metni ve tekrar dene aksiyonu. | Evet, küçük UI/copy. |
| CPY-05 | Ana CTA | P1 | "Ürün Ver" saha diline yakın; "Fiyat ekle" güncelleme davranışını tam anlatmıyordu. Önceki fix bunu "Geçerli fiyat ekle" yaptı. | Fiyat geçmişinin korunacağı daha net anlaşılır. | Mevcut güvenli copy düzeltmesini koru. | Uygulandı; davranış değişmedi. |

## Riskli Alanlar

| ID | Alan | Öncelik | Problem | Kullanıcı Etkisi | Önerilen Çözüm | Kod Değişikliği Gerekir mi? |
| --- | --- | --- | --- | --- | --- | --- |
| RSK-01 | Ürün sahipliği | P0 | Bayi ürünü için kaynak, kategori, birim, aktiflik ve fiyat kapsamı tanımlı değil. | Yanlış model seçimi ileride hareket ve fiyat geçmişini bölebilir. | Koddan önce domain/model keşfi. | Evet; ayrı sprint. |
| RSK-02 | Fiyat zamanı | P1 | `validFrom`, timezone, ileri/geri tarih ve aynı gün çoklu fiyat kuralları kullanıcı sözleşmesine dönüşmemiş. | Rapor ve teslimat fiyatı beklenmedik olabilir. | Karar tablosu, test senaryoları ve migration gereksinimi analizi. | Evet; bu audit dışında. |
| RSK-03 | Hareket bütünlüğü | P1 | Silme yerine düzeltme yaklaşımı doğru yönde, ancak kullanıcı yönergesi ve audit trail görünürlüğü zayıf. | Hatalı düzeltme veya destek ihtiyacı artar. | Append-only hareket politikası sprinti. | Evet. |
| RSK-04 | Pasif bayi borcu | P1 | Borçlu filtresi yalnız aktif ve pozitif bakiyeli bayileri sayıyor; pasif borçlu yalnız pasif filtresinden bulunuyor. | Pasife alınan borçlu toplam takipten gözden kaçabilir. | Aktiflik özelliği eklenirken "pasif borçlu" görünürlüğünü ürün kararıyla netleştir. Hesaplamayı bu sprintte değiştirme. | Evet, ayrı sprint. |
| RSK-05 | Kirli worktree | Süreç riski | Audit başlangıcında çok sayıda uygulama/test dosyası zaten değişmişti. | Test sonucu yalnız audit değişikliğini izole etmeyebilir; yanlış dosyaların commit'e alınma riski vardır. | Commit'e sadece audit dosyası ve açıkça audit kaynaklı fiyat copy satırlarını al. | Git işlemi gerekir. |

## Önerilen Sprint Sırası

1. **Closed beta P0: Bayi düzenleme ve aktif/pasif yönetimi.** Mevcut
   repository sözleşmesini kullan; fiziksel silme ekleme.
2. **Closed beta P0: Bayi ürün kataloğu keşfi.** Kod yazmadan önce ürün
   sahipliği, birim, kategori, aktiflik ve fiyat kapsamını karara bağla.
3. **Fiyat güvenliği sprinti.** Güncel/geçmiş görünümü, geçerlilik zamanı,
   aynı gün fiyatı ve kapsam metinlerini test senaryolarıyla netleştir.
4. **Hareket güvenliği sprinti.** İşlem tarihi, düzeltme önizlemesi ve
   append-only hata telafisi politikasını ele al.
5. **Raporlama sprinti.** Toplu gün sonu/dönem PDF veya CSV export'u.
6. **Copy ve onboarding sprinti.** Reçete/bayi ürünü/Market ilanı ayrımı,
   rol terminolojisi, teknik hata ve görev odaklı empty state iyileştirmeleri.

Önerilen sonraki sprint: **Bayi Düzenleme ve Aktif/Pasif Yönetimi P0
Sprinti**. Ürün kataloğu bundan hemen sonra gelmeli; ürün/fiyat modeli kararı
aynı sprint içine sıkıştırılmamalı.

Bu audit sprintinde uygulanan tek küçük fix, önceki yarım çalışmadan korunan
fiyat sheet copy değişikliğidir:

- `Fiyat ekle / güncelle` → `Geçerli fiyat ekle`
- `Fiyatı kaydet` → `Kaydet` (dar sheet/test düzeninde taşma yaratmaması için)
- Eski fiyatın geçmişte kalacağı ve yeni kaydın yalnız sonraki işlemlerde
  geçerli olacağı açıklaması

Uygulama davranışı, route/navigation, veri modeli, Supabase schema/RLS,
migration, repository sözleşmesi ve borç/alacak hesaplama mantığı değişmedi.
