# FırınNet Akademi + Mizah — Uygulama İlerleme Kaydı

> Bu dosya uygulama boyunca güncellenir: tamamlanan işler, varsayımlar,
> test sonuçları ve sıradaki adım. Rapor değil, çalışma defteridir.

## EDİTORYAL KALİTE + FEED GÖRSEL DÜZELTMESİ (2026-10-01)

**Baseline (ilk iki otomatik yayın):** SIAL haberi 323 kelime (haber hedefi
100-220), 7 paragraf, 9 emir kipi, 7 madde; TÜBİTAK/protein araştırma
yazısı 366 kelime, 4 emir, 4 madde, fırıncılık bağı yazının kendi
ifadesiyle zayıf. İkisinde de kart yalnız başlığı tekrarlıyor (bilgi
katmıyor). Her ikisi de feed'de 1 kart görseliyle yayında.

**Feed görsel kırpılması — kök neden (koddan):** `social_post_card.dart`
`_PostMedia` = `AspectRatio(4/3)` + `BoxFit.cover`. Akademi kartı
1200x675 (16:9); cover yüksekliğe ölçekler → genişliğin %25'i kesilir
(her yandan 150px), kart metni x=80'den başladığı için satır başları
kaybolur. Detay (`comments_page.dart`) `AspectRatio(16/10)`+cover: her
yandan ~67px → metin kenarı kurtulduğu için "tam" görünüyordu.
**Düzeltme:** ortak `FeedPostImage` (feed + detay aynı kural): kutu
görselin GERÇEK oranında (feed_media width/height; yoksa görsel çözülüp
ölçülür), 4:5..1.91:1 aralığına sınırlı, `BoxFit.contain` + nötr zemin →
hiçbir görsel kırpılmaz. Regression: `test/feed_image_fit_test.dart`
(16:9 kart, 4:3, 1:1, dikey, boyutsuz, görselsiz, 320/390/600 genişlik,
detay) — eski kodda 9/10 FAIL, düzeltmeyle 10/10. Kart şablonu
`CARD_SAFE` güvenli alanı (sol/sağ 80px, gövde ≤545, alt marka) + K3 testi.

**Editoryal katman (lib + worker + migration `20261001090000_academy_editorial_v1`):**
- content_type (news/technical_explainer/business/research/ingredient/
  hygiene/craft/quick_note) + tür başına yapı/uzunluk prompt'ta; haber/
  araştırma/kısa notta pratik not listesi deterministik atılır.
- Kaynak gerçeği (body) ile çıkarım ayrı: `editorial_note` yayında
  "FırınNet notu:" etiketiyle, kaynak satırından önce.
- `bakeryRelevance` KAYNAK metinde, LLM'den ÖNCE (token harcamaz):
  protein yaz okulu tipi bağsız içerik `low_bakery_relevance` RED.
- `editorialQuality`: uzunluk bandı, emir kipi yoğunluğu, haberde liste,
  uzun giriş, "kaynak metin içermiyor" meta cümleleri, iç tekrar →
  UYARI; aşırı uzunluk ve son yayınlarla aynı konu → BLOKER. Skor
  `academy_drafts.quality`'de.
- Görsel opsiyonel: `needs_visual` (haber/araştırma/kısa not hep görselsiz;
  diğerleri model gerekçe gösterirse). Görselsiz taslak medya aşamasını
  atlar; RPC medyayı yalnız needs_visual ise şart koşar.
- Yayın RPC'si: İstanbul 08:00-21:30 penceresi (dışı → `deferred_quiet_hours`,
  sıradaki açılışa), son yayından 90 dk (`deferred_spacing`), art arda aynı
  persona / iki araştırma alternatif varken `deferred_diversity`; günlük
  2 + bot başı 1 tavanları korunur. Worker planlaması aynı kuralları
  önceden uygular (pencere + çeşitlilik sırası).

Testler: deno 68/68 (E1-E12, K3), PG 11/11 (yeni 11_editorial_publish:
pencere/görselsiz/not/atıf/aralık/çeşitlilik/tavan), Flutter görsel
regression 10/10.

## CANLI AÇILIŞ — PRODUCTION GO-LIVE (2026-09-30 akşam, kullanıcı talimatı)

