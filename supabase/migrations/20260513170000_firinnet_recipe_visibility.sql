-- ============================================================
-- FırınNet — Reçete görünürlüğü (V1.1)
-- Tarih: 2026-05-13
-- Amaç:
--   • Reçeteleri "Gizli (default)" ve "Profilde açık" olarak ayırmak.
--   • Authenticated kullanıcılar başka kullanıcıların `is_public = true`
--     reçetelerini okuyabilsin (profil sayfasındaki Açık Reçeteler için).
--   • Update/delete/insert hâlâ owner-only (mevcut policy'ler aynen kalıyor).
-- Notlar:
--   • Mevcut select policy `recipe_calculations_select_own` (owner = uid)
--     korunuyor. Yeni eklenen `recipe_calculations_select_public` (is_public
--     = true) permissive policy olarak OR'lanıyor — sonuç:
--       owner_id = auth.uid()  OR  is_public = true.
--   • Anon role'e select grant eklenmiyor. Kayıtsız kullanıcı profil
--     gezmiyorsa zaten gerek yok. İlerde gerekirse `to anon` permissive
--     policy bir migration ile eklenebilir.
-- Geri dönüş:
--   drop policy recipe_calculations_select_public on public.recipe_calculations;
--   drop index idx_recipe_calculations_public_created;
--   alter table public.recipe_calculations
--     drop column published_at,
--     drop column is_public;
-- ============================================================

alter table public.recipe_calculations
  add column if not exists is_public boolean not null default false,
  add column if not exists published_at timestamptz;

-- Yalnız is_public=true satırlar için sparse index. Public listeleme hızlanır,
-- private satırlar indexlenmez (boyut tasarrufu).
create index if not exists idx_recipe_calculations_public_created
  on public.recipe_calculations (created_at desc)
  where is_public = true;

-- Permissive select policy: authenticated kullanıcı başkasının açık reçetesini
-- okuyabilir. Owner policy'siyle OR'lanır.
drop policy if exists recipe_calculations_select_public on public.recipe_calculations;
create policy recipe_calculations_select_public on public.recipe_calculations
  for select to authenticated
  using (is_public = true);

comment on column public.recipe_calculations.is_public is
  'FırınNet — reçete varsayılan gizlidir. true ise profil sayfasında "Açık Reçeteler" bölümünde diğer authenticated kullanıcılara görünür. Edit/delete yine owner-only.';
comment on column public.recipe_calculations.published_at is
  'FırınNet — reçete public yapıldığı zaman damgası. is_public false iken null kalır.';
