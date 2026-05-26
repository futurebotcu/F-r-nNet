# FırınNet Supabase V1 Core Schema — Rapor

Tarih: 2026-05-12
Faz: V1 Core (çekirdek işletme/panel sistemi)
Flutter koduna dokunulmadı.

---

## 1. MCP Bağlantı Özeti

| Alan | Değer |
|---|---|
| MCP server | `supabase` (bağlı) |
| Project URL | `https://sjeqwiqgwzagengdukye.supabase.co` |
| Project ref | `sjeqwiqgwzagengdukye` (memory ile eşleşti — doğru proje) |
| Token | Repo/.env/markdown'a yazılmadı. Yalnızca MCP env'inde. |

Bağlantı öncesi durumu: 0 tablo, 0 migration, `pgcrypto` zaten yüklü (extensions schema).

## 2. Uygulanan Migration Dosyaları

| Sıra | Version | Ad |
|---|---|---|
| 1 | 20260512075056 | firinnet_v1_core_schema |
| 2 | 20260512075421 | firinnet_v1_grants_authenticated |
| 3 | 20260512075525 | firinnet_v1_revoke_trigger_fn_execute |

> Migration MCP `apply_migration` ile uygulandığı için Supabase tarafında otomatik versiyonlandı. Notu: Eğer ileride yerel `supabase/migrations/` dizini kullanılırsa bu üçünü oradan da pull etmek gerekir (`supabase db pull` veya manuel dump). Şu an local dizin oluşturulmadı; MCP-only akış.

## 3. Tablolar (9)

| # | Tablo | RLS | Açıklama |
|---|---|---|---|
| 1 | `public.profiles` | açık | `id = auth.users.id`, account_type ∈ commercial/individual/wholesaler |
| 2 | `public.bakeries` | açık | Fırın işletme kaydı, owner_id → profiles |
| 3 | `public.bakery_products` | açık | Ürün listesi, bakery_id'ye bağlı |
| 4 | `public.recipe_calculations` | açık | Reçete hesaplama; sayısallar trigger ile doldurulur |
| 5 | `public.production_entries` | açık | Günlük üretim |
| 6 | `public.dealers` | açık | Bayi/market/bakkal |
| 7 | `public.dealer_deliveries` | açık | Teslimat üst kaydı; total/returned itemlardan, remaining BEFORE-triggerla |
| 8 | `public.dealer_delivery_items` | açık | Teslimat kalemleri; cross-owner trigger kontrolü |
| 9 | `public.waste_entries` | açık | Fire/iade/kalan; estimated_loss = quantity * unit_cost |

Tüm tablolarda `created_at/updated_at` (recipe ve item hariç — bunlarda `created_at` var, immutable kayıt).

## 4. Indeksler

PK indeksleri haricinde 25 ikincil indeks:

- `bakeries`: owner_id, city, is_active
- `bakery_products`: owner_id, bakery_id, is_active
- `recipe_calculations`: owner_id, created_at DESC
- `production_entries`: owner_id, bakery_id, production_date DESC, product_id
- `dealers`: owner_id, bakery_id, is_active, name
- `dealer_deliveries`: owner_id, bakery_id, dealer_id, delivery_date DESC
- `dealer_delivery_items`: owner_id, delivery_id, product_id
- `waste_entries`: owner_id, bakery_id, waste_date DESC, waste_type

## 5. Fonksiyon ve Trigger'lar

| Fonksiyon | Tip | Kullanım |
|---|---|---|
| `public.set_updated_at()` | SECURITY INVOKER | profiles/bakeries/bakery_products/production_entries/dealers'da BEFORE UPDATE |
| `public.calculate_recipe_calculation()` | SECURITY INVOKER | recipe_calculations'da BEFORE INSERT/UPDATE |
| `public.calculate_dealer_delivery_item()` | SECURITY INVOKER | dealer_delivery_items'da BEFORE INSERT/UPDATE; line_total + owner_id cross-check |
| `public.compute_dealer_delivery_remaining()` | SECURITY INVOKER | dealer_deliveries'de BEFORE INSERT/UPDATE; remaining = total - returned - paid |
| `public.recalculate_dealer_delivery_totals(uuid)` | SECURITY DEFINER, REVOKE ALL | parent total/returned hesaplaması; yalnız trigger içinden |
| `public.trg_dealer_delivery_items_recalc()` | SECURITY DEFINER, REVOKE ALL | dealer_delivery_items'da AFTER I/U/D |
| `public.calculate_waste_entry()` | SECURITY INVOKER | waste_entries'de BEFORE INSERT/UPDATE |

Trigger sayısı: 14 (BEFORE/AFTER kombinasyonları dahil).

## 6. RLS Policy Özeti

| Tablo | Policy adedi | Kapsam |
|---|---|---|
| profiles | 4 | select/insert/update/delete — `id = auth.uid()` |
| bakeries | 4 | select/insert/update/delete — `owner_id = auth.uid()` |
| bakery_products | 4 | aynı |
| recipe_calculations | 4 | aynı |
| production_entries | 4 | aynı |
| dealers | 4 | aynı |
| dealer_deliveries | 4 | aynı |
| dealer_delivery_items | 4 | `owner_id = auth.uid()` + parent delivery aynı owner |
| waste_entries | 4 | aynı |

- Tüm policy'ler `to authenticated`. **Anon'a hiçbir policy verilmedi.**
- `service_role` policy'lerde kullanılmadı.
- Profil silme açık tutuldu (kullanıcı kendi hesabını silebilir; auth.users cascade ile veri akışı temizleniyor). Üretim öncesi UX kararı: "soft delete" istenirse policy update ile `delete` yerine `is_active` ekleyebiliriz.

