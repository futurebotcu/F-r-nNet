-- ============================================================
-- B2B S3 — Talep geçmişi RPC'si, durum/kolon guard'ları, sunucu tarafı
-- sayfalama + filtre, yeni talep bildirimi, mağaza iletişim alanları.
--
-- ADDITİF: drop table / delete / veri değişikliği YOK. Yalnız
-- create-or-replace fonksiyon, yeni trigger, yeni kolon (nullable), yeni
-- index ve grant/revoke. Geri alma: dosya sonundaki "ROLLBACK" bloğu.
--
-- PRODUCTION'A UYGULANMADI — ürün sahibi onayı + RLS smoke (supabase/tests/
-- b2b_requests_s3) sonrası ayrı adım. Repo mirror.
--
-- Referanslar: docs/audits/S1_SECURITY_IMPACT_B2B_GUARDS.md,
--              docs/audits/S2_SECURITY_RECHECK_2026-10-17.md
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1) Mağaza iletişim alanları (nullable, additif)
--    Görünürlük: b2b_shops_select policy'si değişmez (authenticated; aktif
--    mağaza veya sahibi). anon'a tablo grant'i yok → anonim okunamaz.
-- ─────────────────────────────────────────────────────────────
alter table public.b2b_supplier_shops
  add column if not exists phone text,
  add column if not exists whatsapp text,
  add column if not exists website text,
  add column if not exists address text;

alter table public.b2b_supplier_shops
  drop constraint if exists b2b_shops_contact_len;
alter table public.b2b_supplier_shops
  add constraint b2b_shops_contact_len check (
    (phone is null or char_length(phone) <= 32)
    and (whatsapp is null or char_length(whatsapp) <= 32)
    and (website is null or char_length(website) <= 200)
    and (address is null or char_length(address) <= 300)
  );

-- ─────────────────────────────────────────────────────────────
-- 2) Kolon guard'ları
--    GUC `b2b.reply_write=on` (transaction-local) zaten b2b_accept_quote_reply
--    tarafından set ediliyor ve b2b_replies_guard_status bunu tanıyor. Aynı
--    bayrak talep guard'ı için de meşru-yazıcı işareti olarak kullanılır.
-- ─────────────────────────────────────────────────────────────

-- 2a) Mağaza: is_verified yalnız service_role (backoffice).
create or replace function public.b2b_shops_guard_columns()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.is_verified is distinct from old.is_verified
     and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'is_verified yalnız yönetim tarafından değiştirilebilir'
      using errcode = '42501';
  end if;
  if new.owner_id is distinct from old.owner_id
     and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'owner_id değiştirilemez' using errcode = '42501';
  end if;
  return new;
end;
$$;
revoke execute on function public.b2b_shops_guard_columns()
  from public, anon, authenticated;
drop trigger if exists trg_b2b_shops_guard_columns on public.b2b_supplier_shops;
create trigger trg_b2b_shops_guard_columns
  before update on public.b2b_supplier_shops
  for each row execute function public.b2b_shops_guard_columns();

-- 2b) Teklif cevabı INSERT: status='sent', accepted=false zorunlu (tedarikçi
--     kendi cevabını "kabul edilmiş" olarak yazamaz). UPDATE guard'ı mevcut.
create or replace function public.b2b_replies_guard_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(current_setting('b2b.reply_write', true), '') = 'on'
     or coalesce(auth.role(), '') = 'service_role' then
    return new;
  end if;
  new.status := 'sent';
  new.accepted := false;
  return new;
end;
$$;
revoke execute on function public.b2b_replies_guard_insert()
  from public, anon, authenticated;
drop trigger if exists trg_b2b_replies_guard_insert on public.b2b_quote_replies;
create trigger trg_b2b_replies_guard_insert
  before insert on public.b2b_quote_replies
  for each row execute function public.b2b_replies_guard_insert();

-- 2c) Talep: accepted_reply_id yalnız RPC; buyer_id sabit; status geçişleri:
--       open/answered → closed/cancelled : alıcı (doğrudan UPDATE)
--       open → answered                 : yalnız b2b_mark_request_answered
--                                         (GUC ile işaretli)
--       diğerleri                       : reddedilir
create or replace function public.b2b_qr_guard_columns()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bypass boolean :=
    coalesce(current_setting('b2b.reply_write', true), '') = 'on'
    or coalesce(auth.role(), '') = 'service_role';
