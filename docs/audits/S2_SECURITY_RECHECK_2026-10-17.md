# S2 — B2B Güvenlik Yeniden Kontrolü ve Migration Etki/Geri Alma Planı

**Tarih:** 2026-10-17 · **Durum:** ANALİZ (migration UYGULANMADI; production'a yazılmadı) · Önceki: `S1_SECURITY_IMPACT_B2B_GUARDS.md`

## 1. Canlı yeniden kontrol `[CANLI, 2026-10-17]`

`pg_policies` / `pg_trigger` sorgusu S1 ile birebir aynı durumu gösterdi:

| Nesne | Policy'ler | Trigger'lar | S1 bulgusu hâlâ geçerli mi |
|---|---|---|---|
| `b2b_supplier_shops` | insert/select/update (owner) | yalnız `trg_b2b_shops_updated` | **Evet** — `is_verified` kolon koruması yok |
| `b2b_quote_replies` | insert (owner+aktif talep+kota) / select / update (owner) | `trg_b2b_replies_guard_status` (BEFORE **UPDATE**), updated_at, reply_answered, notify | **Evet** — INSERT'te `status/accepted` serbest |
| `b2b_quote_requests` | insert/select/update (buyer) | updated_at, `trg_notify_b2b_accept` | **Evet** — `accepted_reply_id`/`status` alıcı-yazılabilir |

Canlı satır sayıları: replies=0, requests=0, doğrulanmış mağaza=0 → bugün istismar edilmiş bir kayıt yok.

## 2. S2 kodunun bu risklerle ilişkisi

S2 **yalnız okuma** ekler (`listMyQuoteReplies`: `b2b_quote_replies` select, mevcut `b2b_replies_select` policy'si ile sınırlı). Yeni yazma yolu yok; istemci hâlâ `status:'sent'` gönderir ve `accepted` göndermez. Dolayısıyla S2 riski artırmaz; ancak **"Kazanılan" segmenti `reply.accepted/status` okuduğu için** tedarikçinin kendi insert'inde `accepted=true` göndermesi (F3) kendi ekranında sahte "Kazanılan" üretir. Bu yalnız kendisini yanıltır (alıcı akışı etkilenmez), ama veri bütünlüğü için guard §3 ile kapatılmalı. Alıcının `accepted_reply_id`'yi doğrudan yazması (F4) tedarikçi tarafında `trg_notify_b2b_accept` bildirimi tetikler; S2 "Kazanılan" bu durumda sahte görünmez çünkü reply `accepted` kolonu RPC dışında güncellenmez (reply güncelleme guard'ı UPDATE'te var).

## 3. Migration taslağı — mevcut iş akışlarıyla karşılaştırma

Taslak (S1 §4) üç BEFORE trigger + `b2b_accept_quote_reply` içinde GUC bypass ekler. Mevcut akışlarla çakışma kontrolü:

| Akış | Yazdığı kolon | Guard sonrası | Değişiklik gerekli mi |
|---|---|---|---|
| Mağaza oluştur/düzenle (`updateStore`, upsert owner_id) | shop_name, description, regions, categories, logo/cover | `is_verified` gönderilmiyor → **etkilenmez** | Hayır |
| Teklif ver (`addQuoteReply`) | message, price/delivery note, `status:'sent'` | trigger `status:='sent'`, `accepted:=false` zorlar → **aynı sonuç** | Hayır (istemci `status` göndermeyi bırakabilir, opsiyonel) |
| Alıcı kabul (`b2b_accept_quote_reply` RPC) | requests.accepted_reply_id + replies.accepted/status | RPC başında `set_config('app.b2b_guard','on',true)` → bypass | **Evet**: RPC gövdesine 1 satır (aynı migration'da) |
| Alıcı kapat/iptal (`_setRequestStatus` closed/cancelled) | requests.status | guard yalnız closed/cancelled'a izin → **etkilenmez** | Hayır |
| `trg_b2b_reply_answered` (AFTER INSERT) | requests.status open→answered | trigger fonksiyonu SECURITY DEFINER; guard BEFORE UPDATE'te status geçişi `answered` → **reddedilir!** | **Evet**: guard'da `answered` geçişine (open→answered) izin ver VEYA bu trigger'da GUC set et |
| Lead/ilgi (`create_b2b_quote_lead` RPC) | b2b_quote_leads | dokunulmaz | Hayır |
| Akademi/backoffice (service_role) | — | `auth.role()='service_role'` muaf | Hayır |

**Düzeltilmiş guard (requests):** `new.status` geçişi `open→answered` (yalnız `b2b_mark_request_answered` tetikler) ve `*→closed/cancelled` serbest; diğerleri 42501. Bu düzeltme taslağa eklenecek (S1 taslağındaki eksik).

## 4. Etki ve geri alma planı

**Uygulama sırası (tek migration, tek transaction):** (1) 3 guard fonksiyonu + trigger; (2) `b2b_accept_quote_reply` CREATE OR REPLACE (GUC set); (3) EXECUTE revoke'ları.

**Beklenen etki:** istemci akışlarında sıfır görünür değişiklik; yalnız doğrudan PostgREST ile kolon manipülasyonu 42501 alır. Performans: satır başına 3 basit trigger, ihmal edilebilir.

**Doğrulama (RLS smoke, uygulanırsa):** a) sahip PATCH is_verified → 42501 · b) tedarikçi insert status=accepted → satır sent/false · c) alıcı PATCH accepted_reply_id → 42501 · d) RPC kabul → OK + bildirim + replies accepted/declined · e) teklif insert sonrası request status `answered` olur (trigger engellenmedi) · f) alıcı closed/cancelled → OK · g) service_role → serbest.

**Geri alma:** `drop trigger … ; drop function …` (3'er adet) + önceki `b2b_accept_quote_reply` tanımını geri yükle (migration dosyası `20260622160000_b2b_reply_hardening.sql:51-87`). Veri değişikliği yok → geri alma kayıpsız.

**Riskler:** (i) `answered` geçişi unutulursa teklif verme kırılır (yukarıda düzeltildi; smoke e) bunu yakalar); (ii) Supabase default privileges yeni fonksiyonlara authenticated EXECUTE bırakır → revoke şart (önceki derslerle uyumlu).

## 5. Karar

S2'de DB değişikliği yapılmadı. Düzeltilmiş taslak S3/S4'te **onayınızla** ayrı PR + RLS smoke ile uygulanır. "Doğrulanmış" rozeti o zamana kadar UI'a konmaz.
