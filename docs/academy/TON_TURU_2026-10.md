# FırınNet Akademi — Ton ve Konu Turu (Ekim 2026)

Amaç: bilimsel doğruluğu ve kaynak guard'larını koruyarak akışı "fırıncı
Wikipedia'sı"ndan, fırıncının günlük işine yarayan kısa ve doğal içeriğe
çevirmek.

## Değişen dosyalar

| Dosya | Ne değişti |
|---|---|
| `supabase/functions/academy-worker/lib.ts` | `buildDraftPrompt` yeniden yazıldı (dil, yapı, başlık, "bu bana ne kazandırır", açılış çeşitliliği, seri). Şemaya `payoff`, `payoff_kind`, `angle`, `series`. `editorialQuality` ton kapısı: jargon (3+ bloker), jargonlu başlık bloker, uzun cümle / tarih-kurum açılışı / aynı açılış uyarısı, `no_payoff` (üretim türlerinde bloker, haber/araştırmada uyarı). Uzunluk bantları kısaldı. Yeni: `bucketOf`, `MIX_TARGET`, `mixDeficits`, `orderForMix`, `scoreDraftCandidate`, `pickDraftCandidates`. |
| `supabase/functions/academy-worker/index.ts` | Taslak adayı seçimi "en yeni haber" yerine pratik puan (pratik başlık, usta/arşiv kaynağı, Türkçe yerel, eksik kova; basın bülteni ve bayat haber eksi). Yayın sırası konu dengesine göre + günlük haber tavanı (`academy_news_daily_cap`, varsayılan 1). Prompt'a son açılışlar + eksik tür ipucu. Kapalı botun taslakları kuyruğa alınmaz; mizah kapalıyken mizah üretimi yok (yayın kuyruğu düzeltmesi). |
| `supabase/functions/academy-worker/lib_tone_test.ts` | 9 yeni test. |
| `supabase/functions/academy-worker/lib_bugfix_test.ts` | Haber uzunluk bandı testi yeni banda uyarlandı. |
| `academy_bot_settings.style_prompt` (DB verisi) | Aşağıdaki SQL ile deploy'da güncellenecek. |

Yeni config anahtarları (yoksa varsayılan kullanılır): `academy_news_daily_cap`
(1), `academy_mix_window_days` (14).

## Deploy'da çalışacak veri güncellemesi (schema değişmez)

```sql
-- Bot üslupları: akademik ton → tezgâhta anlatan usta tonu
update public.academy_bot_settings set style_prompt = case bot_key
  when 'ekmek_fermantasyon' then 'Üslup: hamurun başındaki ustanın diliyle; sıcaklık/süre/oran kaynaktaysa söyle, yoksa uydurma. Her yazıda hamurun bunu nasıl belli ettiğini anlat.'
  when 'un_tahil' then 'Üslup: un partisi değişince tezgâhta ne değişir, önce onu anlat. Spesifikasyon terimlerini (protein, düşme sayısı vb.) sade Türkçeyle açıkla.'
  when 'turk_urunleri' then 'Üslup: simit, pide, poğaça, börek üreten mahalle fırınının gerçeğiyle; yerel pratik ve günlük tempo.'
  when 'pastacilik' then 'Üslup: pastane tezgâhındaki ustanın diliyle; dolgu, kat, soğuk zincir konularında pratik karşılık.'
  when 'firin_teknoloji' then 'Üslup: fırın başındaki ustaya; gösterge ile ürün arasındaki farkı, buharı, enerjiyi günlük kullanım üzerinden anlat.'
  when 'hijyen_kalite' then 'Üslup: korkutmadan, pratik kontrol listesi mantığıyla; her kural için fırındaki gerçek durumu (tezgâh, bez, kasa, tekne) örnekle.'
  when 'isletme' then 'Üslup: küçük fırın işletmecisinin diliyle; rakamı kaynağa bağla, ay sonu etkisini somutlaştır, kârlılık garantisi verme.'
  when 'sektor_gundemi' then 'Üslup: tarafsız ve kısa haber dili; ama her haberde "fırıncıyı neden ilgilendirir" paragrafı şart. Eski haberi yeni gibi sunma.'
  when 'bilim_arge' then 'Üslup: araştırmayı ustaya çevir — bulgu ne, fırındaki karşılığı ne, bağ zayıfsa açıkça söyle. Terimleri hemen sade Türkçeyle aç.'
  when 'ustalik_dunya' then 'Üslup: dünya fırıncılığından teknikleri Türkiye fırınında denenebilir hâliyle anlat; şekillendirme, kesik, pişirme pratiği.'
  when 'mizah' then style_prompt
  else style_prompt end,
  updated_at = now()
where bot_key in ('ekmek_fermantasyon','un_tahil','turk_urunleri','pastacilik',
  'firin_teknoloji','hijyen_kalite','isletme','sektor_gundemi','bilim_arge','ustalik_dunya');

-- Kapalı mizah botunun kuyruğu tıkayan taslakları kenara al (içerik silinmez)
update public.academy_drafts set status = 'rejected', status_reason = 'bot_disabled',
  updated_at = now()
where bot_key = 'mizah' and status in ('media_ready','dry_run_done','scheduled','checked');

-- Görünürlük için (yoksa varsayılan zaten aynı)
insert into public.app_runtime_config (key, value) values
  ('academy_news_daily_cap', '1'::jsonb),
  ('academy_mix_window_days', '14'::jsonb)
on conflict (key) do nothing;
```

