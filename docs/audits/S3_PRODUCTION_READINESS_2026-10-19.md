# Production Öncesi Son Güvenlik ve Entegrasyon Denetimi — Tedarikçi Paneli S1–S3

**Tarih:** 2026-10-19 · **Dal:** `feat/supplier-s3` · **Karar:** aşağıda (§6) · **Bu turda yapılmayanlar:** production migration, PR merge, canlı dağıtım.

## 1. PR zinciri

| PR | Head → Base | Durum | Commit | Çakışma |
|---|---|---|---|---|
| #117 | `feat/supplier-panel-s1` → `main` | OPEN, MERGEABLE/CLEAN | 6 | yok |
| #118 | `feat/supplier-requests-s2` → `feat/supplier-panel-s1` | OPEN, MERGEABLE/CLEAN | 5 | yok |
| #119 | `feat/supplier-s3` → `feat/supplier-requests-s2` | OPEN, MERGEABLE/CLEAN | 8 (bu denetim dahil) | yok |

- `main` (2934f4b) S1 dalının atası; main bu süreçte ilerlemedi. S3'ün main'e kuru birleştirmesi (`merge-tree`) **0 çakışma**.
- Zincirde tek migration: `20261017120000_b2b_s3_requests_v1.sql` (S3). S1/S2 şema değiştirmez. Migration'ın bağımlılıkları (`b2b_*` zinciri, `20260712100000`, `20260923120000`, `20260925090000`) main'de ve canlıda mevcut.
- **Birleştirme sırası:** #117 → #118 → #119 (her biri squash veya merge; base'ler otomatik güncellenir). Migration yalnız #119 merge'i sonrasında ve ayrı onayla uygulanır (§5).

## 2. Kritik güvenlik kontrolleri (kanıtlı)

Kanıt: `supabase/tests/b2b_requests_s3/run_tests.ps1` — izole PostgreSQL 18, production şema replikası + gerçek migration zinciri; 2026-10-19 tam koşu **ALL B2B S3 TESTS PASSED** (rollback ve yeniden uygulama fazı dahil).

| Kontrol | Sonuç | Test |
|---|---|---|
| Eşzamanlı kabulde yalnız bir teklif kazanır | ✅ İkinci oturum satır kilidinde bekler, `already decided` alır; tek `accepted` cevap. (S3 öncesi tanımda **ikisi de başarılıydı** — harness yakaladı, migration düzeltti.) | `conc_accept_a/b` + `15` C1–C3 |
| Eşzamanlı çift teklif (aynı mağaza) | ✅ `unique_violation`, tek satır | `conc_dup_reply_a/b` + C4–C5 |
| Başka tedarikçinin verisine erişim (RLS + RPC) | ✅ Geçmiş RPC yalnız kendi mağazası; başka mağazanın cevabı/id'si yok; dönüş kolonlarında `buyer_id`/`phone`/`accepted_reply_id` yok; mağazasız kullanıcı boş; anon EXECUTE yok; başka mağaza adına teklif RLS red | `12` H1–H12, `11` G4c |
| Kapanmış/karar verilmiş talebin yetkisiz değişimi | ✅ Alıcı `accepted_reply_id`/`buyer_id` yazamaz, `closed→open` yeniden açamaz, doğrudan `answered` yazamaz; karar verilmiş talebe teklif RLS red; tedarikçi/başka alıcı kabul RPC'si red | `11` G3, G4b, G5 |
| Tekrar çalıştırma (idempotency) | ✅ Migration ardışık 2 kez + rollback sonrası 3. kez hatasız | runner adımları |
| Rollback | ✅ `rollback_s3.sql`: S3 nesneleri düşer, S3 öncesi nesneler ve **veri** kalır, S3 öncesi akış (teklif→answered, kabul) çalışır; iletişim kolonları varsayılan olarak korunur | `16_rollback_asserts` |
| Bildirim hedefleme / dedupe / kota | ✅ Kategori→eşleşen aktif mağazalar; mağaza/ürün/kampanya hedefli→yalnız hedef; alıcının kendi mağazası hariç; `(recipient, entity)` partial unique + `on conflict do nothing`; 10/saat yoğunluk kapağı; pasif mağaza hariç; `actor_id null`, not/telefon yok | `14` N1–N5 |
| Guard trigger'ları client rollerinden revoke, `search_path=''`, SECURITY DEFINER | ✅ | `b2b_s3_migration_contract_test.dart` |
| Reply INSERT'te sahte `accepted/status` | ✅ `sent/false`'a zorlanır | `11` G2 |
| Aylık yanıt kotası (Free 3) | ✅ 4. teklif RLS red | `11` G7 |
| `is_verified` / `owner_id` | ✅ Sahip ✗, service_role ✓ | `11` G1/G1e |