begin
  if v_bypass then return new; end if;
  if new.buyer_id is distinct from old.buyer_id then
    raise exception 'buyer_id değiştirilemez' using errcode = '42501';
  end if;
  if new.accepted_reply_id is distinct from old.accepted_reply_id then
    raise exception 'Teklif kabulü yalnız b2b_accept_quote_reply ile yapılır'
      using errcode = '42501';
  end if;
  if new.status is distinct from old.status then
    if not (old.status in ('open', 'answered')
            and new.status in ('closed', 'cancelled')) then
      raise exception 'Geçersiz talep durumu geçişi: % → %', old.status, new.status
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;
revoke execute on function public.b2b_qr_guard_columns()
  from public, anon, authenticated;
drop trigger if exists trg_b2b_qr_guard_columns on public.b2b_quote_requests;
create trigger trg_b2b_qr_guard_columns
  before update on public.b2b_quote_requests
  for each row execute function public.b2b_qr_guard_columns();

-- 2d) open → answered geçişi meşru yazıcı: reply AFTER INSERT trigger'ı.
--     GUC transaction-local set edilir (set_config(..., true)); guard geçer.
create or replace function public.b2b_mark_request_answered()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform set_config('b2b.reply_write', 'on', true);
  update public.b2b_quote_requests
     set status = 'answered', updated_at = now()
   where id = new.quote_request_id
     and status = 'open';
  return new;
end;
$$;
revoke execute on function public.b2b_mark_request_answered()
  from public, anon, authenticated;

-- 2e) YARIŞ KOŞULU DÜZELTMESİ (harness conc_accept ile tespit edildi):
--     Mevcut b2b_accept_quote_reply talep satırını kilitlemeden okuyor;
--     READ COMMITTED altında iki eşzamanlı kabul ikisi de "karar yok" görüp
--     ikincisi birincinin kararını EZİYORDU. Çözüm: talep satırı FOR UPDATE
--     ile kilitlenir ve UPDATE 'accepted_reply_id is null' şartıyla yapılır.
create or replace function public.b2b_accept_quote_reply(p_reply_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_req uuid;
  v_buyer uuid;
  v_status text;
  v_accepted uuid;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  select qr.id, qr.buyer_id, qr.status, qr.accepted_reply_id
    into v_req, v_buyer, v_status, v_accepted
  from public.b2b_quote_replies rep
  join public.b2b_quote_requests qr on qr.id = rep.quote_request_id
  where rep.id = p_reply_id
  for update of qr;
  if v_req is null then raise exception 'reply not found'; end if;
  if v_buyer <> v_uid then raise exception 'not your request'; end if;
  if v_status not in ('open', 'answered') then raise exception 'request not active'; end if;
  if v_accepted is not null then raise exception 'already decided'; end if;

  perform set_config('b2b.reply_write', 'on', true);

  update public.b2b_quote_requests
     set accepted_reply_id = p_reply_id, updated_at = now()
   where id = v_req and accepted_reply_id is null;
  if not found then raise exception 'already decided'; end if;

  update public.b2b_quote_replies
     set accepted = (id = p_reply_id),
         status   = case when id = p_reply_id then 'accepted' else 'declined' end
   where quote_request_id = v_req;
end;
$$;
revoke execute on function public.b2b_accept_quote_reply(uuid) from public, anon;
grant execute on function public.b2b_accept_quote_reply(uuid) to authenticated, service_role;

-- ─────────────────────────────────────────────────────────────
-- 3) Index'ler (sayfalama / filtre / geçmiş)
-- ─────────────────────────────────────────────────────────────
create index if not exists idx_b2b_qr_open_cat_city
  on public.b2b_quote_requests (category, city, created_at desc)
  where accepted_reply_id is null and status in ('open', 'answered');
create index if not exists idx_b2b_replies_shop_created
  on public.b2b_quote_replies (supplier_shop_id, created_at desc);
create index if not exists idx_b2b_shops_owner_active
  on public.b2b_supplier_shops (owner_id) where is_active;