## Yayın kapısı (her taslakta, deterministik)

- Jargon: `literatür, göstermektedir, parametre, optimizasyon, kinetik,
  reolojik, Saccharomyces, p<0.05…` → 1–2 uyarı, 3+ bloker; başlıkta bloker.
- Payoff: `payoff_kind` ∈ {fire, standart, enerji, iscilik, raf_omru,
  sikayet, hiz, erken_fark, maliyet_satis} veya ≥6 kelimelik payoff cümlesi;
  üretim türlerinde yoksa bloker, haber/araştırmada uyarı. Payoff cümlesi
  metinde de geçmeli (uyarı).
- Açılış: tarih-kurum açılışı uyarı; son 8 yayınla aynı ilk 4 kelime uyarı.
- Uzunluk: haber 80–160 (sert 260), kısa not 40–100, diğerleri 90–200 (sert
  330). Ortalama cümle > 24 kelime uyarı.
- Mevcut kapılar aynen: iddia-kanıt (birebir alıntı), URL yasağı, ticari
  kaynak etiketi, aynı konu tekrarı blokeri, emir listesi uyarısı.

## 20 örnek içerik (yeni kurallarla)

> Not: Bu örnekler yeni prompt kurallarına göre **elle** yazıldı; üretim
> modelinin (DeepSeek) çıktısı değildir — bu makinede LLM anahtarı yok.
> Gerçek üretimde her iddia kaynak alıntısıyla doğrulanır; burada kaynak
> satırı temsili bırakıldı. Deploy sonrası ilk 20 gerçek taslak aynı
> formatta raporlanır.

### Günlük üretim ve ustalık (%35 → 7 örnek)

**1. Hamur bugün neden dünkünden farklı?** · craft · sorun_neden_cozum
Aynı un, aynı maya, aynı tartı; hamur yine de dün gibi gelmedi. Çoğu fırında
sebep tek bir şeyde saklı: hamur sıcaklığı. Un deponun sıcaklığını alır, su
musluktan o günkü sıcaklıkla gelir, yoğurma makinesi de üstüne ısı ekler.
Üçü değişince hamur sıcaklığı 2–3 derece oynar; maya bunu hemen hisseder.
Ustanın dikkat edeceği nokta, yoğurma bitince hamura termometre sokmak.
Sabah ve öğlen ölçüsünü bir hafta deftere yazarsan farkın nereden geldiğini
görürsün. Karşılığı: aynı reçeteden her gün aynı ekmek, fire ve geç kalan
tava daha az.
*payoff_kind: standart*

**2. Yazın aynı reçete neden şaşar?** · technical_explainer · durum_3nokta
Temmuzda hamur öğlene doğru koşmaya başlar; sabah 70 dakikada gelen hamur
45 dakikada taşar. Üç nokta: (1) su sıcaklığı — yazın musluk suyu 25
dereceyi geçer, hamur sıcak çıkar; (2) un deposu — güneş alan depoda un
ısınır; (3) salon sıcaklığı — mayalanma dolabı yoksa hamur odayla birlikte
ısınır. Fırındaki karşılığı: suyu soğutmak en ucuz ayar; buz ya da soğuk su
ile hamur sıcaklığını kışla aynı tutabilirsin. Böylece yaz boyunca üretim
planı şaşmaz, vardiya aynı saatte biter.
*payoff_kind: standart*

