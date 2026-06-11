# FırınNet Feed Boundary Audit

Tarih: 2026-06-11 · Sprint: Feed Boundary & Monetization Redirect Filter V1 · Commit: `feat(feed): guide restricted posts to proper listing sections`

## Feed'in Amacı

Feed = sektör sohbeti, bilgi paylaşımı, gündem, deneyim, foto/video, soru-cevap, topluluk. Feed ≠ ilan panosu / reklam panosu / satış panosu. Bu kural hem ürün kalitesi (Feed'in keyifli kalması) hem monetizasyon hedefi (ilanların ücretlendirilebilir özel alanlarda toplanması) içindir.

## Feed'de Engellenecek / Yönlendirilecek İçerikler

| Kategori | Sinyal örnekleri | Davranış | Hedef |
|---|---|---|---|
| profanity | siktir, amk, orospu, şerefsiz... (yalnız tartışmasız token'lar) | Yayın durdurulur, "yumuşatalım" sheet'i | Metni düzenle |
| scamOrIllegal | kaçak ürün, sahte belge/fatura, yasa dışı | Yayın durdurulur, sakin güvenlik açıklaması | Metni düzenle |
| commercialAd | fiyat listesi, sipariş için, toptan satış, ürünlerimiz, dm'den ulaş, kampanya/indirim* | Yönlendirme sheet'i | Pazar (`/market`) |
| jobAd (işveren) | (eleman/usta/personel/işçi/çırak/tezgahtar/kalfa...) + (aranıyor/alınacak/arıyoruz) [+ maaş/yatılı/sigortalı] | Yönlendirme | İş ilanı formu (`jobOfferNew`) |
| jobSeek (iş arayan) | iş arıyorum, çalışmak istiyorum | YUMUŞAK yönlendirme | İş Arıyorum formu (`jobSeekNew`) |
| workplaceSale | fırın satılık, devren satılık, işyeri/dükkan devri, komple satılık | Yönlendirme | İlan formu (`marketListingNew`; bakery_transfer preselect P1) |
| equipmentSale | (makine/mikser/kazan/tezgah/ekipman...) + (satılık/satıyorum/devren) | Yönlendirme | İlan formu (`marketListingNew`; equipment_sale preselect P1) |

\* kampanya/indirim ZAYIF token: soru/tartışma işaretiyle birlikteyse serbest ("İndirim yapsam mı sizce?" → izinli).

## Normal İzin Verilen Örnekler (testle kilitli)

"Eleman bulmak artık çok zor" · "Hamur makinesi alırken nelere dikkat ediyorsunuz?" · "Un fiyatları arttı, siz ne yapıyorsunuz?" · "Yeni fırınımızda ilk günümüz" · "Makinem bozuldu, çözüm önerisi var mı?" · "Usta bulamıyoruz, siz nasıl çözüyorsunuz?" · görsel/deneyim paylaşımı · yalnız-medya post (boş text). Domain ismi (makine, eleman, fırın...) TEK BAŞINA asla sinyal değildir; niyet kalıbı (satılık/aranıyor/sipariş...) şarttır. İsim+niyet eşleşse bile soru/sohbet bağlamı ("usta arıyoruz ama bulamıyoruz, siz nasıl çözüyorsunuz?") izinlidir.

## Monetization Gerekçesi

İşçi ilanları, işyeri satış/devri, ekipman satışı ve ticari reklamlar ileride ücretlendirilecek/özel alanlarda sunulacak. Feed'de ücretsiz dolaşmaları hem bu modeli baltalar hem Feed kalitesini düşürür. V1 yönlendirme katmanı bu sınırı şimdiden ürün davranışı olarak kurar; paywall/entitlement YOK (aşağıda not).

## Popup / Copy Yaklaşımı

`showFeedBoundarySheet` (premium bottom sheet): ikon + başlık + açıklama + "Neden Feed'de değil?" kutusu + doğru alan CTA + "Metni düzenle" + "Vazgeç". Kaba "yasak" dili YOK; copy'ler spec'ten birebir (testle kilitli). Composer metni hiçbir durumda silinmez; CTA push olduğu için kullanıcı geri dönünce taslağı yerinde bulur. Yorumlarda sheet yerine kısa banner (`boundaryCommentBlocked`).

## Feed Post vs Comment vs Group Farkı

- **Feed post (composer):** tam kural seti — güvenlik + 5 ticari/ilan kategorisi, yönlendirme sheet'i. Auth guard'dan SONRA çalışır (guest önce AuthRequiredSheet; çakışma yok — source-contract testli).
- **Yorum:** DAR kural — yalnız profanity/scam/link'li bariz reklam engellenir (banner). Ticari yönlendirme yorumlarda V1'de YOK (bağlam sohbet; agresif davranılmaz).
- **Grup mesajı:** V1'de classifier UYGULANMADI (bilinçli) — grup bağlamında ticari konuşma meşru olabilir (örn. alım-satım grubu); profanity zaten UGC report/block ile kapsanıyor. Grup composer'a dar güvenlik guard'ı **P1**.

## Teknik

`lib/features/feed/services/feed_boundary_classifier.dart` — saf Dart, deterministik, AI yok, dependency yok. Türkçe-güvenli normalize (İ/I), kelime-sınırlı profanity eşleşmesi (götürü/fiziksel false-positive guard'lı, testli). Çıktı: allowed/category/confidence/destination/reason. Confidence politikası: high → durdur/yönlendir; medium → ticari-ilan kategorilerinde yönlendir, soru-tartışma işaretli belirsiz sohbette izin; low → izin.

## P0 (karşılandı)

- [x] Net reklam/ilan/satış/işçi-arama/işyeri-satışı yönlendirilir
- [x] Normal sohbet/soru/deneyim engellenmez (11 örnek testle kilitli)
- [x] Küfür/scam yayınlanmaz, kibarca düzenlemeye yönlendirilir
- [x] Metin korunur, post oluşturulmaz, guest guard çakışmaz
- [x] Yorum dar güvenlik guard'ı

## Gerçekçilik Modeli (V1.1 sertleştirme sonrası)

**Dürüst tespit:** kararlı bir kullanıcı HER client-side sözcük filtresini aşar — bu kabul edilmiş bir kısıttır, hedef değildir. Katmanlı savunma:

1. **Composer guard (bu katman) = dürüst kullanıcı yönlendirmesi.** Kullanıcıların büyük çoğunluğu kasıtlı atlatmaz; doğru alana nazikçe itmek ürün/monetizasyon hedefinin büyük kısmını karşılar.
2. **Kasıtlı atlatma = report/block + moderasyon kuyruğu** (UGC Safety V1, canlı). Feed'e sızan ilan/reklam topluluk tarafından şikayet edilir, kuyruğa düşer.
3. **Server-side enforcement P1:** aynı classifier'ın Edge Function olarak insert path'inde koşması client bypass'ını kapatır. N-report → otomatik gizleme eşiği P2.

**V1.1'de eklenen ucuz-numara dirençleri** (hepsi saha kanıtlı bypass'lardan, birebir regresyon testli):
- ASCII-fold + **leet-map** (s1kt1r, ar@nıyor) + **tekrar harf sıkıştırma** (aranııııyor)
- **Parça birleştirme** ("s-keym" → "skeym"; yalnız küfür kontrolünde — "iş" gibi legit kısa kelimeler bozulmaz)
- **Sesli-harf iskeleti** (skeym→skym) — "sektör"→sktr çakışması ağır-sesli-düşürme şartıyla (uzunluk farkı ≤1) guard'lı
- **Edit-distance ≤1 fuzzy** kritik niyet kelimelerinde (aranyor/aranıyo/satlik) — varyant listesi yarışı kapandı; "arıyorum"(arayan)/"arıyoruz"(işveren) tek harf farkı, jobSeek kontrolünün öne alınmasıyla korunur
- **Çıplak satış niyeti → Pazar** ("satilik araba" gibi domain-dışı satışlar); soru bağlamı ("satılık mikser arıyorum, öneri?") alıcı sayılır, izinli

## P1

- **Server-side classifier (Edge Function)** — kasıtlı bypass'ın gerçek kapanışı; client guard yalnız UX katmanı
- Market form deep-preselect (`listing_type=bakery_transfer|equipment_sale` query param) — şu an form genel açılıyor
- Grup composer'a dar profanity guard'ı
- Sinyal listelerinin saha verisiyle beslenmesi (rapor edilen kaçaklar regresyon test + sinyal olarak eklenir — bu sprintte 4 saha bypass'ı böyle kapatıldı)
- Kelime yakınlığı (noun↔intent mesafe) — şu an aynı-metin eşleşmesi

## P2 / Future Paywall Notu

- Classifier sinyalleri server-side da koşulabilir (Edge Function) — client bypass koruması
- Entitlement modeli: `market_listings`/`job_offer_posts` oluşturma sayısı/etkin süre ücretlendirmesi; boundary redirect'i o gün paywall'un huni girişi olur
- Telemetri: hangi kategori ne sıklıkla tetikleniyor (redirect → form tamamlama dönüşümü)
