-- =============================================================================
-- FırınNet Data Foundation M5 — Controlled profession taxonomy (kod sütunu).
-- =============================================================================
-- Hedef: meslek bilgisini Türkçe label yerine ASCII code olarak tut.
-- UI label gösterir; DB code yazar.
--
-- Etki:
--   * `profiles.profession_badge_code`        (yeni, nullable)
--   * `worker_profiles.profession_badge_code` (yeni, nullable)
--   * `job_seek_posts.profession_badge_code`  (yeni, nullable)
--   * 3 yeni CHECK constraint (allowed code listesi — taxonomy ile birebir)
--   * Backfill: Türkçe label → code (case-insensitive trim)
--   * Eski `profession_badge` text kolonları KORUNUR (display fallback;
--     M3'te public_profile_detail RPC'si bunu okuyor; UI önce code'u dener,
--     yoksa text'i gösterir).
--
-- Geri dönüş:
--   alter table public.profiles drop column profession_badge_code;
--   alter table public.worker_profiles drop column profession_badge_code;
--   alter table public.job_seek_posts drop column profession_badge_code;
-- =============================================================================

-- ─── 1. Yeni nullable code kolonları ────────────────────────────────
alter table public.profiles
  add column if not exists profession_badge_code text;

alter table public.worker_profiles
  add column if not exists profession_badge_code text;

alter table public.job_seek_posts
  add column if not exists profession_badge_code text;


-- ─── 2. Backfill — Türkçe label → code (case-insensitive trim) ──────
--
-- Map (taxonomy ile birebir):
--   usta_firinci, firin_sahibi, isletmeci, mayaci, hamurcu, simitci,
--   pogacaci, pasta_ustasi, pideci, cirak, kalfa, uncu, susamci, toptanci,
--   ekipman_satici, sofor, other
--
-- Bilinmeyen label → null (kullanıcı UI'da yeniden seçer).

create or replace function public._m5_profession_label_to_code(p_label text)
returns text
language sql
immutable
as $$
  select case lower(btrim(coalesce(p_label, '')))
    when 'usta fırıncı'      then 'usta_firinci'
    when 'fırın sahibi'      then 'firin_sahibi'
    when 'işletmeci'         then 'isletmeci'
    when 'mayacı'            then 'mayaci'
    when 'hamurcu'           then 'hamurcu'
    when 'simitçi'           then 'simitci'
    when 'poğaçacı'          then 'pogacaci'
    when 'pasta ustası'      then 'pasta_ustasi'
    when 'pideci'            then 'pideci'
    when 'çırak'             then 'cirak'
    when 'kalfa'             then 'kalfa'
    when 'uncu'              then 'uncu'
    when 'susamcı'           then 'susamci'
    when 'toptancı'          then 'toptanci'
    when 'ekipman satıcısı'  then 'ekipman_satici'
    when 'şoför'             then 'sofor'
    when 'diğer'             then 'other'
    -- Legacy yan formlar:
    when 'çalışan/usta'      then 'usta_firinci'
    when 'pastacı'           then 'pasta_ustasi'
    else null
  end;
$$;

update public.profiles
   set profession_badge_code = public._m5_profession_label_to_code(profession_badge)
 where profession_badge_code is null
   and profession_badge is not null;

update public.worker_profiles
   set profession_badge_code = public._m5_profession_label_to_code(profession_badge)
 where profession_badge_code is null
   and profession_badge is not null;

update public.job_seek_posts
   set profession_badge_code = public._m5_profession_label_to_code(profession_badge)
 where profession_badge_code is null
   and profession_badge is not null;

drop function public._m5_profession_label_to_code(text);


-- ─── 3. CHECK constraints — allowed code listesi ────────────────────
--
-- nullable: profession_badge_code IS NULL kabul. Allowed code listesi
-- taxonomy ile birebir; yeni code eklenirse migration güncellenir.

alter table public.profiles
  drop constraint if exists profiles_profession_badge_code_chk;
alter table public.profiles
  add constraint profiles_profession_badge_code_chk
  check (
    profession_badge_code is null
    or profession_badge_code in (
      'usta_firinci','firin_sahibi','isletmeci','mayaci','hamurcu',
      'simitci','pogacaci','pasta_ustasi','pideci','cirak','kalfa',
      'uncu','susamci','toptanci','ekipman_satici','sofor','other'
    )
  );

alter table public.worker_profiles
  drop constraint if exists worker_profiles_profession_badge_code_chk;
alter table public.worker_profiles
  add constraint worker_profiles_profession_badge_code_chk
  check (
    profession_badge_code is null
    or profession_badge_code in (
      'usta_firinci','firin_sahibi','isletmeci','mayaci','hamurcu',
      'simitci','pogacaci','pasta_ustasi','pideci','cirak','kalfa',
      'uncu','susamci','toptanci','ekipman_satici','sofor','other'
    )
  );

alter table public.job_seek_posts
  drop constraint if exists job_seek_posts_profession_badge_code_chk;
alter table public.job_seek_posts
  add constraint job_seek_posts_profession_badge_code_chk
  check (
    profession_badge_code is null
    or profession_badge_code in (
      'usta_firinci','firin_sahibi','isletmeci','mayaci','hamurcu',
      'simitci','pogacaci','pasta_ustasi','pideci','cirak','kalfa',
      'uncu','susamci','toptanci','ekipman_satici','sofor','other'
    )
  );


-- ─── 4. public_profile_detail RPC — code alanlarını whitelist'e ekle ─
--
-- M3 RPC profile + worker bloklarına profession_badge_code ekleniyor.
-- Eski profession_badge (text) korunur — UI önce code'u dener.

create or replace function public.public_profile_detail(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_profile     jsonb;
  v_worker      jsonb;
  v_experiences jsonb;
  v_bakery      jsonb;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  select to_jsonb(t) into v_profile
    from (
      select id, display_name, avatar_url, account_type,
             profession_badge, profession_badge_code, city
        from public.profiles
       where id = p_user_id
    ) t;

  if v_profile is null then
    return null;
  end if;

  select to_jsonb(t) into v_worker
    from (
      select profession_badge, profession_badge_code, experience_years,
             cities, skills, shift_preference, bio
        from public.worker_profiles
       where owner_id = p_user_id
       limit 1
    ) t;

  select coalesce(
           jsonb_agg(to_jsonb(t) order by t.start_date desc nulls last),
           '[]'::jsonb
         )
    into v_experiences
    from (
      select id, title, city, start_date, end_date, description
        from public.worker_experiences
       where owner_id = p_user_id
       order by start_date desc nulls last
       limit 20
    ) t;

  select to_jsonb(t) into v_bakery
    from (
      select id, name, city, district, description
        from public.bakeries
       where owner_id = p_user_id
       order by created_at desc nulls last
       limit 1
    ) t;

  return jsonb_build_object(
    'profile',     v_profile,
    'worker',      v_worker,
    'experiences', v_experiences,
    'bakery',      v_bakery
  );
end;
$$;

revoke all on function public.public_profile_detail(uuid) from public;
grant execute on function public.public_profile_detail(uuid) to authenticated;