**3. Fırından çıkan ekmek neden çöker?** · craft · sorun_neden_cozum
Ekmek fırında güzel kabarıyor, tezgâha alınca kabuk buruşuyor, orta çöküyor.
İki olağan şüpheli var: fazla mayalanmış hamur ve erken çıkarılmış ekmek.
Fazla gelen hamurun gaz kesesi zayıftır; fırın ısısıyla son bir şişer, sonra
kendini tutamaz. Erken çıkan ekmeğin ise içi hâlâ nemli ve yumuşaktır; dış
soğuyunca iç ağırlığıyla oturur. Hamur bunu sana parmak testinde belli eder:
bastığında iz hemen geri geliyorsa erken, hiç gelmiyorsa geç kalmışsın.
Karşılığı: çöken ekmek satılmaz, doğrudan fire; iki kontrol o fireyi keser.
*payoff_kind: fire*

**4. Hamur neden ele yapışır?** · craft · gozlem_aciklama
Şekillendirmede hamur ele, tezgâha, beze yapışıyorsa ilk akla gelen "su
fazla" olur; ama çoğu zaman sorun yoğurmanın kısa kalması. Gluten ağı tam
oluşmamış hamur suyu tutamaz, su yüzeye çıkar. Kısa bir pencere testi
yeter: hamurdan bir parça çekip ışığa tut, yırtılmadan inceliyorsa yoğurma
tamam. Un serpmek geçici çözümdür; her serpişte reçete değişir, ekmek
kuru çıkar. Karşılığı: doğru yoğurulmuş hamurla şekillendirme hızlanır,
ustanın eli daha az yorulur, ürün her gün aynı olur.
*payoff_kind: iscilik*

**5. Fırında buhar ne işe yarar?** · technical_explainer · gozlem_aciklama
Buharsız pişen ekmeğin kabuğu ilk dakikalarda sertleşir ve içerinin
şişmesine izin vermez; ekmek küçük kalır, kesik açılmaz. Buhar, kabuğu
birkaç dakika yumuşak tutar; ekmek fırında rahatça büyür, kabuk ince ve
parlak olur. Buharın zamanlaması önemli: ilk 8–10 dakika yeter, sonrası
kabuğu kalınlaştırmaz, aksine yumuşatır. Gösterge aynı olsa da buhar
kazanı dolu değilse ürün farklı çıkar. Karşılığı: aynı hamurdan daha hacimli
ekmek, tezgâhta daha iyi görünen ürün, "küçük kalmış" şikâyeti azalır.
*payoff_kind: sikayet*

**6. Usta değişince kalite neden değişiyor?** · craft · durum_3nokta
Gece ustası ile gündüz ustası aynı reçeteyle çalışır, ekmek yine farklı
çıkar. Fark genellikle üç yerde: yoğurma süresi ("göz kararı" dakikalar),
hamur sıcaklığı hedefi ve mayalanmanın bitişine karar verme anı. Üçünü de
kâğıda dökmek yeter: hedef hamur sıcaklığı, yoğurma dakikası, parmak testi
kuralı. Bu bir ustanın yerini almaz; ustanın bilgisini işletmenin standardı
yapar. Karşılığı: usta izne çıkınca, yeni çırak gelince kalite düşmez;
müşterinin "ekmek dün daha güzeldi" demesi azalır.
*payoff_kind: standart*

**7. Sabah ilk üretimle öğlen üretimi neden farklı çıkar?** · quick_note
Sabah fırın soğuktan ısınır, taş tam doymamıştır; ilk tavalar altı soluk
çıkar. Öğlene doğru fırın tam ısınır, aynı süre bu kez altı fazla kızartır.
Bu yüzden ilk üretimi iki dakika uzun, öğleni iki dakika kısa tutan ustalar
haklıdır. Karşılığı: gün içinde süreyi fırının hâline göre oynatmak alt
yanığı ve soluk ürünü azaltır.
*payoff_kind: erken_fark*

