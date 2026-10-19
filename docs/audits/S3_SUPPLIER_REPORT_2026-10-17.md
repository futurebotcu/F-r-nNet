# S3 — Güvenlik, Veri Bütünlüğü ve Eksik İşlevler: Sprint Raporu

**Tarih:** 2026-10-17 · **Dal:** `feat/supplier-s3` (base `feat/supplier-requests-s2` → `feat/supplier-panel-s1` → main) · **Durum:** TAMAMLANDI, onay bekliyor · **Main merge / production deploy / canlı migration:** YOK

PR zinciri: #117 S1→main · #118 S2→S1 · S3→S2 (bu PR). Migration ve güvenlik değişiklikleri ayrı dokümanda: `S3_SECURITY_MIGRATION_PLAN_2026-10-17.md`.

## 1. Tespit edilen sorunlar ve çözümler

| # | Sorun (doğrulanmış) | Çözüm | Nerede |
|---|---|---|---|
| 1 | Tedarikçi, yanıtladığı ama kapanmış/karar verilmiş talebin ayrıntısını göremiyordu (RLS buyer-only, RPC yalnız açık) | Minimum yetkili RPC `b2b_my_replied_requests()` (yalnız çağıranın mağazası; `buyer_id`/diğer cevaplar/telefon yok; `decision` won/lost/closed/pending). İstemci RPC yoksa S2 davranışına düşer | migration §4; `supabase_b2b_repository.dart` `listMyRepliedRequests`, `SupplierRequestsInbox.build(history:)` |
| 2 | S1/S2 güvenlik bulguları: `is_verified` sahip-yazılabilir; reply INSERT'te `accepted/status` serbest; alıcı `accepted_reply_id`/`status` doğrudan yazabilir | 3 BEFORE trigger guard + durum geçiş matrisi (open/answered→closed/cancelled alıcı; open→answered yalnız `b2b_mark_request_answered` GUC işaretli) | migration §2a–2d |
| 3 | **S2 kontrolünde öngörülen kırılma:** guard, `trg_b2b_reply_answered`'ın open→answered geçişini engellerdi | `b2b_mark_request_answered` transaction-local `b2b.reply_write=on` set eder; harness G2 teklif verince `answered` olduğunu doğrular | migration §2d |
| 4 | **Yeni bulgu — yarış koşulu (harness ile kanıtlandı):** mevcut `b2b_accept_quote_reply` talep satırını kilitlemeden okuyor; iki eşzamanlı kabul ikisi de başarılı oluyor, ikincisi birincinin kararını eziyor ve her iki tedarikçiye "seçildi" bildirimi gidiyor | `FOR UPDATE OF qr` + `where accepted_reply_id is null` + `if not found → already decided` | migration §2e; harness `conc_accept_a/b` + 15 |
| 5 | Açık talep listesi global ve sayfalamasız (31 sorgu/0 limit) | `b2b_open_quote_requests_page(cat[], city[], exclude_replied, limit≤100, offset)` + `count(*) over()`; partial index (kategori, il, tarih) | migration §3, §5; `_FreshList` "Daha fazla talep yükle" |
| 6 | Panel KPI ile Talepler sayısı istemci hesabı; ölçekte sapabilir | `b2b_supplier_request_counts()` tek sunucu sayısı; UI RPC yoksa istemci hesabı | migration §5b; `SupplierRequestsInbox.freshCount` |
| 7 | Yeni talep için bildirim yok | Mevcut `notifications` tablosu + mevcut push webhook; hedefleme (mağaza/ürün/kampanya hedefli → yalnız hedef; kategori → eşleşen aktif mağazalar), alıcının kendi mağazası hariç, `(recipient, entity)` dedupe, 10/saat yoğunluk kapağı, generic metin | migration §6 |
| 8 | Ürün silme/çoğaltma yoktu | "Yönet" menüsü: Çoğalt (taslak kopya, kota sunucuda) · Sil (onay dialogu, geri alınamaz uyarısı); kampanya Sil | `b2b_meta_pill.dart`, `b2b_manage_actions.dart`, kart/sekme bağlantıları |
| 9 | Kampanya "bağlı ürün" serbest metin ve **hiç kaydedilmiyordu** | Kendi ürünlerimden seçici → `linked_product_id` yazılır/okunur (FK embed ile ad) | `supplier_campaign_form_screen.dart`, repo add/update/mapper |
| 10 | Mağaza iletişim alanları yoktu; mağaza formunda çift-gönderim/dirty guard yoktu | `phone, whatsapp, website, address` (nullable + CHECK) + form alanları (doğrulama: telefon ≥10 rakam, web host) + `_saving` + `DirtyFormGuard`; alıcı detayında Ara/WhatsApp/Web (44px) + adres; gizlilik notu | migration §1; `supplier_store_edit_screen.dart`, `b2b_store_contact.dart`, `b2b_store_detail_screen.dart` |

