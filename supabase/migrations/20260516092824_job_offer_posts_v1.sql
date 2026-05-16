-- Migration: job_offer_posts_v1
-- Version: 20260516092824
-- Applied to remote: 2026-05-16 via MCP apply_migration.
--
-- FırınNet — Ticari/Toptancı "Usta Arıyor / İş Veriyorum" ilanları.
-- Bireysel kullanıcılar bunları yalnız okuyabilir (RLS authenticated
-- select aktif olanları; ilan veremezler — UI guard rolü kontrol eder).
-- Bireysel kullanıcının "İş Arıyorum" ilanları zaten `job_seek_posts`'ta.

create table public.job_offer_posts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  bakery_id uuid references public.bakeries(id) on delete set null,
  title text not null,
  role_title text not null,
  city text,
  district text,
  description text,
  salary_min numeric(12,2) check (salary_min is null or salary_min >= 0),
  salary_max numeric(12,2) check (salary_max is null or salary_max >= 0),
  shift_type text,
  experience_required text,
  is_active boolean not null default true,
  contact_preference text not null default 'in_app'
    check (contact_preference in ('in_app','phone','whatsapp')),
  author_name text not null default '',
  author_role text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_job_offer_posts_active_created
  on public.job_offer_posts (created_at desc)
  where is_active = true;
create index idx_job_offer_posts_owner
  on public.job_offer_posts (owner_id, created_at desc);
create index idx_job_offer_posts_city
  on public.job_offer_posts (city) where is_active = true;

-- Snapshot author: BEFORE INSERT — profiles owner-only RLS bypass için SECURITY DEFINER.
create or replace function public.snapshot_job_offer_post_author()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_name text; v_badge text; v_account text;
begin
  select
    coalesce(nullif(trim(display_name), ''), ''),
    coalesce(nullif(trim(profession_badge), ''), ''),
    coalesce(nullif(trim(account_type), ''), '')
  into v_name, v_badge, v_account from public.profiles where id = new.owner_id;
  new.author_name := coalesce(nullif(v_name, ''), 'FırınNet İşletmesi');
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
revoke execute on function public.snapshot_job_offer_post_author() from public;
revoke execute on function public.snapshot_job_offer_post_author() from anon;
revoke execute on function public.snapshot_job_offer_post_author() from authenticated;

create trigger trg_job_offer_posts_snapshot_author
  before insert on public.job_offer_posts
  for each row execute function public.snapshot_job_offer_post_author();

create trigger trg_job_offer_posts_updated_at
  before update on public.job_offer_posts
  for each row execute function public.set_updated_at();

alter table public.job_offer_posts enable row level security;

create policy job_offer_posts_select_active_or_own on public.job_offer_posts
  for select to authenticated
  using (is_active = true or owner_id = auth.uid());

create policy job_offer_posts_insert_own on public.job_offer_posts
  for insert to authenticated
  with check (owner_id = auth.uid());

create policy job_offer_posts_update_own on public.job_offer_posts
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy job_offer_posts_delete_own on public.job_offer_posts
  for delete to authenticated
  using (owner_id = auth.uid());

grant select, insert, update, delete on public.job_offer_posts to authenticated;

comment on table public.job_offer_posts is
  'FırınNet — Ticari/Toptancı "Usta Arıyor / İş Veriyorum" ilanları. RLS: active or own select, owner CRUD.';