## 3. Eksik kalan kontroller — bu turda tamamlananlar

| Kontrol | Sonuç |
|---|---|
| Sunucu sayfalama + filtre birlikte | ✅ Yeni testler: kategori∧il (5/0), filtre∧exclude_replied (1), filtre∧tümü (2), filtre∧sayfa (limit 2 offset 4 → 1/5), çoklu kategori/il dizileri (2), sınır normalizasyonu, sıralama (`13` P4b–P4g) |
| Uçtan uca alıcı–tedarikçi (S1↔S2↔S3) | ✅ `test/supplier_e2e_s1_s3_test.dart`: alıcı talep → Panel "Yanıt bekleyen" +1 → Talepler/Yeni'de kart → teklif → karttan düşer → alıcı ilgi + kabul → geçmiş kararı `won`, Kazanılan segmentinde, Panel "İlgilenen" +1, "Yanıt bekleyen" başlangıca döner |
| Silinen ürün görseli — storage temizliği | ✅ Strateji uygulandı: DB silme başarılıysa ve URL başka ürün/kampanyamda **paylaşılmıyorsa** (Çoğalt aynı URL'yi paylaşır) `deleteIfOwned` (yalnız `<uid>/…` yolu, best-effort, UI'a hata yansımaz); listeler bilinmiyorsa silme ATLANIR (güvenli taraf). Sunucu tarafı orphan süpürme S4 adayı (düşük maliyet) |
| Yeni talep bildirimlerinde FCM yapılandırması | ⚠️ **Buradan tam doğrulanamadı.** Canlı: webhook trigger `push_dispatch_on_notification_insert` aktif (O), `supabase_functions.hooks` 94 çağrı (son: 2026-09-30), 24 aktif push token, **`notification_push_deliveries` 0 satır**. Edge function env'i (`FIREBASE_SERVICE_ACCOUNT_JSON`, `PUSH_DISPATCH_KEY`) MCP'den okunamaz; Vault'ta push secret'ı yok (tasarım gereği, dashboard env). Teslimat satırı olmaması ya FCM env eksik/secret uyuşmazlığı ya da bildirimlerin silinmiş olmasından (cascade) kaynaklanabilir → **dağıtım sonrası manuel push smoke şart** (bir test talebi aç, tedarikçi cihazında push ve `notification_push_deliveries` satırı doğrula). In-app bildirim (zil/badge) FCM'den bağımsız çalışır. |

## 4. Production geçiş planı

