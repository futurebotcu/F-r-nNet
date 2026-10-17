# S1 — B2B Güvenlik Etki Analizi: `is_verified` ve Teklif Kabul Akışı

**Tarih:** 2026-10-17 · **Durum:** ANALİZ + TASLAK MIGRATION (uygulanmadı; onay bekliyor) · **Kaynak:** `SYSTEM_AUDIT_SUPPLIER_PANEL_2026-10-16.md` §6.1 S1–S3

Tüm policy/trigger tespitleri canlı DB'de `pg_policies` / `pg_trigger` sorgusuyla doğrulandı (2026-10-16).

## 1. `b2b_supplier_shops.is_verified` — sahip tarafından yazılabilir

**Mekanizma:** `b2b_shops_update` policy'si yalnız `owner_id = auth.uid()` kontrol eder; tabloda tek trigger `trg_b2b_shops_updated` (updated_at). Kolon bazlı koruma yok. Sahip, PostgREST ile `PATCH /rest/v1/b2b_supplier_shops?id=eq.<id>` gövdesinde `{"is_verified": true}` gönderebilir.

**Mevcut etki (bugün):** **DÜŞÜK.** `is_verified` hiçbir UI yüzeyinde okunmuyor/gösterilmiyor (repo select ediyor, model map etmiyor; mağaza kartı/detayında rozet yok). Alıcı tarafında hiçbir karar bu kolona bağlı değil. Dolayısıyla istismar bugün görünür bir sonuç üretmez.