## 7. Hesaplama Doğrulama Sonuçları

### 7.1 Recipe trigger
Girdi: `flour_kg=50, water_percent=60, yeast_percent=1, salt_percent=2, unit_weight_gr=250, waste_percent=3`

| Alan | Beklenen | Bulunan |
|---|---|---|
| water_kg | 30 | **30.000** ✓ |
| yeast_kg | 0.5 | **0.500** ✓ |
| salt_kg | 1 | **1.000** ✓ |
| total_dough_kg | 81.5 | **81.500** ✓ |
| net_dough_kg | 79.055 | **79.055** ✓ |
| estimated_count | 316 | **316** ✓ |

### 7.2 Dealer delivery totals
Girdi: items = `(Ekmek 10x5)`, `(Simit 20x2.50, 2 iade)`; parent paid_amount=50

| Alan | Beklenen | Bulunan |
|---|---|---|
| Ekmek.line_total | 50.00 | **50.00** ✓ |
| Simit.line_total | 50.00 | **50.00** ✓ |
| total_amount | 100.00 | **100.00** ✓ |
| returned_amount (2 simit × 2.50) | 5.00 | **5.00** ✓ |
| paid_amount | 50.00 | **50.00** ✓ |
| remaining_amount (100−5−50) | 45.00 | **45.00** ✓ |

### 7.3 Güvenlik testleri
- Cross-owner item insert: `calculate_dealer_delivery_item()` triggerı `RAISE EXCEPTION` ile reddetti ✓
- `returned_quantity > quantity`: `chk_returned_le_quantity` check constraint reddetti ✓
- `set local role anon; select … profiles`: SQL-level `permission denied` (defense-in-depth) ✓
- `set local role authenticated; jwt.sub = test_user_id`: kendi profili/bakery/items görünür ✓
- `set local role authenticated; jwt.sub = farkli_uid`: hiçbir satır görünmedi (0/0/0) ✓

### 7.4 Test verisi durumu
Tüm test kayıtları (synthetic auth.user + cascade) **silindi**. Şu an `select count(*) from <her tablo>` → **0**.

## 8. Güvenlik Notları

- ✓ RLS her tabloda açık (`rowsecurity = true` 9/9).
- ✓ Owner-based izolasyon, `auth.uid()` üzerinden.
- ✓ Anon'a yalnız `usage on schema public` verildi (DML yok). Şu an `permission denied` döner → defense-in-depth.
- ✓ Authenticated için tablo-seviyesi SELECT/INSERT/UPDATE/DELETE grant — RLS politikalarıyla filtrelenir.
- ✓ Trigger fonksiyonları (`SECURITY DEFINER`) için `EXECUTE` revoke edildi; RPC üzerinden çağrılamaz.
- ✓ `service_role` hiçbir politikada kullanılmadı; bu rol normal Flutter client'ından geçmeyecek.
- ✓ Cross-owner item enjeksiyonu hem trigger hem RLS WITH CHECK ile çift katmanlı bloklu.
- ✓ remaining_amount **negatif** kalabilir (fazla ödeme/iade kombinasyonunda). Bu bilinçli tercih — gerçek bakiyeyi gizlemiyoruz.
- ⚠ **Bizim olmayan advisor uyarıları (proje sahibinin Supabase dashboard'undan ele alması gerekenler):**
  - `auth_leaked_password_protection` — Auth → Password Protection'ı HIBP ile aç.
  - `public.rls_auto_enable()` SECURITY DEFINER (Supabase'in projesini oluştururken eklediği yardımcı fonksiyon, biz oluşturmadık). İncelenebilir.
- ⛔ Token / service_role / publishable key dosyaya yazılmadı, repo'ya commit edilmedi.

## 9. Henüz Yapılmayanlar (kapsam dışı, bilinçli)

- Sosyal akış, ilan sistemi, mesajlaşma
- Storage bucket (avatar/foto yükleme)
- Ödeme / abonelik / üyelik
- Push notification, AI, harita, edge function
- Realtime publication ayarları
- Flutter Supabase SDK entegrasyonu
- Auth tetikleyici (auth.users INSERT → profiles INSERT) — `handle_new_user()` yok
- Soft-delete / arşiv mekanizması

## 10. Önerilen Sonraki Migration Sırası

1. **`firinnet_v1_auth_user_handler`** — `auth.users` insertinden `public.profiles` satırını otomatik oluşturan trigger (account_type Flutter formundan raw_user_meta_data ile gelir). Bu olmadan Flutter signup → profile oluşmaz.
2. **`firinnet_v2_storage_avatars`** — `avatars` storage bucket'ı + owner-scoped policy.
3. **`firinnet_v2_social_feed`** — gönderiler, beğeniler, yorumlar (sosyal akış başlangıcı).
4. **`firinnet_v2_messaging`** — DM/grup mesajlaşma.
5. **`firinnet_v3_jobs_classifieds`** — ilan sistemi.
6. **`firinnet_v3_notifications`** — bildirim event tablosu (push notification öncesi).

## 11. Flutter Sonraki Faz Planı (referans, bu PR dışı)

1. `supabase_flutter` paketini `pubspec.yaml`'a ekle.
2. Anahtar yönetimi: yalnız **publishable (anon) key**'i runtime'a koy — service_role kesinlikle Flutter'a girmez.
3. `lib/services/supabase_client.dart` üzerinden tek instance.
4. Mevcut mock repository'leri Supabase adapter'la değiştir; behavior parity test.
5. Auth signup → custom `account_type` meta + `handle_new_user` trigger ile profil oluşumu.
6. Offline-first için Drift/Hive ile lokal cache + remote sync (mevcut local DB politikası korunur).