## 2. Değiştirilen dosyalar

**Supabase:** `supabase/migrations/20261017120000_b2b_s3_requests_v1.sql` (yeni, uygulanmadı) · `supabase/tests/b2b_requests_s3/` (harness: `run_tests.ps1`, `00_harness_b2b.sql`, `01_notify_b2b_live_subset.sql`, `02_harness_post.sql`, `sql/10..15`, `conc_*`)

**Flutter — veri:** `models/b2b_replied_request.dart` (yeni), `models/b2b_store.dart` (+iletişim), `models/b2b_campaign.dart` (+`linkedProductId`), `models/supplier_requests_inbox.dart` (history/serverCounts/decision), `repositories/b2b_repository.dart`, `supabase_b2b_repository.dart`, `local_b2b_repository.dart`, `providers/b2b_providers.dart`

**Flutter — UI:** `widgets/b2b_manage_actions.dart` (yeni), `widgets/b2b_store_contact.dart` (yeni), `widgets/b2b_meta_pill.dart`, `b2b_product_card.dart`, `b2b_campaign_card.dart`, `screens/supplier/forms/supplier_campaign_form_screen.dart`, `supplier_store_edit_screen.dart`, `screens/supplier/supplier_requests_tab.dart`, `supplier_products_tab.dart`, `supplier_campaigns_tab.dart`, `supplier_store_tab.dart`, `screens/detail/b2b_store_detail_screen.dart`, `dashboard/widgets/supplier_panel_home.dart`, `core/constants/app_strings.dart` (+44 string)

**Testler:** `test/b2b_s3_migration_contract_test.dart`, `test/supplier_s3_test.dart`, `test/golden/supplier_s3_capture_test.dart`, `test/supplier_requests_s2_test.dart` (geçmiş RPC var/yok varyantı)

## 3. Yeni RPC ve migration tasarımları

Ayrıntı ve geri alma: `S3_SECURITY_MIGRATION_PLAN_2026-10-17.md`. Özet imzalar:

```sql
b2b_my_replied_requests() → (request_id, category, quantity, city, district, buyer_type,
  delivery_time, note, request_status, request_created_at, target_type, target_id,
  my_reply_id, my_reply_status, my_reply_accepted, my_reply_created_at, decision)
b2b_open_quote_requests_page(p_categories text[], p_cities text[], p_exclude_replied bool,
  p_limit int, p_offset int) → açık talep satırları + total_count
b2b_supplier_request_counts() → (fresh_count, network_open_count)
```
Hepsi `SECURITY DEFINER`, `search_path=''`, yalnız `authenticated/service_role`; `auth.uid()` zorunlu.

**İstemci uyumluluğu:** RPC bulunamazsa (`PGRST202`) repo `null` döner ve UI S2 davranışına düşer → migration'dan önce/sonra aynı app sürümü çalışır; zorunlu güncelleme yok.

## 4. Güvenlik ve RLS testleri