### İşletme ve maliyet (%20 → 4 örnek)

**8. Gramajdaki 10 gram gerçekten önemli mi?** · business · sorun_neden_cozum
Hamur kesimde 10 gram fazla vermek göz kararıyla fark edilmez; ay sonunda
fark edilir. Günde 2.000 ekmek kesen bir fırında 10 gram, günde 20 kilo
hamur demektir; ayda yarım tondan fazla un, su, maya ve enerji kasadan
çıkar ama fiyata yansımaz. Çözüm pahalı değil: kesim tartısını vardiya
başında kontrol etmek ve rastgele on ekmeği tartıp deftere yazmak. Fazla
gramaj müşteriye hediye gibi görünür, aslında kârdan sessizce gider.
*payoff_kind: maliyet_satis*

**9. Un fiyatı arttığında yalnızca satış fiyatına bakmak neden yetmez?** · business
Un zamlanınca ilk refleks fiyatı artırmak olur; ama çoğu fırında kaybın
yarısı un fiyatından değil, fire ve gramaj kaçağından gelir. Zam gününde
yapılacak ilk iş, bir haftalık fireyi ve gramaj sapmasını saymak. Fire
yüzde 5'ten yüzde 3'e inince un zammının bir kısmı kendiliğinden karşılanır.
Karşılığı: fiyatı her zamda yükseltmek yerine önce içerideki kaçağı
kapatmak, müşteriyi kaybetmeden marjı korur.
*payoff_kind: maliyet_satis*

**10. Küçük bir fırında basit maliyet takibi nasıl yapılır?** · business · durum_3nokta
Muhasebe programı şart değil; üç rakam yeter. (1) Günlük un çuvalı sayısı,
(2) günlük satılan ekmek adedi, (3) gün sonu elde kalan. Bir çuvaldan kaç
ekmek çıktığını haftalık takip edersen gramaj kaçağını ve fireyi aynı anda
görürsün. Elektrik ve gaz faturasını da aylık ekmek adedine böl; ekmek
başına enerji maliyeti çıkar. Karşılığı: zam, personel ve fiyat kararlarını
hissiyatla değil, kendi rakamınla verirsin.
*payoff_kind: maliyet_satis*

**11. Personel vardiyası üretime göre nasıl planlanır?** · business
Gece 02:00'de üç usta, akşam 17:00'de bir çırak: çoğu fırının planı budur ve
akşam ekmeği bu yüzden ya erken biter ya bayat kalır. Saatlik satış
sayımı bir hafta tutulduğunda yoğun saatler netleşir; vardiya o eğriye
göre kayar. Çoğu mahalle fırınında ikinci küçük bir pişirme akşam 16:00'da
hem fireyi düşürür hem akşam müşterisini tutar. Karşılığı: aynı personelle
daha az fire, daha az boş saat.
*payoff_kind: fire*

### Ürün kalitesi / hata çözümü (%15 → 3 örnek)

**12. Ekmek çabuk bayatlıyorsa ilk nereye bakmalı?** · ingredient · sorun_neden_cozum
Ertesi gün taş gibi olan ekmeğin sebebi çoğu zaman un değil, su ve
pişirmedir. Hamur suyu düşükse ekmek baştan kurudur; fazla pişen ekmek
nemini fırında bırakır. Üçüncü şüpheli, erken paketlemedir: sıcak ekmek
poşette terler, kabuk yumuşar ve sonra sertleşir. Önce hamurdaki su
oranına, sonra pişirme süresine, en son paketleme saatine bak. Karşılığı:
bayat iade ve "dünkü ekmek" şikâyeti azalır.
*payoff_kind: raf_omru*

**13. Un değişince reçetede ilk neye bakılır?** · ingredient · durum_3nokta
Yeni parti un geldi, hamur farklı davranıyor. Üç kontrol: (1) su — bazı
unlar daha çok su kaldırır, hamur sertse yüzde 1–2 su ekle; (2) yoğurma
süresi — kuvvetli un geç gelişir, pencere testine göre uzat; (3) mayalanma
— zayıf un çabuk gelir, süreyi kısalt. Reçeteyi baştan yazmak gerekmez;
üç ayar not edilir, parti bitince eski değere dönülür. Karşılığı: un
değişiminde iki üç gün süren "bozuk ekmek" dönemi bir hamura iner.
*payoff_kind: erken_fark*