-- ─────────────────────────────────────────────────────────────
-- 4) RPC — tedarikçinin yanıtladığı talepler (geçmiş dahil, ANONİM)
--    Minimum yetki: yalnız çağıranın mağazasının cevap verdiği talepler;
--    buyer_id, diğer tedarikçilerin cevapları/id'leri, telefon vb. DÖNMEZ.
--    decision: won / lost / closed / pending (alıcı kararı veya kapanış).
-- ─────────────────────────────────────────────────────────────
create or replace function public.b2b_my_replied_requests()
returns table (
  request_id uuid,
  category text,
  quantity text,
  city text,
  district text,
  buyer_type text,
  delivery_time text,
  note text,
  request_status text,
  request_created_at timestamptz,
  target_type text,
  target_id uuid,
  my_reply_id uuid,
  my_reply_status text,
  my_reply_accepted boolean,
  my_reply_created_at timestamptz,
  decision text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    qr.id, qr.category, qr.quantity, qr.city, qr.district, qr.buyer_type,
    qr.delivery_time, qr.note, qr.status, qr.created_at,
    qr.target_type, qr.target_id,
    rep.id, rep.status, rep.accepted, rep.created_at,
    case
      when qr.accepted_reply_id = rep.id then 'won'
      when qr.accepted_reply_id is not null then 'lost'
      when qr.status in ('closed', 'cancelled') then 'closed'
      else 'pending'
    end
  from public.b2b_quote_replies rep
  join public.b2b_quote_requests qr on qr.id = rep.quote_request_id
  where auth.uid() is not null
    and rep.supplier_shop_id in (
      select s.id from public.b2b_supplier_shops s where s.owner_id = auth.uid()
    )
  order by rep.created_at desc;
$$;
revoke execute on function public.b2b_my_replied_requests() from public, anon;
grant execute on function public.b2b_my_replied_requests() to authenticated, service_role;

-- ─────────────────────────────────────────────────────────────
-- 5) RPC — açık talepler: sunucu tarafı filtre + sayfalama
--    Aynı anonimlik sözleşmesi (buyer_id yok). p_exclude_replied=true →
--    çağıranın mağazasının zaten cevapladığı talepler listelenmez ("Yeni").
--    total_count pencere fonksiyonu ile (sayfadan bağımsız toplam).
-- ─────────────────────────────────────────────────────────────
create or replace function public.b2b_open_quote_requests_page(
  p_categories text[] default null,
  p_cities text[] default null,
  p_exclude_replied boolean default true,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  id uuid,
  target_type text,
  target_id uuid,
  category text,
  quantity text,
  city text,
  district text,
  buyer_type text,
  delivery_time text,
  note text,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  total_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select s.id from public.b2b_supplier_shops s where s.owner_id = auth.uid()
  )
  select qr.id, qr.target_type, qr.target_id, qr.category, qr.quantity, qr.city,
         qr.district, qr.buyer_type, qr.delivery_time, qr.note, qr.status,
         qr.created_at, qr.updated_at,
         count(*) over () as total_count
  from public.b2b_quote_requests qr
  where auth.uid() is not null
    and qr.status in ('open', 'answered')
    and qr.accepted_reply_id is null
    and (p_categories is null or qr.category = any (p_categories))
    and (p_cities is null or qr.city = any (p_cities))
    and (
      not coalesce(p_exclude_replied, true)
      or not exists (
        select 1 from public.b2b_quote_replies r
        where r.quote_request_id = qr.id
          and r.supplier_shop_id in (select id from mine)
      )
    )
  order by qr.created_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 100)
  offset greatest(coalesce(p_offset, 0), 0);
$$;
revoke execute on function public.b2b_open_quote_requests_page(text[], text[], boolean, integer, integer)
  from public, anon;
grant execute on function public.b2b_open_quote_requests_page(text[], text[], boolean, integer, integer)
  to authenticated, service_role;

-- 5b) Sayaçlar — Panel KPI ile Talepler sekmesi aynı sunucu sayısını kullanır.
create or replace function public.b2b_supplier_request_counts()
returns table (fresh_count bigint, network_open_count bigint)
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select s.id from public.b2b_supplier_shops s where s.owner_id = auth.uid()
  ),
  open_reqs as (
    select qr.id from public.b2b_quote_requests qr
    where qr.status in ('open', 'answered') and qr.accepted_reply_id is null
  )
  select
    (select count(*) from open_reqs o
      where auth.uid() is not null
        and not exists (
          select 1 from public.b2b_quote_replies r
          where r.quote_request_id = o.id
            and r.supplier_shop_id in (select id from mine)))::bigint,
    (select count(*) from open_reqs)::bigint;
