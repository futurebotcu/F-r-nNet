-- =============================================================================
-- FırınNet ID Foundation — benzersiz, kalıcı, okunabilir kullanıcı numarası.
-- =============================================================================
-- Format: FN-YYYY-NNNNNN (örn. FN-2026-000001). Her yıl 1'den başlar.
--
-- Gizlilik kuralı:
--   * profiles.firinnet_id text UNIQUE — yalnız sahibine açık.
--   * profiles RLS zaten owner-only (id = auth.uid()) — bu alan
--     başka kullanıcıya direkt sızmaz.
--   * public_profile_snapshot + public_profile_detail RPC'lerinde
--     firinnet_id whitelist'e EKLENMEZ — kasıtlı.
--   * Bu ID resmi kimlik değildir (KYC / vergi no / TC kimlik / login
--     factor değil). Sadece uygulama içi referans.
--
-- Üretim stratejisi (race-safe):
--   1. Per-year counter tablosu (firinnet_id_counters) — INSERT...ON
--      CONFLICT DO UPDATE row lock atomic.
--   2. generate_firinnet_id() SECURITY DEFINER function — anon/auth
--      doğrudan çağıramaz (revoke), sadece handle_new_user trigger
--      tarafından kullanılır.
--   3. handle_new_user trigger'ı firinnet_id'yi insert sırasında doldurur.
--   4. Mevcut row'lar için tek UPDATE ile backfill (set expression her
--      satır için yeniden evaluate edilir).
--
-- Backward compat:
--   * Eski profile satırları null kalmaz — backfill ile ID alır.
--   * Migration sonrası yeni signup'lar otomatik ID alır.
--   * UNIQUE constraint + format CHECK constraint DB-level güvence.
--
-- Geri dönüş:
--   alter table public.profiles drop constraint profiles_firinnet_id_format_chk;
--   alter table public.profiles drop constraint profiles_firinnet_id_unique;
--   alter table public.profiles drop column firinnet_id;
--   -- handle_new_user trigger fonksiyonunu önceki sürüme geri yükle
--   drop function public.generate_firinnet_id();
--   drop table public.firinnet_id_counters;
-- =============================================================================

-- ─── 1. Counter tablosu (per-year) ──────────────────────────────────
create table if not exists public.firinnet_id_counters (
  year    int primary key,
  counter bigint not null default 0,
  updated_at timestamptz not null default now()
);

-- Counter tablosu yalnız generate_firinnet_id() üzerinden değiştirilir;
-- doğrudan client erişimi yok. RLS açık tutuyoruz (her ihtimale karşı)
-- ama policy yok = client'tan tamamen kapalı.
alter table public.firinnet_id_counters enable row level security;
comment on table public.firinnet_id_counters is
  'FırınNet ID per-year counter. generate_firinnet_id() ile atomic INSERT'
  '...ON CONFLICT DO UPDATE. Client erişimi yok (RLS + no policy + revoke).';


-- ─── 2. firinnet_id kolonu + UNIQUE + format CHECK ──────────────────
alter table public.profiles
  add column if not exists firinnet_id text;

-- Format: FN-YYYY-NNNNNN (yıl 4 hane, sayaç 6 hane).
alter table public.profiles
  drop constraint if exists profiles_firinnet_id_format_chk;
alter table public.profiles
  add constraint profiles_firinnet_id_format_chk
  check (firinnet_id is null or firinnet_id ~ '^FN-[0-9]{4}-[0-9]{6}$');

-- UNIQUE — aynı ID iki kullanıcıya verilemez.
alter table public.profiles
  drop constraint if exists profiles_firinnet_id_unique;
alter table public.profiles
  add constraint profiles_firinnet_id_unique unique (firinnet_id);


-- ─── 3. generate_firinnet_id() — atomic per-year generation ────────
create or replace function public.generate_firinnet_id()
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_year    int := extract(year from now())::int;
  v_counter bigint;
begin
  -- Atomic upsert: yıl yoksa insert, varsa counter+=1. RETURNING'ten
  -- güncel counter alınır. ON CONFLICT row lock atomic.
  insert into public.firinnet_id_counters (year, counter)
    values (v_year, 1)
  on conflict (year) do update
    set counter = public.firinnet_id_counters.counter + 1,
        updated_at = now()
  returning counter into v_counter;

  return 'FN-' || v_year::text || '-' || lpad(v_counter::text, 6, '0');
end;
$$;

-- Sadece SECURITY DEFINER trigger'lar kullansın; client/anon/auth doğrudan
-- çağıramasın. Public hak yok.
revoke all on function public.generate_firinnet_id() from public;
revoke all on function public.generate_firinnet_id() from anon, authenticated;


-- ─── 4. handle_new_user trigger entegrasyonu ─────────────────────────
-- Yeni profil satırına firinnet_id otomatik atanır. on conflict do update
-- mevcut firinnet_id'yi EZMEZ (var olan kullanıcı tekrar trigger'a girerse
-- ID değişmez).

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $function$
declare
  v_meta jsonb;
  v_display_name text;
  v_account_type_raw text;
  v_account_type text;
begin
  v_meta := coalesce(new.raw_user_meta_data, '{}'::jsonb);

  v_display_name := nullif(trim(v_meta->>'display_name'), '');
  if v_display_name is null then
    v_display_name := nullif(trim(v_meta->>'name'), '');
  end if;
  if v_display_name is null and new.email is not null then
    v_display_name := nullif(split_part(new.email, '@', 1), '');
  end if;
  if v_display_name is null then
    v_display_name := 'FırınNet Kullanıcısı';
  end if;

  v_account_type_raw := v_meta->>'account_type';
  if v_account_type_raw in ('commercial','individual','wholesaler') then
    v_account_type := v_account_type_raw;
  else
    v_account_type := 'individual';
  end if;

  insert into public.profiles (
    id, display_name, account_type, profession_badge, city, avatar_url,
    email, firinnet_id
  ) values (
    new.id,
    v_display_name,
    v_account_type,
    nullif(trim(v_meta->>'profession_badge'), ''),
    nullif(trim(v_meta->>'city'), ''),
    nullif(trim(v_meta->>'avatar_url'), ''),
    new.email,
    public.generate_firinnet_id()
  )
  on conflict (id) do update
    set email = excluded.email,
        updated_at = now();
  -- Not: display_name/account_type/profession_badge/city/avatar_url/
  -- firinnet_id conflict halinde KASITLI olarak ezilmez.

  return new;
end;
$function$;


-- ─── 5. Mevcut profil satırları için backfill ────────────────────────
-- Tek UPDATE — set expression her satır için yeniden evaluate edilir
-- (PG dokümanı). Counter atomic olduğu için her satır benzersiz ID alır.
-- Mevcut firinnet_id varsa (yoksa null) skip; tekrar verilmez.

update public.profiles
   set firinnet_id = public.generate_firinnet_id()
 where firinnet_id is null;
