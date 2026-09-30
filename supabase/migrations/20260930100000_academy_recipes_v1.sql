-- =============================================================================
-- Akademi "Tarif" içerik türü V1 — usta tarif havuzu + taslak kind genişletme.
-- TAMAMEN KAPALI başlar: academy_recipe_enabled=false; bot tarif ÜRETİM hattı
-- bu migration'da YOK (kural/şema/denetim). Kurallar:
--  - Bot tarifi fırıncı yüzdesi aralık dışıysa RED (worker checkBakersRecipe
--    strict); usta tarifinde aralık dışı UYARI, gram↔% tutarsızlığı hep RED.
--  - Dış kaynaktan uyarlama: metin/fotoğraf kopyalanmaz (hasVerbatimOverlap
--    12-kelime kuralı worker'da), oranlar kendi anlatımıyla + kaynak linki.
--  - Postta gramaj + yüzde BİRLİKTE gösterilir.
-- =============================================================================
insert into public.app_runtime_config (key, value) values
  ('academy_recipe_enabled', 'false'::jsonb)
on conflict (key) do nothing;

create table if not exists public.academy_recipes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  author_name text not null,             -- kaynak = usta adı (görünür atıf)
  author_user_id uuid references public.profiles(id) on delete set null,
  source_kind text not null default 'master'
    check (source_kind in ('master','bot','adapted')),
  source_url text,                       -- yalnız adapted için
  ingredients jsonb not null default '[]'::jsonb, -- [{name,grams,pct?}]
  oven_c int,
  minutes int,
  steps text not null default '',
  notes text not null default '',
  check_result jsonb not null default '{}'::jsonb, -- worker denetim çıktısı
  status text not null default 'draft'
    check (status in ('draft','approved','published','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint academy_recipe_adapted_url_chk
    check (source_kind <> 'adapted' or source_url is not null)
);
alter table public.academy_recipes enable row level security;
revoke all on public.academy_recipes from public, anon, authenticated;
-- Usta girişi: kendi taslağını ekler/görür/günceller; onay/yayın YALNIZ
-- service_role (backoffice). Bot yalnız approved havuzdan yayımlar.
drop policy if exists ar_select_own on public.academy_recipes;
drop policy if exists ar_insert_own on public.academy_recipes;
drop policy if exists ar_update_own_draft on public.academy_recipes;
create policy ar_select_own on public.academy_recipes
  for select to authenticated using (author_user_id = auth.uid());
create policy ar_insert_own on public.academy_recipes
  for insert to authenticated
  with check (author_user_id = auth.uid() and status = 'draft'
              and source_kind = 'master');
create policy ar_update_own_draft on public.academy_recipes
  for update to authenticated
  using (author_user_id = auth.uid() and status = 'draft')
  with check (author_user_id = auth.uid() and status = 'draft');
grant select, insert, update on public.academy_recipes to authenticated;
grant select, insert, update, delete on public.academy_recipes
  to service_role;

-- Taslak türlerine 'recipe' eklenir (additif; mevcut veriler geçerli kalır).
alter table public.academy_drafts
  drop constraint if exists academy_drafts_kind_check;
alter table public.academy_drafts
  add constraint academy_drafts_kind_check
  check (kind in ('news','evergreen','commercial_note','humor','recipe'));