Plan değişikliği: yarınki otomatik açılış yerine BU TURDA canlı
(academy-go-live cron'u kaldırıldı). Değişen config (eski→yeni):
enabled false→true, dry_run true→false, recipe_enabled false→true;
hard_cap seed penceresi için 2→14→2, bot_cap 1→2→1 (geri alındı).

**İlk canlı içerik (gerçek hat):** 10 editoryal taslak (evergreen,
claims=[], dış kaynak iddiası yok) → worker media işleriyle 10 PNG kart →
`academy_publish_draft` ile **10/10 published**. 6 bot: ekmek_fermantasyon
×2 (hamur sıcaklığı, ekşi maya), un_tahil ×2 (su kaldırma, tuz yüzdesi),
firin_teknoloji ×2 (buhar/veriş, enerji), hijyen_kalite (çapraz bulaşma),
isletme ×2 (fire, gramaj), ustalik_dunya (şekillendirme).

**Tarifler canlı:** 5 usta tarifi (Beyaz Ekmek, Ramazan Pidesi, Simit,
Tam Buğday, Sandviç) checkBakersRecipe strict PASS kanıtıyla published;
`ar_select_published` RLS migration'ı PROD'da; Flutter'a Tarifler şeridi +
detay alt-sayfası (gramaj+% birlikte) eklendi (widget testli).
**K2g fixi (red-first):** 'Tam buğday unu' gibi ek almış un adları taban
sayılmıyordu → FLOUR_RE düzeltildi (yanlış RED'i canlı doğrulama yakaladı).

Smoke (authenticated rolüyle): 10 bot postu + author_name snapshot +
kart=1/post; public_profile_snapshot bot adını döndürüyor; 5 tarif
görünür. profiles tablosunun yalnız-kendi-satırı politikası bilinen
tasarım (feed snapshot + RPC yolu). Testler: deno 55/55, PG 10/10,
Flutter 2507/2507, analyze 0.

Rollback: config eski değerlere; içerik: editorial-% idempotency_key'li
draft/post/media satırları + 5 tarif silinebilir (id'ler DB'de etiketli).

## EK-6/7 — VİDEO KURALI + TARİF TÜRÜ V1 (2026-09-30)

**Video denetimi (madde 6):** Kod taraması sonucu — YouTube/video/transkript/
thumbnail çekimi HİÇ YOKTU (safeFetch video/image content-type reddi, 0 video
aday, medya yalnız üretilen info_card, taslakta URL yasağı). Kural artık
AÇIK kod+test (K1): `isVideoPlatformUrl` (youtube/youtu.be/vimeo/dailymotion/
tiktok/twitch) + `isLikelyArticle` reddi → video sayfası makale/kanıt olamaz;
indirme/yeniden yükleme/transkript kazıma/thumbnail YOK; izinli tek kullanım
kendi özet + videonun linki (atıf sicilden).

**Tarif türü V1 (madde 7, plan→uygulama):** `academy_recipes` usta havuzu
PROD'da (RLS: usta kendi taslağı; onay/yayın YALNIZ service_role; adapted
için source_url zorunlu) + drafts.kind'e 'recipe' + `academy_recipe_enabled=
false` (bot üretim hattı SONRAKİ adım — config açılınca). Denetimler lib'de
testli (K2a-f, deno 54/54): `checkBakersRecipe` fırıncı yüzdesi (un=100;
hidrasyon 50-90, tuz 1.2-3, maya instant 0.2-2/taze 0.5-5, şeker≤25, yağ≤30,
fırın 140-320°C, süre 5-120dk; bot=strict RED, usta=uyarı; gram↔% tutarsızlık
HER kipte RED), `formatRecipeLines` gramaj+% birlikte ("Un 1000 g (%100)"),
`hasVerbatimOverlap` 12-kelime birebir dizi = kopya RED (uyarlama kuralı).
PG 10_recipes testi (RLS/onay/adapted/kind/config) — paket 10/10 PASS.
Ders: harness auth.uid() `request.jwt.claim.sub` (tekil) okur; runner'a
migration eklerken idempotency turundaki fix-sonra-uygula sırası korunmalı.

## AŞAMA 6 — YAYIN AÇILIŞI KURULUMU (2026-09-30, onaylı)

Onay öncesi iki düzeltme (main e8ab2c2, worker deploy edildi):
- **date_context sanitize (H7)**: modelin iç-talimat cümlesi + parantez notu
  yayına sızamaz (lib `sanitizeDateContext`, validateDraftOutput'a bağlı;
  nokta içeren tarih bozulmaz). Mevcut SIAL taslağı veri düzeyinde
  temizlendi → "Etkinlik tarihi: 17-21 Ekim 2026".
- **Atıf etiketi vendor-only**: ' (üretici içeriği)' yalnız
  source_type='vendor'; ticari SEKTÖR YAYINI (World Bakers) etiket almaz.
  Yeni migration `20260930090000_academy_attribution_vendor_fix` PROD'da;
  PG 04-P7 fixture vendor + P7e negatif senaryo; runner idempotency turu
  fix'i engine'den SONRA yeniden uygular (engine 2. uygulaması eski gövdeyi
  geri yazıyordu — testte yakalandı).

Açılış planı (kullanıcı onaylı) KURULDU:
- Tavanlar: `academy_daily_post_hard_cap=2`, `academy_bot_daily_post_cap=1`.
- Mizah botu `posting_enabled=false` (ilk 3 gün; akademi oturunca elle açılır).
- `academy-go-live` tek-seferlik pg_cron: **1 Ekim 2026 09:00 İstanbul**
  → `academy_enabled=true` + `academy_dry_run=false` + kendini siler.
- İlk 3 gün yayın raporlaması: oturum-içi zamanlanmış izleme turu (2 saatte
  bir, gündüz) — her yeni bot postunun id+metni kullanıcıya raporlanır.
- Acil durdurma: `update public.app_runtime_config set value='false'::jsonb
  where key='academy_enabled';`

## AŞAMA 3-5 — secrets + deploy + DRY-RUN CANLI DOĞRULAMA (2026-09-29/30)

Secrets: edge `ACADEMY_WORKER_TOKEN`+`DEEPSEEK_API_KEY` mevcut; Vault
`academy_worker_url`+`academy_worker_key` dolu. İlk tick 401 → iki değer
ayrı girilmişti; tek yeni değerle senkronlandı (rotasyon; değer rapora
yazılmadı). Worker deploy (CLI, --no-verify-jwt); yanlış/eksik token → 401
fail-closed doğrulandı. `academy_enabled=true` + `academy_dry_run=true`;
geçici `*/2` burst cron ile ~9 saat gerçek koşu, sonra burst kaldırıldı
(kalıcı 30-dk `academy-worker-tick`).

**Gerçek ortam sonuçları:** 264 scan + 297 archive başarılı; **73 kaynak
gerçek makale kanıtıyla ACTIVE** (27 degraded, 13 candidate); 880 içerik
adayı. **DeepSeek gerçek:** 152 istek / ~810k token (2 gün). **Bütçe
tavanları tuttu:** token 405k/400k-cap ve fetch ~2k/cap'te kesildi
(`budget_*` hata sınıfı). **İddia denetimi gerçek çıktıda:** 20 taslak RED
(`context_mismatch`/`quantity`/`substance_mismatch`; `claims_uncertain`
asla yayımlanmadı), 1 akademi taslağı (SIAL Paris, 4 iddia) + 2 mizah
taslağı kabul → **dry_run_done; feed'e 0 bot postu (gece boyu)**. PNG kart
1200×675 GERÇEK üretildi ve Storage'a yüklendi (nesne doğrulandı). Hata
sınıfları canlı görüldü: scan_failed→dead (57), llm_truncated, budget_*.

**Canlı bulunan ve düzeltilen hatalar (main 9266761 + devamı):**
- draft `max_tokens` 1800 → truncation retry döngüsü (129 kez, token
  israfı) → 4000 → canlıda sürdü → **8000**.
- scan dedupe anahtarında saat slotu → kuyruk şişmesi (113→211) →
  slot kaldırıldı (cooldown zaten aralığı koruyor) + kuyruk kopya temizliği.

Not: akademi taslak kabul oranı bilinçli olarak düşük (deterministik
denetim EN kaynak + TR quote çevirisini reddediyor → güvenli taraf);
kabul oranı iyileştirmesi canlı-sonrası backlog.

## AŞAMA 2 — merge + prod migration SONUÇ (2026-09-29)

PR #110 squash-merge edildi (main `fa20760`); 3 academy migration prod'a
MCP ile uygulandı (`academy_content_engine_v1`, `academy_sources_seed_v1`,
`academy_cron_v1`). Ön koşullar: prod `find_or_create_direct_conversation`
tanımı migration ÖNCESİ `pg_get_functiondef` ile alındı
(rollback/…prod_snapshot_20260929.sql) ve repo ugc_safety_v1_1 tanımıyla
birebir aynı çıktı (fark yok); prod migration listesi karşılaştırıldı —
uygulananlar YALNIZ bu 3'ü (not: 3 eski prod migration'ının repo dosyası
yok — b2b_revoke_trigger_fn_execute, b2b_quote_leads_denorm,
expire_old_listings_daily_cron — geçmişte MCP ile doğrudan uygulanmış,
bilinen sapma). Tam DB yedeği MEVCUT ARAÇLARLA ALINAMADI/teyit edilemedi
(MCP'de backup API yok, CLI bağlantısız, PAT izole) — telafi: değişen tek
nesnenin birebir snapshot'ı + imza-bağımsız tam rollback SQL'i
(rollback/academy_full_rollback.sql; cron adı academy-worker-tick).

Prod doğrulama (hepsi PASS): 12 academy tablosu hepsi RLS'li; 12 RPC;
`academy_enabled=false` + `academy_dry_run=true`; cron `academy-worker-tick`
kayıtlı ve `academy_cron_tick()` = 'disabled' (kill-switch no-op); 11 bot
hesabı parolasız (giriş kapalı) + profiles.is_bot=true; 113 kaynak / 199
eşleştirme (hepsi candidate). DM smoke (gerçek 2 test kullanıcısı, auth
bağlamı simüle, oluşan konuşmalar silindi): kullanıcı-kullanıcı DM açıldı +
idempotent; akademi botuna (allow_dm=false) DM RED; Mizah botuna DM açıldı.
Security advisör: academy'ye özgü YENİ sorun yok (RLS-no-policy INFO'ları
bilinçli deny-by-default; motor RPC'leri authenticated'a kapalı).

Sistem hâlâ TAM KAPALI: worker deploy edilmedi, Vault boş, secrets yok.

## AŞAMA 1 — zayıf bot güçlendirme SONUÇ (2026-09-29)

Hedef: isletme/turk_urunleri/ustalik_dunya ≥5 içerik-kanıtlı. Sonuç:
**113 aday → 43 içerik-kanıtlı / 7 feed-kanıtsız / 5 blocked_or_limited /
58 kanıtsız.** Konu başına: ekmek_fermantasyon 11, sektor_gundemi 10,
ustalik_dunya 10, firin_teknoloji 9, hijyen_kalite 8, bilim_arge 7,
pastacilik 7, **turk_urunleri 6, isletme 5, un_tahil 5** — üç zayıf konu
hedefi karşıladı. 22 yeni aday eklendi (yalnız yeniler tarandı, ONLY
filtresiyle; tam tarama TEKRARLANMADI); kanıt kuralları değişmedi.

Bu sırada bulunan ve kırmızı-test-önce kapatılan YENİ hatalar (deno 44/44):
- **H4 kapsam seçimi**: extractPage ilk `<article>`'ı alıyordu — çoğu
  sitede o teaser kartı (47 karakterlik "gövde" → gerçek makale RED).
  `scopeContent` artık en uzun article/main bloğunu seçer; linkDensity/
  form/paragraf ölçümleri de AYNI kapsamda (site menüsünün 300 linki doğru
  makaleyi reddettiremez; kategori listelemesi hâlâ RED). Bu düzeltme
  theperfectloaf/chainbaker/bakefromscratch/breadtopia'yı kanıta çevirdi.
- **H4d canonical-kök**: her sayfada köke işaret eden bozuk canonical
  makale URL'sini "/" yapıyordu → artık yok sayılır.
- **Kalıp sızıntıları**: hakkında/yayın ilkeleri/kalite-çevre yönetimi/
  media-center/üyelik-etkinlik dışı kurumsal sayfalar; `kurumsal/` yolu
  artık bütünüyle içerik-dışı. Ayrıca Python `\b`→backspace tuzağı regex'e
  görünmez 0x08 sokmuştu (4 adet) — temizlendi, test ediliyor.

Dürüstlük notları: world_bakers/craft_bakers_uk kanıtları etkinlik duyurusu
(sınıf: gerçek içerik, sınırda); oztiryakiler kanıtı şirket basın haberi;
uno_tr/akmaya/ozmaya/dunya_gida bağlantı hatası (status 0) — kanıtsız;
snack_bakery/ulusoy_un 403 → blocked_or_limited (kanıtlı SAYILMAZ);
food_business_news/degirmenci_dergisi kanıt çıkarılamadı. Seed migration
113 aday/mapping'e genişletildi (PG paketi yeniden koşuldu).

## 3. tur — üç doğrulanmış hata + kanıt kalitesi SONUÇ (2026-09-29)

Üç hata kırmızı-test-önce kapatıldı (`lib_bugfix_test.ts` düzeltme öncesi
9/12 FAIL → sonrası deno 38/38 + typecheck temiz; PG paketi 9/9):

- **H1 iddia denetimi**: birim SINIF+ÇARPAN modeli (g↔kg, dk↔saat artık
  dönüşümle eşdeğer; 20 g ↔ 0.02 kg KABUL, 30 dk ≠ 30 saat RED), olumsuzluk
  yönü XOR (bekletilmemelidir ≠ bekletilmelidir → RED), madde sözlüğü
  (un miktarı maya iddiasını DOĞRULAYAMAZ; süreç-kelime örtüşmesi maskeyi
  kaldırıldı), TR-özet + EN-quote kabulü korundu.
- **H2 sahte içerik kanıtı**: iletişim/giriş/çerez/kontaktformular +
  kurumsal biyografi (başkan/bakan/genel müdür/kurucu) + über-uns/
  Datenschutz/tarihçe/teşkilat/iştirakler + üyelik/iş-ilanı/haber-listesi/
  ana-sayfa sayfaları KANIT DEĞİL (`isLikelyArticle` tür+yapı denetimi,
  `BAKERY_TOPICAL_RE` konu şartı, proof v:2 — eski kanıtlar kaynağı
  aktive edemez). TR charset düzeltmesi (windows-1254/iso-8859-9 →
  `detectCharset`/`decodeBody`) başlık kalıplarının kaçmasını bitirdi.
- **H3 keşif cursor'u**: `discoverArticles` cursor'u artık DENENEN link
  sayısı kadar ilerler (10 link/maxArticles=5 → cursor 5; 6-10 sonraki
  turda okunur, atlama yok).

**Kaynak doğrulama (canlı, worker koduyla aynı çıkarım, nezaket gecikmeli
tek koşu + 3 aşamalı ölçüt-yeniden-değerlendirme — tarama TEKRARLANMADI):**
91 aday → **32 içerik-kanıtlı** / 7 feed-erişilir-kanıtsız /
**3 blocked_or_limited** (soke_un 403, miwe 503, mdpi_foods 403 — kanıtlı
sayılmaz) / 49 kanıtsız. Konu başına: ekmek_fermantasyon 8, hijyen_kalite 8,
bilim_arge 7, firin_teknoloji 7, sektor_gundemi 9, un_tahil 5, pastacilik 5,
turk_urunleri 3, ustalik_dunya 3, isletme 2. Önceki 52/53 sayıları kurumsal
ana-sayfa/üyelik/ilan/listeleme kanıtları içeriyordu; yeniden değerlendirme
bunları `content_proof_rejected` alanına düşürdü. Sınırda kalan 2 kayıt
(tuik Alo-124 kurumsal sayfası, codex Arapça haber listelemesi) raporda
işaretli; üretici ürün/teknik sayfaları bilinçli olarak kanıt SAYILIR
(atıfta "üretici içeriği" notu var). Zayıf botlar (isletme 2, turk_urunleri
3, ustalik_dunya 3) canlı öncesi aday genişletme ister — motor kanıtsız
kaynağı zaten aktive etmez, bu bir blocker değil kapasite notudur.

Kalan canlı doğrulamalar değişmedi: gerçek DeepSeek çağrısı (anahtar yok),
Storage/feed yayını (deploy yok), cihaz görünümü. Sistem OFF
(`academy_enabled=false`, `academy_dry_run=true`).

## Mevcut durum tablosu (keşif — 2026-09-28, main 6c878c1)

| Bileşen | Durum | Kaynak |
|---|---|---|
| Bot kimlik modeli | ✅ CANLI: `profiles.is_bot` + `academy_bot_profiles` (metadata+RLS; Path B: bot = giriş-kapalı auth.users+profiles satırı, post `owner_id=bot id`) | `20260713090000_academy_bot_profiles_v1.sql` (PR #100 MERGED) |
| Bot seed | ❌ YOK (bilinçli; plan `docs/academy/bot_seed_plan.md`) | prod'da 0 bot satırı |
| PR #102 (feed/profil UI) | AÇIK ve BAYAT (Temmuz; social_post_card/profile_page o günden çok değişti; içine alakasız hesap-silme/docs işleri karışmış) | okuma katmanı deseni yeniden kullanılacak, PR muhtemelen kapatılıp yerine yenisi |
| Feed | `feed_posts` (owner_id→profiles, type CHECK 8 değer, author snapshot trigger) + `feed_media` (`feed-media` bucket) | social_spine_v1 + s3_feed_media |
| Bot post yazımı | YALNIZ service_role (feed_posts_insert_self: owner_id=auth.uid(); service_role RLS bypass) — korunacak sözleşme | social_spine_v1:558 |
| Yorum/DM | feed_comments insert_self; `find_or_create_direct_conversation` çift-yön block'lu, **is_bot kontrolü YOK** (boşluk: bota DM açılabilir) | ugc_safety_v1_1 |
| Bildirim/push | notifications + pg_net→push-dispatch; bot postuna yorum bota tüketilmeyen bildirim yazar (bilinen küçük yan etki) | in_app_notification_events, push_dispatch |
| Zamanlayıcı | pg_cron mevcut (tek job: supplier-launch-reminders); Akademi cron/worker YOK | supplier_launch_campaign_v1:481 |
| İş kuyruğu | YOK (kurulacak) | — |
| LLM istemcisi | YOK (DeepSeek kurulacak; repoda hiçbir LLM çağrısı yok) | grep 0 eşleşme |
| UI bot rozeti/route | YOK (client `is_bot` okumuyor; router'da academy yok) | grep 0 eşleşme |
| Engelleme/şikayet | content_reports target_type feed_post/profile bot içeriğini kapsar; user_blocks çalışır | ugc_safety_v1 |
| AGENTS.md | YOK | — |

## Kilit varsayımlar (teslim raporunda tekrarlanacak)

1. **Kaynak sayısı**: bot başına ~10 eşleştirme, ortak havuz 80–100 ADAY hedefi;
   aktif sayısı erişim testlerine bağlı, doğrulanmamış aday "aktif" sayılmaz.
   Toplam-10 istenirse `academy_max_active_sources` config'i ile sınırlanabilir.
2. **Konu taksonomisi**: canlı `academy_topic_chk` 11 eski anahtar içeriyor ama
   prod'da satır YOK → CHECK, prompt'taki 10 Akademi konusu + `mizah` ile
   ADDITIVE genişletilir (eski anahtarlar geçerli kalır, migration düzenlenmez).
3. **Yayın sıklığı**: config'te; "her bot her gün 2" ZORUNLU DEĞİL
   (günlük toplam hedef 6, bot başı üst sınır 2, mizah 1, kalite eşiği önce).
4. **JS-render/OCR/video-transkript**: v1 kapsam DIŞI (Edge runtime'a
   sıkıştırılmaz); bu erişim yöntemini gerektiren kaynak `paused/degraded`
   olarak dürüstçe işaretlenir.
5. **Görsel**: v1 sırası = izinli kaynak fotoğrafı (yalnız izin kaydı varsa) →
   Pexels (anahtar varsa) → programatik bilgi kartı (satori+resvg) →
   görselsiz metin postu. Görsel üretim API'si (ücretli) v1'de kapalı.
6. **Canlı yayın**: `academy_dry_run=true` + `academy_enabled=false`
   varsayılanıyla kurulur; gerçek feed'e yayın yalnız kullanıcı onayıyla açılır.
7. **DeepSeek**: anahtar `DEEPSEEK_API_KEY` (edge secret). Yoksa üretim hattı
   fail-closed; fixture testleriyle doğrulanır. Model adı resmî dokümandan
   uygulama sırasında doğrulanır.

## Plan (fazlar)

- **Faz 1**: `academy_content_engine_v1` migration — bot tablo genişletme
  (subtopics/style/is_humor/allow_dm), `academy_sources`,
  `academy_bot_sources`, `academy_content_items`, `academy_drafts`,
  `academy_media`, `academy_jobs`(+runs, lease/dedupe), `academy_usage_daily`,
  `academy_engagement_prefs`; config anahtarları `app_runtime_config`'e;
  service-role RPC'ler (claim/complete/publish, idempotent yayın);
  `find_or_create_direct_conversation`'a is_bot+allow_dm kuralı;
  11 bot idempotent seed. İzole PG test paketi `supabase/tests/academy_engine/`.
- **Faz 2**: 40 aday kaynak sicil seed'i + yerel doğrulama probe script'i +
  makinece okunabilir rapor (`docs/academy/source_verification.json`).
- **Faz 3**: `academy-worker` edge fn (kuyruk tüketici: scan→classify→draft→
  media→publish), DeepSeek istemcisi (JSON şema doğrulamalı), bilgi kartı
  üretici, pg_cron tanımları, bütçe sayaçları, dry-run guard (server-side).
- **Faz 4**: Flutter — academy okuma katmanı + feed bot rozeti + FırınNet
  Akademi toplu profil sayfası (konu filtresi, sayfalama, boş/hata durumları) +
  Mizah profili; PR #102'nin kullanışlı desenleri güncel main'e yeniden yazılır.
- **Faz 5**: Mizah etkileşim kuralları (yanıt/kendiliğinden yorum/DM),
  hız+bütçe sınırları, bot-bot döngü engeli, ciddi-konu filtresi.
- **Faz 6**: testler (izole PG + Flutter + fixture), analyze, tam suite, CI,
  üç-durumlu teslim raporu.

## Tamamlananlar

- 2026-09-28: Keşif (yukarıdaki tablo). Branch `feature/academy-engine-v1`.
- **Faz 1** (26f5d65): `20260929090000_academy_content_engine_v1.sql` —
  tablolar+RLS+RPC'ler+11 bot seed; DM bot istisnası; izole PG paketi
  `supabase/tests/academy_engine/` (01-06).
- **Faz 2** (80f7d90): 41 aday kaynak (`sources_candidates.json` → üretilen
  `20260929100000_academy_sources_seed_v1.sql`, 70 bot eşleştirmesi);
  canlı probe `scripts/academy_probe_sources.ps1` →
  `source_verification.json`: **feed=7 sitemap=12 html=13 unreachable=9 /41**.
- **Faz 3**: `supabase/functions/academy-worker/` (lib.ts saf mantık +
  index.ts IO; deno test 12/12), `20260929110000_academy_cron_v1.sql`
  (academy_cron_tick + pg_cron 30dk, Vault academy_worker_url/key,
  fail-soft), PG testleri 07-08. DeepSeek: model env `DEEPSEEK_MODEL`
  (varsayılan `deepseek-flash`; resmî docs 2026-09: deepseek-flash /
  deepseek-v4-pro), `response_format json_object`, bütçe sayaçları.
  **Kapsam dışı bırakılanlar (bilinçli, raporda)**: görsel üretimi
  (info-card dahil) v1'de YOK → metin-postu; JS-render/OCR/video yok.

- **Faz 4** (513beac): Flutter — AcademyPage (/academy, filtre+sayfalama+
  boş/hata), SocialPostCard bot rozeti + akademi yönlendirme, profil AI
  rozeti + Mesaj gating, model 22 konu; academy testleri 13/13, analyze 0.
- Örnek içerikler: `docs/academy/sample_posts.md` (biçim örneği; model
  üretimi DEĞİL — anahtar yok).

## Sıradaki adım (Faz 4-6)

1. Flutter: `lib/features/academy/` okuma katmanı (PR #102 deseni güncel
   main'e yeniden yazılır: AcademyRepository/Supabase/providers + model
   subtopics/is_humor/allow_dm alanları) + feed kartında AI/Akademi rozeti
   (`social_post_card.dart`) + `/academy` toplu profil sayfası (konu
   filtreleri = bot chip'leri, cursor sayfalama feed_posts owner_id in
   botIds, boş/hata/loading) + router + profil sayfasında bot davranışı
   (academyBotProfileProvider; bot profilinde DM butonu yalnız allow_dm).
2. Flutter testleri: academy sayfa/rozet/filtre/sayfalama/boş-hata;
   mevcut 2497 test regresyonsuz; analyze.
3. PR aç (feature/academy-engine-v1), CI, teslim raporu (3-durum:
   kod/dış entegrasyon/canlı işletim). MERGE + prod migration + deploy +
   cron/vault/secret kurulumu = KULLANICI ONAYI (canlı yayın yetkisi yok).

## V1.1 devam turu — 6 hata sınıfı kapatıldı (2026-09-28, 28ba3c8+d9784e4)

1. dry_run_done→canlı: publish RPC aynı taslağı güncel şartlarla yayımlar
   (PG 04-P8). 2. RSS'siz keşif: discoverArticles (sitemapindex tümü
   cursor'la, HTML keşfi, kategori/çerez reddi) — probe v3 AYNI worker
   koduyla canlı: **53/91 içerik-kanıtlı** (konu başına 4-14; zayıflar
   turk_urunleri 4, ustalik_dunya 5). 3. İddia denetimi: quote-kanıt +
   tam-sayı sınırı + birim sınıfı + boş-claims/teknik reddi + tüm görünür
   alanlar. 4. Kart hatasında media_ready YOK + publish medya satırını
   doğrular (04-P9). 5. Q8-Q11: max-attempt dead+neden, config_blocked
   toparlanma, dead-döngü koruması, degraded ×4 backoff. 6. Tek cron
   isteği (tick_and_process), sohbet önceliği, cooldown, turlar-arası
   yayın aralığı, atomik bütçe, genel tavan (04-P10). PG 9/9, deno 24/24.

## V1.1 tamamlama turu — SONUÇ (2026-09-28)

Tüm P1–P6 maddeleri uygulandı (aşağıdaki liste artık DONE durum kaydıdır):
P1 ad7a06e, P2+P3 a8b6a94, P5/P6 sonraki commit. Kanıtlar: PG paketi 9
dosya ALL PASS (91 kaynak/155 eşleştirme, stale-worker, partial-dedupe,
atıf, B/C/E diyalogları); deno 18/18 + typecheck; kartlar GERÇEK render
(docs/academy/preview/*.png — TR karakter/taşma gözle OK); analyze 0.
Kalan canlı doğrulamalar (anahtar/deploy gerektirir): gerçek DeepSeek
çağrısı, prod Storage yüklemesi, cihazda feed görünümü.

## V1.1 orijinal eksik listesi (kapatıldı — tarihçe)

Durum doğrulaması: yerel=uzak=PR#110 head 50352bc; main 6c878c1; harici
(ChatGPT) değişiklik GitHub'a ULAŞMAMIŞ; PR #102 açık bırakıldı.

- [ ] P1 DB: complete_job stale-worker guard'ı; jobs dedupe index'i PARTIAL
  (queued/running) → dry-run→canlı + ertesi-gün + anahtar-sonrası yeniden
  kuyruklama açılır; publish/humor günlük sayaçlarına advisory lock (yarış);
  yayında kullanıcı-görünür KAYNAK atfı (ad+doğrulanmış URL+ticari not+tarih
  bağlamı); academy_extend_lease; mizah reply/DM RPC'leri (gönderim-anı
  yeniden doğrulama + tek-seviye yorum + duplicate-event).
- [ ] P2 Worker: bütçe günü Istanbul (UTC bug); per-feed-URL ETag/LM
  (kaynak-geneli tek etag bug'ı); robots.txt disallow uygulaması; indirme
  sırasında akış boyut sınırı; kaynak 'active' YALNIZ gerçek makale
  çıkarımından sonra; bot seçimi adil dağılım (ilk-konu bug'ı); claim batch
  küçült + iş başına lease uzatma (sıralı işleme süre aşımı); iddia-kaynak
  otomatik denetimi (sayı/oran metinde yoksa publishable=false); uydurma URL
  reddi domain değil doğrulanmış-URL bazlı; arşiv tarama cursor'u.
- [ ] P3 Görsel: resvg-wasm + gömülü TTF ile deterministik PNG bilgi/mizah
  kartı (sarı-beyaz, TR karakter); storage→academy_media→feed_media hattı;
  en az 1 Akademi + 1 Mizah kartı GERÇEK render + gözle kontrol.
- [ ] P4 Mizah B–E: kendi postuna yorum cevabı, DM cevabı, kendiliğinden
  yorum tetiği (maintenance event tarama), izinli kendiliğinden DM; tümü
  gönderim anında yeniden doğrulama + testler.
- [ ] P5 Kaynak: 41→80-100 aday (publisher_group tekilleştirme, TR somut);
  probe v2 içerik-çıkarım kanıtı (örnek URL+başlık+metin uzunluğu+tarih) →
  canlı rapor; seed yenile.
- [ ] P6 Flutter: Ayarlar'da mizah yorum/DM tercihleri (prefs tablosu RLS'i
  hazır); tüm test paketleri; PR güncelle; kanıtlı rapor.

## Kurulum (canlı etkinleştirme — henüz YAPILMADI)

1. `supabase functions deploy academy-worker` (verify_jwt default ON kalsın
   mı? Hayır: cron token'la çağırır → `--no-verify-jwt` gerek).
2. Secrets: `ACADEMY_WORKER_TOKEN` (rastgele), `DEEPSEEK_API_KEY`,
   (ops) `DEEPSEEK_MODEL`.
3. Vault: `academy_worker_url` = https://<ref>.supabase.co/functions/v1/academy-worker,
   `academy_worker_key` = ACADEMY_WORKER_TOKEN değeri.
4. Migration'lar prod'a; `academy_enabled=true` (dry_run=true ile önce
   kuru koşu; feed'e yayın için `academy_dry_run=false`).
5. Acil durdurma: `academy_enabled=false` (tick+publish+humor hepsi durur).
