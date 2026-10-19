# S3 — Güvenlik Değişiklikleri ve Migration Planı (UYGULANMADI)

**Tarih:** 2026-10-17 · **Dosya:** `supabase/migrations/20261017120000_b2b_s3_requests_v1.sql` · **Durum:** repo'da hazır, **production'a uygulanmadı** (ürün sahibi onayı bekliyor) · **Davranış kanıtı:** `supabase/tests/b2b_requests_s3/run_tests.ps1` (izole yerel PostgreSQL 18; production'a bağlanmaz)

## 1. İçerik (hepsi additif)

| # | Değişiklik | Neden | Geri alma |
|---|---|---|---|
| 1 | `b2b_supplier_shops` + `phone, whatsapp, website, address` (nullable) + uzunluk CHECK | Mağaza iletişimi (S3-6) | drop column (veri: yalnız yeni alanlar) |
| 2a | `trg_b2b_shops_guard_columns` (BEFORE UPDATE): `is_verified`/`owner_id` yalnız service_role | S1 F1 | drop trigger/function |
| 2b | `trg_b2b_replies_guard_insert` (BEFORE INSERT): `status:='sent'`, `accepted:=false` | S1 F3 (sahte "kabul") | drop trigger/function |
| 2c | `trg_b2b_qr_guard_columns` (BEFORE UPDATE): `accepted_reply_id` yalnız RPC; `buyer_id` sabit; status yalnız open/answered→closed/cancelled | S1 F4 | drop trigger/function |
| 2d | `b2b_mark_request_answered` GUC `b2b.reply_write=on` set eder → open→answered meşru | S2 kontrolünde tespit edilen kırılma | önceki tanıma dön (`20260618120000`) |
| 2e | **`b2b_accept_quote_reply` yarış koşulu düzeltmesi**: talep satırı `FOR UPDATE`, UPDATE `accepted_reply_id is null` şartlı, `if not found → already decided` | Harness `conc_accept` ile **gerçek hata** bulundu: iki eşzamanlı kabul ikisi de başarılı oluyor, ikincisi birincinin kararını eziyordu | önceki tanıma dön (`20260622160000`) |
| 3 | 3 index (açık talep kategori/il/tarih partial; cevaplar mağaza/tarih; aktif mağaza sahibi) | Sayfalama/geçmiş performansı | drop index |
| 4 | RPC `b2b_my_replied_requests()` | Tedarikçi teklif geçmişi (kapanmış/karar verilmiş dahil) | drop function |
| 5 | RPC `b2b_open_quote_requests_page(cat[], city[], exclude_replied, limit, offset)` + `b2b_supplier_request_counts()` | Sunucu filtre/sayfalama + KPI tutarlılığı | drop function |
| 6 | `notify_b2b_quote_request_created` (AFTER INSERT talep) + `notifications_b2b_qr_dedupe_idx` | Yeni talep bildirimi (mevcut notifications → mevcut push webhook) | drop trigger/function/index |

Veri değişikliği, drop table, delete YOK. İki kez uygulanabilir (harness idempotency adımı).

## 2. Minimum yetki / anonimlik

- Geçmiş RPC: yalnız `auth.uid()`'in mağazasının cevapladığı talepler; dönüşte `buyer_id`, `accepted_reply_id`, telefon/not yok; `decision` (won/lost/closed/pending) türetilmiş. Diğer tedarikçilerin cevapları/id'leri dönmez (harness H6/H7).
- Sayfalama RPC: `buyer_id` yok; `p_limit` 1–100'e, `p_offset` ≥0'a normalize; `auth.uid() is null` → boş.
- Tüm yeni fonksiyonlar `SECURITY DEFINER` + `set search_path = ''`; trigger fonksiyonları ve RPC'ler `anon`/`public`'ten revoke; RPC'ler yalnız `authenticated, service_role`.
- Bildirim metni generic (kategori · il), `actor_id null`, not/telefon yazılmaz; route `/pazar?tab=talepler`.

## 3. Bildirim tasarımı (mevcut altyapı, paralel sistem yok)

`notifications` INSERT → mevcut `push_dispatch_on_notification_insert` webhook → `push-dispatch` edge fn (değişmedi). Hedefleme: `target_type=shop/product/campaign` → yalnız hedef mağaza; `category` → kategorisi eşleşen aktif mağazalar; alıcının kendi mağazası hariç; pasif mağaza hariç. Tekrar: `(recipient_id, entity_id)` partial unique + `on conflict do nothing`. Yoğunluk: mağaza sahibi son 1 saatte ≥10 talep bildirimi aldıysa atlanır. (Harness N1–N5.)

## 4. Harness sonuçları (2026-10-17, lokal PG18, port 55434)

`prod_replica_schema.sql` → harness ek katmanı (stub drop + `auth.role()` mock) → gerçek B2B migration zinciri (7 dosya) + canlı notify alt kümesi → `20260712100000` → `20260923120000` → `20260925090000` → **S3 migration ×2** → testler:

| Dosya | Kapsam | Sonuç |
|---|---|---|
| 10_seed | 3 mağaza, 6 talep, 4 cevap, kabul + kapanış; open→answered trigger guard ile uyumlu | PASS |
| 11_guards_and_transitions | G1 is_verified/owner_id (sahip ✗, service_role ✓) + iletişim CHECK · G2 insert guard + open→answered · G3 accepted_reply_id/buyer_id/geçersiz geçiş ✗, closed/cancelled ✓, reopen ✗ · G4 çift teklif (unique), karar verilmiş talebe teklif ✗, başka mağaza adına ✗ · G5 tedarikçi/başka alıcı kabul ✗ · G6 meşru kabul + bildirim + ikinci kabul ✗ · G7 Free aylık 3 kota, 4. ✗ | PASS (10 blok) |
| 12_history_rpc | u9: 5 satır (lost/closed/pending/won doğru), kapanmış talep ayrıntısı var, başka mağaza cevabı sızmaz, kolon adlarında buyer_id/phone/accepted_reply_id yok; u11 won; mağazasız boş; anon ✗ | PASS |
| 13_paging_and_counts | tüm açık 8 / yeni 6; sayaç RPC aynı; kategori 5; il 1; limit/offset; sınır normalizasyonu; sıralama; eski RPC ile tutarlı | PASS |
| 14_notifications | hedefleme (Maya→A, Un→A+B, shop→B), kendi mağazası hariç, dedupe, yoğunluk kapağı, pasif mağaza | PASS |
| conc_accept_a/b + conc_dup_reply_a/b + 15 | **Eşzamanlı kabul → ikincisi 'already decided' (düzeltme öncesi: ikisi de başarılı)**; eşzamanlı çift teklif → unique_violation | PASS |

Çalıştırma: `powershell -File supabase\tests\b2b_requests_s3\run_tests.ps1` (≈40 sn).

## 5. Production'a uygulama planı (onay sonrası)

1. **Ön kontrol (salt-okunur):** `select count(*) from b2b_quote_replies where status<>'sent' and accepted=false` (tutarsız satır beklenmez); `select count(*) from b2b_supplier_shops where is_verified` (0). Canlı tablolar bugün boş (replies=0, requests=0).
2. **Uygulama:** MCP `apply_migration` ile tek dosya, tek transaction. Süre: milisaniye (tablolar boş; index'ler `if not exists`).
3. **Doğrulama:** `pg_trigger` (6 yeni trigger), `pg_proc` (yeni RPC'ler + accept/mark_answered yeni gövde), advisor security (yeni SECURITY DEFINER'lar authenticated'a yalnız RPC'ler için açık).
4. **Uygulama tarafı:** istemci RPC yoksa (PGRST202) otomatik S2 davranışına düşer; migration sonrası aynı sürüm sunucu özelliklerini kullanmaya başlar → **zorunlu app güncellemesi yok**.
5. **Geri alma:** dosya sonundaki ROLLBACK bloğu (veri kaybı yok; iletişim kolonları düşürülürse yalnız o alanlar kaybolur).

## 6. Kalan riskler

- Yeni talep bildirimi push'u `push-dispatch` edge fn'in FCM yapılandırmasına bağlı (mevcut durum korunur).
- Kategori eşleşmesi tam metin (`category = any(categories)`); serbest kategori adı girilirse (alıcı "Diğer" yazarsa) eşleşme olmaz → sessizce bildirim yok (tasarım gereği, spam yerine).
- Yoğunluk kapağı sabit (10/saat); config'e taşınabilir.
- `b2b_open_quote_requests` (eski RPC) korunur; yeni istemci sürümü sayfalama RPC'sini tercih eder.
