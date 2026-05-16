-- Migration: market_listings_v1
-- Version: 20260516092830
-- Applied to remote: 2026-05-16 via MCP apply_migration.
--
-- FırınNet — Marketplace ürün/hizmet/ekipman ilanları.
-- Authenticated kullanıcı kendi ilanını oluşturur, başkalarının aktif
-- ilanlarını okuyabilir.

create table public.market_listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  category text not null
    check (category in ('hammadde','ekipman','devren_firin','ikinci_el','ambalaj','hizmet','diger')),
  listing_type text not null default 'product'
    check (listing_type in ('product','service','equipment')),
  condition text
    check (condition is null or condition in ('new','used','as_is')),
  description text,
  city text,
  district text,
  price numeric(14,2) check (price is null or price >= 0),
  unit text,
  contact_preference text not null default 'in_app'
    check (contact_preference in ('in_app','phone','whatsapp')),
  is_active boolean not null default true,
  author_name text not null default '',
  author_role text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_market_listings_active_created
  on public.market_listings (created_at desc)
  where is_active = true;
create index idx_market_listings_owner
  on public.market_listings (owner_id, created_at desc);
create index idx_market_listings_category
  on public.market_listings (category) where is_active = true;
create index idx_market_listings_city
  on public.market_listings (city) where is_active = true;

create or replace function public.snapshot_market_listing_author()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_name text; v_badge text; v_account text;
begin
  select
    coalesce(nullif(trim(display_name), ''), ''),
    coalesce(nullif(trim(profession_badge), ''), ''),
    coalesce(nullif(trim(account_type), ''), '')
  into v_name, v_badge, v_account from public.profiles where id = new.owner_id;
  new.author_name := coalesce(nullif(v_name, ''), 'FırınNet Satıcı');
  new.author_role := coalesce(
    nullif(v_badge, ''),
    case v_account
      when 'commercial' then 'Ticari'
      when 'wholesaler' then 'Toptancı'
      when 'individual' then 'Bireysel'
      else 'Üye'
    end);
  return new;
end; $$;
revoke execute on function public.snapshot_market_listing_author() from public;
revoke execute on function public.snapshot_market_listing_author() from anon;
revoke execute on function public.snapshot_market_listing_author() from authenticated;

create trigger trg_market_listings_snapshot_author
  before insert on public.market_listings
  for each row execute function public.snapshot_market_listing_author();

create trigger trg_market_listings_updated_at
  before update on public.market_listings
  for each row execute function public.set_updated_at();

alter table public.market_listings enable row level security;

create policy market_listings_select_active_or_own on public.market_listings
  for select to authenticated
  using (is_active = true or owner_id = auth.uid());

create policy market_listings_insert_own on public.market_listings
  for insert to authenticated
  with check (owner_id = auth.uid());

create policy market_listings_update_own on public.market_listings
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy market_listings_delete_own on public.market_listings
  for delete to authenticated
  using (owner_id = auth.uid());

grant select, insert, update, delete on public.market_listings to authenticated;

comment on table public.market_listings is
  'FırınNet — Marketplace ürün/hizmet/ekipman ilanları. RLS: active or own select, owner CRUD.';