**Yedek ve geri dönüş**
- Supabase otomatik yedekleri (plan bazlı, dashboard › Database › Backups) **buradan doğrulanamadı**; uygulama öncesi dashboard'da son yedek zamanı teyit edilmeli. Ek güvence: B2B tabloları canlıda boş (replies=0, requests=0, shops=1, products=1) → veri riski asgari; `prod_precheck.sql` ile migration öncesi sayılar kaydedilir.
- Geri dönüş: `supabase/tests/b2b_requests_s3/rollback_s3.sql` (harness'ta doğrulandı; veri kaybı yok; iletişim kolonları korunur). Uygulama RPC yokluğunda otomatik S2 davranışına döner → rollback için uygulama güncellemesi gerekmez.

**Migration öncesi / sonrası SQL** (salt-okunur, MCP `execute_sql`): `prod_precheck.sql` (tutarsız cevap/talep yok, S3 nesneleri yok, `accept_fn_has_for_update=false`), `prod_postcheck.sql` (9 fonksiyon SECURITY DEFINER + search_path, 5 trigger aktif, 4 index, `accept_fn_has_for_update=true`, grant matrisi: anon ✗ / authenticated ✓ RPC, guard ✗).

**Uygulama uyumluluğu**
- Eski uygulama (main) + yeni DB: reply insert `status:'sent'` gönderir (guard aynı değeri zorlar) ✓; kabul RPC imzası değişmedi ✓; kampanya insert `linked_product_id` göndermez (null) ✓; mağaza select yeni kolonları istemez ✓; eski açık talep RPC'si korunur ✓.
- Yeni uygulama (S3) + eski DB: tüm yeni RPC çağrıları `PGRST202` → `null` → S2 davranışı; delete/duplicate mevcut policy'lerle çalışır; iletişim alanları — **dikkat:** `updateStore` yeni kolonları upsert payload'ında gönderir → **eski DB'de 400 (kolon yok)**. Bu yüzden sıra: **önce migration, sonra S3'lü uygulama yayını** (veya S3 dağıtımı migration'a kadar bekletilir). Mağaza düzenleme dışındaki tüm S3 yüzeyleri eski DB ile uyumludur.

**Sıra (önerilen)**
1. Dashboard: yedek teyidi; `prod_precheck.sql`.
2. PR #117 → #118 → #119 merge (sırayla; CI yeşil).
3. Migration `apply_migration` (tek dosya, tek transaction) → `prod_postcheck.sql` → advisor security.
4. Uygulama derlemesi (main) → internal test/TestFlight → **push smoke** (§3) → geniş yayın.
5. İzleme (ilk 48 saat): `b2b_quote_requests`/`replies` sayıları, `notifications` type dağılımı, `notification_push_deliveries` error oranı, edge function logları.

## 5. Bulgular (sınıflandırılmış)

| Sev | Bulgu | Durum / Aksiyon |
|---|---|---|
| **BLOCKER** | — | Yok. |
| **HIGH** | Mevcut canlı `b2b_accept_quote_reply` yarış koşulu (iki eşzamanlı kabul) | Migration ile kapanır; canlı tablolar boş olduğu için henüz etkilenen kayıt yok. Migration uygulanana kadar açık kalır. |
| **HIGH** | Push teslimat kanıtı yok (0 delivery satırı; FCM env doğrulanamadı) | In-app bildirim etkilenmez. Dağıtım sonrası manuel push smoke + edge function env teyidi (dashboard). Migration'ı bloklamaz. |
| **MEDIUM** | `updateStore` yeni kolonlar gönderdiği için S3 uygulaması **eski DB'de** mağaza düzenlemeyi kıran 400 alır | Sıra kuralı: migration → uygulama yayını. İsteğe bağlı sertleştirme (S4): kolon yoksa payload'dan düşürme. |
| **MEDIUM** | Yedek teyidi MCP'den yapılamadı | Dashboard'da manuel teyit (adım 1). |
| **MEDIUM** | Kategori eşleşmesi tam metin; serbest/“Diğer” kategori girilirse tedarikçiye bildirim gitmez | Tasarım gereği sessiz; S4: kategori taksonomisi zorunlu veya "tümü" abonelik seçeneği. |
| **LOW** | Storage orphan görseller (sunucu tarafı süpürme yok) | İstemci temizliği eklendi; S4 cron süpürme. |
| **LOW** | Yoğunluk kapağı sabit 10/saat | Config'e taşınabilir. |
| **LOW** | Sayfalama modunda filtre chip seçenekleri yüklenen sayfadan türetilir | S4: `distinct` RPC. |
| **LOW** | Emülatör/cihaz smoke yapılmadı (ortam) | Widget-test PNG'leri + PG harness; dağıtım sonrası cihaz smoke. |

## 6. Test ve CI (son ağaç, 2026-10-19)

| Kontrol | Sonuç |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test --exclude-tags golden` | **3004/3004** |
| SQL harness (migration ×2 + testler + rollback + yeniden uygulama) | ALL B2B S3 TESTS PASSED |
| `flutter build apk --debug` | ✅ (önceki tur; bu turda yalnız test/widget değişti) |

## 7. GO / NO-GO önerisi

**GO (koşullu) — migration ve PR zinciri için.** Gerekçe: BLOCKER yok; güvenlik invariant'ları (eşzamanlılık, izolasyon, durum geçişleri, dedupe/kota) gerçek PostgreSQL üzerinde kanıtlı; migration additif, idempotent ve rollback'i test edilmiş; uygulama her iki DB durumuyla (mağaza düzenleme hariç) uyumlu; tam test paketi ve CI adımları yeşil.

Koşullar (sırayla): (1) dashboard'da yedek teyidi + `prod_precheck.sql`; (2) #117→#118→#119 merge; (3) migration + `prod_postcheck.sql`; (4) **S3'lü uygulama yayını migration'dan sonra**; (5) dağıtım sonrası push smoke — başarısızsa FCM env düzeltilene kadar push kanalı "bilinen eksik" olarak işaretlenir (in-app bildirim çalışır), geniş yayın bunu beklemeli.

Onayınız olmadan migration uygulanmayacak, PR merge edilmeyecek, dağıtım yapılmayacaktır.