**14. Altı pişip üstü neden soluk kalır?** · technical_explainer
Taban fırın taşından doğrudan ısı alır, üst ise havadan; ikisi dengeli
değilse alt yanar, üst beyaz kalır. Sık sebepler: üst rezistans/alev
düşük, buhar fazla ve geç kesilmiş, tava fırının alt rafında. Ustanın ilk
deneyeceği şey buharı erken kesmek; ikincisi üst ısıyı birkaç derece
artırmak. Gösterge aynı dereceyi gösterse de fırının her rafı aynı
pişirmez. Karşılığı: aynı fırından daha düzgün renkte ürün, ikinci kez
fırına atma zahmeti biter.
*payoff_kind: standart*

### Hijyen ve gıda güvenliği (%10 → 2 örnek)

**15. Fırın temizliğinde en çok unutulan noktalar neler?** · hygiene · durum_3nokta
Tezgâh her gün silinir; asıl risk göz önünde olmayan yerlerde. Üç unutulan
nokta: hamur bezleri (nemli kalınca küf tutar, her gün değişmeli), kasa ve
tepsi köşeleri (eski hamur kalıntısı yeni hamura karışır), un deposunun
zemini (dökülen un haşere çeker). Haftalık küçük bir kontrol listesi bu
üçünü kapsarsa denetimde sürpriz olmaz. Karşılığı: müşteri şikâyeti ve
denetim riski düşer, ekipman daha uzun dayanır.
*payoff_kind: sikayet*

**16. Ekmek üzerinde yeşil-siyah lekeler: küf neden bu kadar hızlı gelir?** · hygiene
Küf sporu her yerde var; sorun, ekmeğin onlara uygun ortam vermesi. Sıcak
paketlenen ekmek poşette nem bırakır, nem küfün hızlı yolu. Dilimleme
bıçağı ve tezgâh temizlenmezse spor ekmekten ekmeğe taşınır. Ekmeği tam
soğutup paketlemek ve dilimleyiciyi günde bir kez yıkamak çoğu fırında
yeterli olur. Karşılığı: iade ve atılan paketli ekmek azalır, raf ömrü bir
gün uzar.
*payoff_kind: raf_omru*

### Sektör haberi / mevzuat (%10 → 2 örnek)

**17. Ekmek gramajı denetimleri sıklaştı: neye bakılıyor?** · news · haber_etkisi
Haber: Bakanlık ekmekte gramaj denetimlerini yoğunlaştırdığını açıkladı.
Fırıncı için anlamı şu: denetim pişmiş ekmeğin gramajına bakar, hamur
kesimine değil; kesimde doğru tartılan ekmek pişince eksik çıkabilir.
Fırın kaybını bilmek için haftada bir pişmiş ekmeği tartmak yeter. Kaynak
ve tarih bağlantısı sistem tarafından eklenir.
*payoff_kind: bilgi*

**18. Doğalgaz tarifesinde değişiklik: fırın faturası nasıl etkilenir?** · news
Haber: sanayi abonelerinde kademeli tarife duyuruldu. Fırıncıyı ilgilendiren
taraf: tüketim belli bir eşiği geçince birim fiyat artıyor; aynı üretimi
daha az gazla yapmak (fırını boş çalıştırmamak, pişirmeleri birleştirmek)
artık doğrudan fatura demek. Kaynak sistem tarafından eklenir.
*payoff_kind: enerji*

### Satış, müşteri ve sunum (%5 → 1 örnek)

**19. Tezgâhta kalan ürün sana ne anlatıyor?** · business · gozlem_aciklama
Gün sonu tezgâhta kalan ürün, yarının üretim planıdır. Hangi ürünün hangi
saatte kaldığını üç gün not etmek yeter: akşam kalan simit sabah fazla
üretildiğini, öğleden sonra biten poğaça ikinci pişirme fırsatını gösterir.
Ürünü göz hizasına ve kasaya yakın koymak satışı oynatır; kalanı önde
tutmak ise müşteriye "bayat" dedirtir. Karşılığı: aynı tezgâhla daha az
fire, daha çok satış.
*payoff_kind: maliyet_satis*