**Gelecek etki (rozet UI'a girerse):** **YÜKSEK.** "Doğrulanmış firma" rozeti güven sinyalidir; kendi kendine doğrulanan tedarikçi alıcıyı yanıltır. Bu yüzden S5 (mağaza profili) sprintinde rozet, aşağıdaki guard **canlıya alınmadan** UI'a konmayacak.

**Karar:** Kritik istismar bugün doğrulanmadı → S1'de DB değişikliği yapılmadı. Guard migration'ı taslak olarak hazır (§4), onayınızla ayrı PR'da uygulanır.

## 2. `b2b_quote_replies` INSERT'te `status` / `accepted` serbest

**Mekanizma:** `b2b_replies_insert` with_check: kendi mağazası ∧ `b2b_request_accepts_reply` ∧ `can_reply_b2b_quote`. `status`/`accepted` sınırlanmıyor. Guard trigger `trg_b2b_replies_guard_status` yalnız **BEFORE UPDATE**. Tedarikçi insert gövdesinde `{"status":"accepted","accepted":true}` gönderebilir.

**Etki:** **ORTA.** Alıcının teklif detayında yanıt kartı "kabul edildi" görünümü alabilir (UI `accepted`/`status` okuyor: `buyer_quote_detail_screen.dart`). Ancak gerçek kabul `b2b_quote_requests.accepted_reply_id` ile belirlenir; `b2b_accept_quote_reply` RPC'si çağrılmadığı için talep `answered`'da kalır, diğer tedarikçiler yanıt vermeye devam edebilir, lead/bildirim akışı tetiklenmez. Yani **görsel sahtecilik** mümkün, **akış ele geçirme** değil. Veri bütünlüğü açısından yine de kapatılmalı.

## 3. `b2b_quote_requests.accepted_reply_id` / `status` alıcı tarafından doğrudan yazılabilir

**Mekanizma:** `b2b_qr_update_own` (`buyer_id = auth.uid()`), kolon guard yok. FK herhangi bir reply id'yi kabul eder (başka bir talebe ait reply dahil).

**Etki:** **ORTA-DÜŞÜK.** Alıcı kendi talebini manipüle eder (kendi verisi). Risk: (a) başka talebe ait reply id'yi kabul edilmiş göstermek → `trg_notify_b2b_accept` o reply'ın tedarikçisine "Teklifin seçildi" bildirimi gönderir (yanıltıcı bildirim); (b) RPC'nin lead oluşturma/`accepted` işaretleme adımları atlanır → tutarsız durum. Üçüncü şahıs verisi sızmaz.

## 4. Taslak migration (UYGULANMADI — onay gerekli)

Additif, geri alınabilir (trigger drop ile), mevcut client akışlarını kırmaz (client bu kolonları göndermiyor; RPC'ler SECURITY DEFINER + `set_config('app.b2b_guard','on')` ile muaf tutulur). RLS smoke seti ile doğrulanmalı.

```sql
-- 2026xxxxxx_b2b_column_guards_v1.sql  (TASLAK)
-- 1) Shops: is_verified yalnız service_role / guard-bypass
create or replace function public.b2b_shops_guard_columns()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if current_setting('app.b2b_guard', true) = 'on' then return new; end if;
  if auth.role() = 'service_role' then return new; end if;
  if new.is_verified is distinct from old.is_verified then
    raise exception 'is_verified yalnız yönetim tarafından değiştirilebilir'
      using errcode = '42501';
  end if;
  return new;
end $$;
revoke execute on function public.b2b_shops_guard_columns() from public, anon, authenticated;
drop trigger if exists trg_b2b_shops_guard_columns on public.b2b_supplier_shops;
create trigger trg_b2b_shops_guard_columns
  before update on public.b2b_supplier_shops
  for each row execute function public.b2b_shops_guard_columns();

-- 2) Replies: INSERT'te status='sent', accepted=false zorunlu
create or replace function public.b2b_replies_guard_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.role() = 'service_role' then return new; end if;
  new.status := 'sent';
  new.accepted := false;
  return new;
end $$;
revoke execute on function public.b2b_replies_guard_insert() from public, anon, authenticated;
drop trigger if exists trg_b2b_replies_guard_insert on public.b2b_quote_replies;
create trigger trg_b2b_replies_guard_insert
  before insert on public.b2b_quote_replies
  for each row execute function public.b2b_replies_guard_insert();

-- 3) Requests: accepted_reply_id yalnız RPC (b2b_accept_quote_reply) üzerinden;
--    status alıcı tarafından yalnız open/answered → closed/cancelled yönünde.
create or replace function public.b2b_qr_guard_columns()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if current_setting('app.b2b_guard', true) = 'on' then return new; end if;
  if auth.role() = 'service_role' then return new; end if;
  if new.accepted_reply_id is distinct from old.accepted_reply_id then
    raise exception 'Teklif kabulü yalnız b2b_accept_quote_reply ile yapılır'
      using errcode = '42501';
  end if;
  if new.status is distinct from old.status
     and new.status not in ('closed','cancelled') then
    raise exception 'Geçersiz talep durumu geçişi' using errcode = '42501';
  end if;
  return new;
end $$;
revoke execute on function public.b2b_qr_guard_columns() from public, anon, authenticated;
drop trigger if exists trg_b2b_qr_guard_columns on public.b2b_quote_requests;
create trigger trg_b2b_qr_guard_columns
  before update on public.b2b_quote_requests
  for each row execute function public.b2b_qr_guard_columns();

-- 4) b2b_accept_quote_reply içinde (mevcut fonksiyon güncellenir):
--    perform set_config('app.b2b_guard','on', true);  -- işlem başında
--    ... mevcut update'ler ...
--    (transaction-local GUC; fonksiyon bitince sıfırlanır)
```

**Doğrulama planı (uygulanırsa):** RLS smoke: (a) sahip PATCH is_verified → 42501; (b) tedarikçi insert status=accepted → satır `sent/false` olarak yazılır; (c) alıcı PATCH accepted_reply_id → 42501; (d) `b2b_accept_quote_reply` RPC normal çalışır, bildirim/lead akışı korunur; (e) alıcı `status=closed` → OK; (f) `status=open` geri alma → 42501 (mevcut `_setRequestStatus` yalnız closed/cancelled yazıyor, uyumlu).

**Riskler:** `b2b_accept_quote_reply` fonksiyonu güncellenmeden guard açılırsa kabul akışı kırılır → migration iki adımı aynı dosyada, tek transaction'da yapmalı. Akademi/backoffice script'leri service_role kullanıyor, etkilenmez.

## 5. Öneri

| Adım | Ne zaman | Risk |
|---|---|---|
| Rozet UI'ı guard'sız yayınlamamak | Şimdi (kural) | — |
| Guard migration (§4) + RLS smoke | S4 sprinti, ayrı PR, onayınızla | Orta (RPC güncellemesi aynı dosyada) |
| Bucket boyut/MIME limitleri + HIBP | Dashboard'dan, kod yok, onayınızla | Düşük |