$$;
revoke execute on function public.b2b_supplier_request_counts() from public, anon;
grant execute on function public.b2b_supplier_request_counts() to authenticated, service_role;

-- ─────────────────────────────────────────────────────────────
-- 6) Yeni teklif talebi → uygun tedarikçilere in-app bildirim
--    (push mevcut notifications INSERT trigger'ı ile otomatik gider).
--    Hedefleme: target_type shop/product/campaign → yalnız hedef mağaza;
--    category → kategorisi eşleşen aktif mağazalar. Alıcının kendi mağazası
--    hariç. Tekrar: aynı (alıcı, talep) için mağaza başına tek bildirim
--    (partial unique index + on conflict do nothing). Yoğunluk: mağaza
--    sahibi son 1 saatte ≥ 10 talep bildirimi aldıysa yenisi atlanır.
--    Metin generic (kimlik/telefon/not YAZILMAZ).
-- ─────────────────────────────────────────────────────────────
create unique index if not exists notifications_b2b_qr_dedupe_idx
  on public.notifications (recipient_id, entity_id)
  where type = 'b2b_quote_request_created';

create or replace function public.notify_b2b_quote_request_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_recent integer;
begin
  for v_owner in
    select distinct s.owner_id
    from public.b2b_supplier_shops s
    where s.is_active
      and s.owner_id is distinct from new.buyer_id
      and (
        (new.target_type = 'shop' and s.id = new.target_id)
        or (new.target_type = 'product' and s.id in (
              select p.shop_id from public.b2b_products p where p.id = new.target_id))
        or (new.target_type = 'campaign' and s.id in (
              select c.shop_id from public.b2b_campaigns c where c.id = new.target_id))
        or (coalesce(new.target_type, 'category') = 'category'
            and new.category = any (s.categories))
      )
  loop
    select count(*) into v_recent
      from public.notifications n
     where n.recipient_id = v_owner
       and n.type = 'b2b_quote_request_created'
       and n.created_at > now() - interval '1 hour';
    if v_recent >= 10 then
      continue;
    end if;
    insert into public.notifications
      (recipient_id, actor_id, type, title, body, entity_type, entity_id, route)
    values
      (v_owner, null, 'b2b_quote_request_created', 'Yeni teklif talebi',
       coalesce(nullif(new.category, ''), 'Ürün') ||
         case when coalesce(new.city, '') <> '' then ' · ' || new.city else '' end,
       'quote_request', new.id, '/pazar?tab=talepler')
    on conflict do nothing;
  end loop;
  return new;
end;
$$;
revoke execute on function public.notify_b2b_quote_request_created()
  from public, anon, authenticated;
drop trigger if exists trg_notify_b2b_quote_request_created on public.b2b_quote_requests;
create trigger trg_notify_b2b_quote_request_created
  after insert on public.b2b_quote_requests
  for each row execute function public.notify_b2b_quote_request_created();

-- ─────────────────────────────────────────────────────────────
-- ROLLBACK (uygulanmaz; referans) — veri kaybı yok.
--   drop trigger trg_notify_b2b_quote_request_created on public.b2b_quote_requests;
--   drop function public.notify_b2b_quote_request_created();
--   drop index notifications_b2b_qr_dedupe_idx;
--   drop function public.b2b_supplier_request_counts();
--   drop function public.b2b_open_quote_requests_page(text[],text[],boolean,integer,integer);
--   drop function public.b2b_my_replied_requests();
--   drop index idx_b2b_qr_open_cat_city; drop index idx_b2b_replies_shop_created;
--   drop index idx_b2b_shops_owner_active;
--   -- b2b_mark_request_answered: 20260618120000_b2b_v1_closing.sql tanımına dön
--   -- b2b_accept_quote_reply: 20260622160000_b2b_reply_hardening.sql tanımına dön
--   drop trigger trg_b2b_qr_guard_columns on public.b2b_quote_requests;
--   drop function public.b2b_qr_guard_columns();
--   drop trigger trg_b2b_replies_guard_insert on public.b2b_quote_replies;
--   drop function public.b2b_replies_guard_insert();
--   drop trigger trg_b2b_shops_guard_columns on public.b2b_supplier_shops;
--   drop function public.b2b_shops_guard_columns();
--   alter table public.b2b_supplier_shops drop constraint b2b_shops_contact_len,
--     drop column phone, drop column whatsapp, drop column website, drop column address;
-- ─────────────────────────────────────────────────────────────
