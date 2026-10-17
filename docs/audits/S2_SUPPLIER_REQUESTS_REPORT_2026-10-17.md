# S2 — Tedarikçi Talep Yönetimi ve Ticari Fırsatlar: Sprint Raporu

**Tarih:** 2026-10-17 · **Dal:** `feat/supplier-requests-s2` (base: `feat/supplier-panel-s1` → `audit/system-audit-2026-10-16` → main) · **Durum:** TAMAMLANDI, onay bekliyor · **Main merge / prod deploy / DB migration:** YOK (ayrı onay)

PR zinciri: `feat/supplier-panel-s1 → main` (S1) ve `feat/supplier-requests-s2 → feat/supplier-panel-s1` (S2, S1'e bağımlı).

## 1. Mevcut işleyiş doğrulaması (kod + canlı DB)

| Soru | Doğrulanmış yanıt | Kanıt |
|---|---|---|
| Talebi kim oluşturur? | Tedarikçi olmayan her rol (alıcı): `b2b_qr_insert_own` (`buyer_id = auth.uid()`); UI `showB2bOfferFlow(requestQuote/askPrice)` | `b2b_quote_requests` policy `[CANLI]`, `b2b_offer_bottom_sheet.dart` |
| Hangi tedarikçiler görür? | **Tüm** authenticated kullanıcılar, yalnız `b2b_open_quote_requests()` RPC ile: `status ∉ (closed,cancelled)` ve `accepted_reply_id is null`; `buyer_id` dönmez. Kategori/bölge filtresi sunucuda yok. Tedarikçi tabloyu doğrudan okuyamaz (select yalnız buyer) | RPC tanımı `[CANLI]` |
| Kim yanıt verir? | Kendi mağazası olan tedarikçi: `b2b_replies_insert` = own shop ∧ `b2b_request_accepts_reply` (open/answered ∧ karar yok) ∧ `can_reply_b2b_quote` (aylık kota); talep başına tek yanıt (unique) | policy + `20260622160000` |
| Kendi yanıtlarını nasıl takip eder? | **S2 öncesi: edemiyordu.** Yalnız lead'ler (alıcı "İlgileniyorum" derse) görünüyordu. `b2b_replies_select` kendi mağazasının yanıtlarını okumaya zaten izin veriyordu; UI/sorgu yoktu | S2: `listMyQuoteReplies()` |
| Talep ne zaman tamamlanmış sayılır? | `accepted_reply_id` dolunca (karar) veya alıcı `closed/cancelled` yapınca; her iki durumda RPC listesinden düşer. `answered` yalnız "en az bir yanıt var" demektir | RPC + `trg_b2b_reply_answered` |
| Kabul edilen teklif nasıl belirlenir? | Yalnız alıcı, `b2b_accept_quote_reply(p_reply_id)` RPC ile: `accepted_reply_id` set + o yanıt `accepted/status=accepted`, diğerleri `declined`; `trg_notify_b2b_accept` tedarikçiye bildirim. Lead şart değil (ayrı buton) | RPC tanımı `[CANLI]`, `buyer_quote_detail_screen.dart:488-530` |
| RLS neye izin verir? | Tedarikçi: shops (own), products/campaigns (own write, published read), replies (own insert/update/select), leads (own shop select), requests (hiç). Alıcı: requests (own), replies (own request select), leads (own update) | `pg_policies` `[CANLI]` |

**Kritik kısıt (S2 tasarımını belirledi):** Tedarikçi, yanıtladığı ama artık açık olmayan (kapanmış / karar verilmiş) bir talebin ayrıntısını **okuyamaz** (tablo RLS buyer-only, RPC yalnız açık). Lead varsa `b2b_quote_leads` denormalize alanları (kategori/miktar/il) kullanılır; yoksa yalnız kendi yanıtı gösterilir ve kart bunu açıkça söyler ("Talep artık açık değil"). Yanıltıcı ekran üretilmedi; kalıcı çözüm S3 önerisi (§7).

## 2. Eski ve yeni talep yönetimi

| | Eski "Teklif Ağı" | Yeni "Talepler" (S2) |
|---|---|---|
| Segmentler | Açık Talepler · İlgilenenler | **Yeni (n) · Yanıtladıklarım (n) · İlgilenenler (n) · Kazanılan (n)** — sayaçlı, 44px, yatay kaydırılabilir |
| Yanıt durumu | Yok; yanıtlanmışta da "Teklif Ver" görünüyordu, çift yanıt sunucudan 23505 ile dönüyordu | Yanıtlanan talep **Yeni'den düşer**; Yanıtladıklarım'da durum çipi: *Alıcı kararı bekleniyor / Teklifin seçildi / Başka teklif seçildi / Talep artık açık değil* |
| Talep tarihi | Yok | "3 sa önce / dün / 12 Eyl" (RPC `created_at`, `relativeTimeTr`) |
| Ürün bağlamı | Yok (`target_id` map edilmiyordu) | "Ürünün: X" / "Kampanyan: Y" / "Mağazana yönelik" (yalnız **kendi** nesnelerimle eşleşirse); başkasının hedefi için yalnız "Belirli bir tedarikçiye yönelik" (ad yok) |
| Filtre / arama | Yok | Metin (Türkçe-duyarlı normalize) + kategori + il chip'leri; seçenekler listedeki gerçek değerlerden |
| Kazanılan | Yalnız lead kartında küçük çip | Ayrı segment: `reply.accepted` (yalnız RPC set eder) + teklif özeti + varsa lead/telefon |
| Dokunma hedefleri | 38–40px | 44px (Teklif Ver, Alıcıya yanıt yaz, segmentler, filtre chip'leri) |
| Boş/hata | Jenerik | Segment başına anlamlı boş durum; filtreli boşta "Filtreyi temizle" CTA; tek `ErrorRetryState` (3 kaynağı birden yeniler) |

## 3. Değiştirilen dosyalar

| Dosya | Değişiklik |
|---|---|
| `lib/features/b2b_market/models/b2b_quote_request.dart` | `targetType`, `targetId`, `createdAt` (opsiyonel; mevcut çağrılar bozulmaz) |
| `lib/features/b2b_market/models/b2b_quote_reply.dart` | `status` (sent/accepted/declined enum), `createdAt`; `copyWith` tutarlılığı |
| `lib/features/b2b_market/models/supplier_requests_inbox.dart` | **Yeni** — saf gelen kutusu hesabı, hedef bağlamı, filtre modeli |
| `lib/features/b2b_market/repositories/{b2b_repository,supabase_b2b_repository,local_b2b_repository}.dart` | `listMyQuoteReplies()`; mapper: target/created_at/status; `_replyCols` ortak |
| `lib/features/b2b_market/providers/b2b_providers.dart` | `b2bMyRepliesProvider`, `supplierRequestsInboxProvider`, `supplierRequestsInboxRefresh` |
| `lib/features/b2b_market/screens/supplier/supplier_requests_tab.dart` | **Yeni** ekran (eski `supplier_offer_network_tab.dart` silindi) |
| `lib/features/b2b_market/widgets/b2b_lead_card.dart` | **Yeni** — lead kartı + `B2bOutcomeChip` (token renkleri) |
| `lib/features/b2b_market/widgets/b2b_quote_request_card.dart` | `dateLabel`, `contextChip`; alt satır Wrap (dar ekran), buton 44px; alıcı kullanımı değişmedi |
| `lib/features/b2b_market/widgets/b2b_meta_pill.dart` | `B2bStatusPill` metni Flexible (1.5x taşma) |
| `lib/features/b2b_market/screens/b2b_shell_screen.dart` | Sekme etiketi "Teklif Ağı" → "Talepler" (anahtar zaten `talepler`) |
| `lib/features/dashboard/widgets/supplier_panel_home.dart` | KPI → gelen kutusu kaynağı (§5) |
| `lib/core/constants/app_strings.dart` | 40 yeni S2 string'i; KPI etiketleri |
| `test/supplier_requests_s2_test.dart`, `test/golden/supplier_requests_s2_capture_test.dart`, `test/b2b_market_preview_test.dart`, `test/supplier_panel_home_test.dart` | Testler |

Yeni tablo, RPC, migration **yok**.

## 4. Yeni kullanıcı akışları

1. **Panel → "Yanıt bekleyen" KPI / "Talepleri gör"** → `/pazar?tab=talepler` → Yeni segmenti (yalnız yanıtlamadıklarım) → kartta tarih + bağlam → **Teklif Ver** (mevcut sheet; kota paywall'ı korunur) → kart Yeni'den düşer, Yanıtladıklarım'a "Alıcı kararı bekleniyor" ile girer; Panel KPI düşer.
2. **Yanıtladıklarım** → alıcı ilgilenirse kartta "Alıcı teklifinle ilgileniyor" satırı; **İlgilenenler** segmentinde telefon (onaylıysa) + "Alıcıya yanıt yaz" (mevcut lead mini-chat).
3. **Alıcı "Bu teklifle ilerle"** → bildirim (mevcut) → **Kazanılan** segmenti ve Panel'de ilgili sayı; Yanıtladıklarım'da "Teklifin seçildi"; kaybedilenlerde "Başka teklif seçildi".
4. **Filtre/arama** → kategori veya il chip'i (toggle), metin arama; eşleşme yoksa "Filtreye uyan talep yok" + temizle.

## 5. S1 paneliyle entegrasyon

- Panel KPI "Açık talep" → **"Yanıt bekleyen"** = `inbox.fresh.length` (yanıtlamadığım, aktif). Yardımcı metin: **"Ağda N açık talep"** (toplam, yanıtladıklarım dahil). İki sayı ayrı kavram olarak etiketlenir, karıştırılmaz.
- KPI ve Talepler sekmesi **aynı provider'ı** (`supplierRequestsInboxProvider`) kullanır → sayılar her zaman tutarlı; teklif verildiğinde `b2bMarketControllerProvider` revizyonu ikisini birlikte yeniler.
- "İlgilenen" KPI'si da aynı kaynaktan; Panel hata yenileme üç provider'ı birden invalidate eder.

## 6. Test ve CI sonuçları

| Kontrol | Sonuç |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` S2 + B2B + panel dosyaları (6 dosya) | 84/84 |
| `flutter test --exclude-tags golden` (CI komutu, son ağaç) | **2974/2974 geçti** |
| `flutter build apk --debug` (CI adımı) | ✅ app-debug.apk üretildi |
| `flutter test test/golden/supplier_requests_s2_capture_test.dart` | 5/5, PNG üretildi |

Yeni testler (24): gelen kutusu (Yeni = aktif − yanıtlanan; lead özeti / requestUnavailable; Kazanılan/İlgilenenler), hedef bağlamı (ürünüm/başkası/kategori; başkasının adı asla), filtre seçenekleri + Türkçe-duyarlı arama, mapper (target/status/created_at), widget: segmentler, Yeni listesi (kapalı talep yok, "@" yok), Yanıtladıklarım dürüst kart, teklif verince segment geçişi, chip filtre + temizle, arama boş durumu, İlgilenenler/Kazanılan boş, hata → retry, shell `?tab=talepler`, 320px 1.0/1.3/1.5x taşma; Panel KPI = gelen kutusu.

## 7. Güvenlik değerlendirmesi

Ayrıntı: `S2_SECURITY_RECHECK_2026-10-17.md`. Özet: canlı policy/trigger durumu S1 ile aynı (3 bulgu geçerli; canlı tablolar boş). S2 yalnız okuma ekler, riski artırmaz; ancak tedarikçinin insert'te `accepted=true` göndermesi kendi "Kazanılan" ekranını yanıltabilir → guard gerekli. **Taslakta eksik bulundu:** requests guard'ı `open→answered` geçişine (`trg_b2b_reply_answered`) izin vermeli, yoksa teklif verme kırılır; düzeltilmiş plan + geri alma adımları dokümanda. **Migration uygulanmadı; onayınızı bekliyor.**

## 8. Görsel çıktılar

`docs/audits/s2/`: `requests_fresh_390.png` (Yeni, filtre + anonimlik notu + kartlar), `requests_replied_390.png` (Yanıtladıklarım: "Talep artık açık değil" + "Teklifin seçildi"), `requests_interested_390.png` (lead + telefon + CTA), `requests_won_390.png` (Kazanılan), `requests_fresh_320_x1_3.png` (320px, 1.3x). Not: yakalama ortamında `FilledButton` etiketi font fallback'i nedeniyle kutu çizer (yalnız PNG artefaktı; cihazda normal — S1 ile aynı).

## 9. Çözülmeyen riskler / sınırlar

1. Kapanmış/karar verilmiş talebin ayrıntısı tedarikçiye **erişilemez** (RLS/RPC tasarımı) → "Talep artık açık değil" kartı; kalıcı çözüm S3 RPC (migration, onay).
2. Yeni talep için **push/in-app bildirim yok** (yalnız lead/mesaj/kabul); tedarikçi Panel'e girmeden haberdar olmaz.
3. Talep listesi hâlâ **global ve sayfalamasız** (RPC); filtre istemci tarafında. Ölçekte RPC filtresi/sayfalama gerekir.
4. Başka tedarikçiye yönelik talepler (ürün/mağaza hedefli) listede kalır; yalnız etiketlenir. Ürün sahibinin görmesi istenmiyorsa RPC'de hedef filtresi (S3 kararı).
5. Yakalama ortamı buton fontu (artefakt).

## 10. S3 önerileri

1. **RPC `b2b_my_replied_requests()`** (SECURITY DEFINER, anonim: kategori/miktar/il/durum/accepted_reply_id, yalnız çağıranın mağazasının yanıtladığı talepler) → Yanıtladıklarım/Kazanılan kartlarında tam bağlam; + `b2b_open_quote_requests(p_category[], p_city[], p_limit, p_offset)` sayfalama/filtre. (Migration — onay.)
2. **Yeni talep bildirimi**: `b2b_quote_requests` AFTER INSERT trigger → kategori/bölge eşleşen aktif mağazalara in-app + push (`push-dispatch`). (Migration — onay.)
3. **Guard migration** (S1 taslağı + S2 düzeltmesi) + RLS smoke; ardından mağaza profilinde "Doğrulanmış" rozeti (backoffice onaylı).
4. Ürün/kampanya yönetimi (S1 planındaki S3): silme, çoğaltma, kampanya `linked_product_id` kaydı (bug), formlarda guard.
5. Mağaza profili: il/ilçe/telefon/web; alıcı detayında "Mesaj gönder".
6. UX küçük: KPI etiketleri 2 satır (1.5x), Talepler'de "son görülen" işareti (yerel), lead mini-chat'in Mesajlar'a bağlanması (orta boy).