İzole PostgreSQL 18 (port 55434, üretime bağlanmaz): production şema replikası + gerçek B2B migration zinciri + S3 (idempotency için 2 kez). Sonuç: **ALL B2B S3 TESTS PASSED** (10 seed · 11 guard/geçiş/kota 10 blok · 12 geçmiş RPC 4 blok · 13 sayfalama/sayaç 2 blok · 14 bildirim 5 blok · 15 eşzamanlılık 2 senaryo). Öne çıkanlar:

- Çift teklif → `unique_violation`; karar verilmiş talebe teklif → RLS red; başka mağaza adına → RLS red.
- Tedarikçi/başka alıcı kabul → `not your request`; ikinci kabul → `already decided`; **eşzamanlı kabul yarışı** → tek kabul.
- Free toptancı aylık 3 cevap, 4. → RLS red (kota).
- Geçmiş RPC: başka mağaza cevabı sızmaz; `buyer_id`/`phone`/`accepted_reply_id` kolonu yok; anon → EXECUTE yok.
- Bildirim: hedefleme/dedupe/yoğunluk/pasif mağaza/kendi mağazası.

Dart tarafı: `b2b_s3_migration_contract_test.dart` (kaynak sözleşmesi) + `supplier_s3_test.dart`.

## 5. Test ve CI sonuçları

| Kontrol | Sonuç |
|---|---|
| `flutter analyze` | No issues found |
| SQL harness (`run_tests.ps1`) | ALL B2B S3 TESTS PASSED |
| S3 + S2 + panel test dosyaları | 48/48 |
| `flutter test --exclude-tags golden` (CI komutu) | **3003/3003 geçti** (2026-10-19, final ağaç) |
| `flutter build apk --debug` (CI adımı) | ✅ app-debug.apk üretildi (Gradle assembleDebug 107 s) |
| S3 PNG yakalama | 5/5 → `docs/audits/s3/` |

## 6. S1–S3 entegrasyon durumu

- Panel KPI (S1) → `freshCount` sunucu sayacı (S3) varsa onu, yoksa gelen kutusu (S2) hesabını kullanır; Talepler sekmesiyle aynı provider.
- Talepler (S2) → Yeni: sunucu sayfalama (S3) varsa "Daha fazla talep yükle" + sayaç; Yanıtladıklarım/Kazanılan: geçmiş RPC varsa kapanmış taleplerin tam bağlamı ("Talep artık açık değil" yalnız fallback'te).
- Mağazam/Ürünler/Kampanyalar: tüm kartlarda aynı Yönet menüsü (Düzenle · Taslağa al/Yayına al · Çoğalt · Sil).
- Mağaza detayı (alıcı): Teklif iste + Ara/WhatsApp/Web; sahibi: düzenle/ekle aksiyonları değişmedi.
- Regresyon: S1/S2 testleri geçiyor; S2 testine geçmiş-RPC var/yok iki varyant eklendi.

## 7. Production'a çıkış için kalan riskler

1. **Migration uygulanmadı** (onay). Uygulanana kadar: guard'lar yok (S1 bulguları açık), yarış koşulu canlıda mevcut (tablolar boş, risk düşük), geçmiş/sayfalama/bildirim pasif (UI fallback).
2. Yeni talep push'u mevcut `push-dispatch` yapılandırmasına bağlı; FCM env eksikse yalnız in-app.
3. Ürün silme görseli storage'da kalır (orphan; `deleteIfOwned` çağrılmıyor) — düşük maliyet, S4 temizlik.
4. Kampanya `linked_product_id` başka tedarikçinin ürünüyle doldurulabilir (FK kabul eder; RLS select izin vermediği için ad görünmez) — kozmetik; guard istenirse trigger.
5. Sayfalama modunda kategori/il chip seçenekleri ilk sayfadan türetilir (S2 davranışı); sunucu "distinct" RPC'si S4 adayı.
6. Emülatör/cihaz smoke yapılmadı (ortam); widget-test PNG'leri + lokal PG harness ile doğrulandı.
7. Yakalama ortamı buton fontu artefaktı (cihazda normal).
