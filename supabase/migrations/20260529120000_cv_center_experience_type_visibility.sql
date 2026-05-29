-- Unified Professional CV Center Sprint (2026-05-29)
-- worker_experiences CV entry type + visibility (additive, geriye uyumlu).
-- RLS owner-only base policy değişmedi; public görünürlük public_profile_detail
-- RPC içinde is_public ile uygulanır (başkası yalnız is_public=true görür,
-- owner kendi tümünü görür). Uzakta apply_migration ile uygulandı
-- (cv_center_experience_type_visibility).

alter table public.worker_experiences
  add column if not exists entry_type text not null default 'individual',
  add column if not exists is_public boolean not null default true;

create or replace function public.public_profile_detail(p_user_id uuid)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'public', 'pg_temp'
as $function$
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
             profession_badge, profession_badge_code,
             city, city_code
        from public.profiles
       where id = p_user_id
    ) t;

  if v_profile is null then
    return null;
  end if;

  select to_jsonb(t) into v_worker
    from (
      select profession_badge, profession_badge_code, experience_years,
             cities, city_codes, skills, skill_codes,
             shift_preference, bio
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
      select id, title, workplace, city, city_code, start_date, end_date,
             description, entry_type, is_public
        from public.worker_experiences
       where owner_id = p_user_id
         and (is_public = true or p_user_id = auth.uid())
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
$function$;