### Derin teknik / bilimsel (%5 → 1 örnek)

**20. Fazla maya gerçekten işi hızlandırır mı?** · research · gozlem_aciklama
Araştırma bulgusu: maya oranı artınca gaz üretimi hızlanıyor ama hamurun
gazı tutma gücü aynı hızda artmıyor; belli bir noktadan sonra ekmek daha
çabuk geliyor, hacmi büyümüyor, tadı mayamsı oluyor. Yani maya, zaman
satın alır ama kaliteden öder. Fırındaki karşılığı: acele günlerde mayayı
artırmak yerine hamur suyunu birkaç derece ılıtmak çoğu zaman daha
güvenli yoldur. Kaynak sistem tarafından eklenir.
*payoff_kind: standart*

## Eski prompt ↔ yeni prompt: 5 karşılaştırma

Sol taraf 2–7 Ekim'de **gerçekten yayınlanan** metinlerin açılışı; sağ taraf
aynı kaynak gerçekleriyle yeni kurallara göre yazım (kaynak dışı çıkarım
"FırınNet notu"na ayrılır).

**A. Balkabaklı hamur**
- Eski: "King Arthur Baking'in 5 Ekim 2026 tarihli balkabaklı tarif
  derlemesi, unlu mamulde tekrar eden bir soruna parmak basıyor: püre
  hamura hem nem hem ağırlık getiriyor…"
- Yeni başlık: **Balkabaklı hamur neden ağır kalıyor?**
  "Sonbaharda balkabaklı çörek ve kek yapan pastanelerin ortak derdi: hamur
  kabarmıyor, ağır kalıyor. Sebep pürenin kendisi — püre hamura yalnız
  lezzet değil, bol su da taşıyor. Kaynaktaki iki tarifte çözüm aynı:
  püreyi ocakta çevirip fazla suyunu uçurmak, sonra hamura katmak. Hamur
  bunu sana yoğururken belli eder: püreli hamur normalden gevşekse su
  fazladır. FırınNet notu: Püre ne kadar indirilirse reçetedeki sıvı o
  kadar azaltılmalı; yoksa hamur yine gevşer. Karşılığı: aynı reçeteden her
  partide aynı kabarma, pastanede 'bu sefer tutmadı' partisi azalır."

**B. Puratos protein karışımı**
- Eski: "Puratos, ticari fırınlar için geliştirdiği iki yüksek proteinli
  karışımı duyurdu: ProteinPro Strength ve ProteinPro Flex. 5 Ekim 2026
  tarihli duyuruya göre…"
- Yeni başlık: **Proteinli ekmek talebi fırına gelirse hamur nasıl davranır?**
  "Spor salonu müşterisi 'proteinli ekmek var mı?' diye sormaya başladı.
  Puratos'un yeni iki karışımı tam bu talep için çıkmış (üretici içeriği).
  Üreticinin kendi anlatımına göre karışım hamurun su emişini ve
  işlenebilirliğini değiştiriyor; yani mevcut reçeteye katınca su ve yoğurma
  yeniden ayarlanmalı. FırınNet notu: Bu bir ürün duyurusu; bağımsız test
  yok, Türkiye'de bulunurluk ve fiyat ayrıca sorulmalı. Karşılığı: denemeye
  karar verirsen ilk partiyi küçük tut, su ve süreyi not et."

**C. MIWE fırın kontrol sistemi**
- Eski: "MIWE'nin ABD kolu MIWE America, 27 Ağustos 2026'da MIWE flexbake®
  fırın kontrol teknolojisinin yeni sürümünü duyurdu…"
- Yeni başlık: **Fırının göstergesi doğru olsa bile ürün neden farklı pişer?**
  "Aynı derece, aynı süre; sabah tavası güzel, öğlen tavası soluk. Fırın
  üreticisi MIWE'nin yeni kontrol sürümü tam bu derdi hedefliyor: sistem
  pişirme koşullarındaki değişkenleri izleyip kendisi dengeliyor (üretici
  açıklaması). Ustanın bildiği şeyin elektroniği aslında: fırın dolu mu boş
  mu, kapı kaç kez açıldı, taş ne kadar doydu. FırınNet notu: Yeni sistem
  almadan önce aynı dengeyi elle kurmak mümkün — tava sırası ve kapı açma
  disiplini çoğu farkı kapatır. Karşılığı: gün içinde standardı tutturmak,
  ikinci pişirme ve soluk ürün azalır."

