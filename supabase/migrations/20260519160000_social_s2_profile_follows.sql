-- =============================================================================
-- FırınNet Social S2 — Profile Follow System
-- =============================================================================
-- Sosyal omurganın takip katmanı. Public profile sayfasında "Takip et /
-- Takipten çık" butonu ve followers/following count rozetleri için.
--
-- Tasarım:
--   * Tablo: profile_follows(follower_id, following_id, created_at)
--   * Composite PK = (follower_id, following_id) → idempotent: aynı çift
--     iki kez insert edilemez (duplicate follow olmaz).
--   * CHECK (follower_id <> following_id) → self-follow yapısal olarak
--     yasak.
--   * RLS:
--     - SELECT authenticated: tüm follow graph okunabilir (sosyal sayaçlar
--       için). Hassas alan yok.
--     - INSERT authenticated: yalnız `follower_id = auth.uid()` (kendi
--       adına takip; başka biri adına yapamaz).
--     - DELETE authenticated: yalnız `follower_id = auth.uid()` (kendi
--       takibini geri çekebilir). "Followee siler" yetkisi yok (V1'de
--       block sistemi yok; TODO).
--     - UPDATE policy yok → default-deny (zaten anlamlı değil).
--   * anon role hiç DML almaz; default-deny.
--
-- Donor kıyaslaması:
--   Donor (itsezlife) `subscriptions(id, subscriber_id, subscribed_to_id)`
--   tablosunda surrogate uuid PK + `WITH CHECK (true)` gibi gevşek
--   policy'ler kullanıyor. Bu migration FırınNet RLS standardına göre
--   sıkılaştırılır: surrogate id yok (gereksiz; composite zaten unique),
--   self-follow CHECK + INSERT/DELETE owner-only policy.
--
-- Block desteği (V2):
--   `blocked_users(user_id, blocked_user_id)` tablosu eklendiğinde follow
--   policy'ye `AND NOT EXISTS (... blocked ...)` koşulu eklenebilir. Şu
--   an böyle bir tablo yok; gevşek policy yazmamak için sadece TODO.
--
-- Geri dönüş (manuel):
--   drop policy if exists profile_follows_select_visible on public.profile_follows;
--   drop policy if exists profile_follows_insert_self on public.profile_follows;
--   drop policy if exists profile_follows_delete_self on public.profile_follows;
--   drop table if exists public.profile_follows;
-- =============================================================================

create table public.profile_follows (
  follower_id   uuid not null references public.profiles(id) on delete cascade,
  following_id  uuid not null references public.profiles(id) on delete cascade,
  created_at    timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint profile_follows_no_self check (follower_id <> following_id)
);

create index profile_follows_follower_idx
  on public.profile_follows (follower_id, created_at desc);

create index profile_follows_following_idx
  on public.profile_follows (following_id, created_at desc);

alter table public.profile_follows enable row level security;

create policy profile_follows_select_visible
  on public.profile_follows
  for select to authenticated
  using (true);

create policy profile_follows_insert_self
  on public.profile_follows
  for insert to authenticated
  with check (follower_id = auth.uid());

create policy profile_follows_delete_self
  on public.profile_follows
  for delete to authenticated
  using (follower_id = auth.uid());

grant select, insert, delete on public.profile_follows to authenticated;

comment on table public.profile_follows is
  'V1 Social S2 — Public follow graph. Composite PK (follower, following) '
  'idempotent; self-follow CHECK; RLS INSERT/DELETE only follower self.';