**D. Food for Peace buğday sevkiyatı**
- Eski: "New Orleans limanında düzenlenen törenle Food for Peace programı
  kapsamındaki yeni sevkiyat kutlandı. ABD bayraklı Liberty Grace gemisine
  28.420 MT…"
- Yeni karar: Bu haber **yayınlanmaz**. Aday puanlamasında basın/tören
  haberi eksi puan alır; 'fırıncıyı neden ilgilendirir' sorusuna verilecek
  dürüst cevap zayıf (kaynak dışı spekülasyon gerektirir). Bu tür içerik
  yerine aynı gün ustalık kovasından bir yazı seçilir.

**E. Maine tahıl konferansı izlenimi**
- Eski: "Maine'de düzenlenen Kneading Conference'a üst üste ikinci yıl
  katılan Breadtopia yazarı, etkinliğin bu yılki açılış konuşmasını…"
- Yeni başlık: **Fırında tükenmişlik: yalnız çalışan ustanın en büyük riski**
  "Gece 2'de tek başına hamur açan usta için 'tükenmişlik' lüks bir kelime
  gibi gelir; ama kaynaktaki konuşmanın özü tam bu: 'topluluk,
  tükenmişliğin panzehiri'. Yazı bir konferans izlenimi, teknik veri yok.
  FırınNet notu: Türkiye'de de fırıncı odaları ve ustalar arası sohbet aynı
  işi görür — bir sorunu başka bir ustaya sormak çoğu zaman en ucuz
  danışmanlıktır. Karşılığı: bilgi paylaşımı; doğrudan üretim etkisi yok,
  bu yüzden kısa not olarak ve haber kotasından yayınlanır."

## Son katman (deploy öncesi eklendi)

- **Yerel gerçeklik:** başlıkta Türkiye fırın pratiği terimleri (somun, pide,
  simit, poğaça, yaş/kuru maya, çuval, bayi, kasalama, gramaj, fire, iade,
  vardiya, doğalgaz…) aday puanına artı; yabancı basın bülteni pratik/yerel
  köprüsüzse ek eksi. Taslakta hiç yerel terim yoksa `no_local_context` uyarısı.
- **FırınNet notu guard'ı (`checkEditorialNote`):** notta kaynakta geçmeyen
  sayı/ölçü, mevzuat-sağlık ifadesi veya kesinlik dili → bloker.
- **Konu yorgunluğu:** başlık+payoff+ilk cümle kök imzası son 30 günün
  yayınlarıyla ≥0.45 örtüşürse `topic_fatigue` blokeri; aday seçiminde
  başlık imzası örtüşmesi −6.
- **Pratiklik puanı:** payoff türü + `tomorrow_action` + eylem fiili + yerel
  terim → 0–100; üretim/ustalıkta <60, diğer pratik türlerde <40 bloker.
- **Kalite tabanı:** `academy_min_quality_score` (70) altı yayınlanmaz;
  günlük hedef 6 bir tavandır, zorunluluk değil.
- **Günlük plan:** 2 üretim, 1 işletme, 1 ürün kalitesi, 1 hijyen/satış
  (yumuşak: tavanı dolan kova sıranın sonuna), haber+derin teknik toplam 1
  (sert).
- **Dil:** "Ustam/abi/kanka/valla" vb. yapay esnaf ağzı 1 isabet uyarı,
  2 isabet bloker; prompt'ta açık yasak.

## Deploy sonrası izleme

- İlk 3 gün: yayınlanan her taslağın `quality.payoff_kind`, `angle` ve
  `blockers` alanları; `no_payoff` ve `jargon_heavy` oranı.
- Konu dağılımı: `select content_type, count(*) from academy_drafts where
  status='published' and updated_at > now()-interval '7 days' group by 1`.
- Haber tavanı: günde en çok 1 haber (`academy_news_daily_cap`).
