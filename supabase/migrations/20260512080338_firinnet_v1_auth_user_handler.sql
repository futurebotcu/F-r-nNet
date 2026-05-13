-- Migration: firinnet_v1_auth_user_handler
-- Version: 20260512080338
-- Source: applied to remote project sjeqwiqgwzagengdukye via MCP apply_migration on 2026-05-12
-- This file is a local mirror for source control. DO NOT re-apply to remote;
-- remote already records this version.

-- FırınNet V1 — auth.users INSERT olunca public.profiles satirini otomatik olustur.
-- SECURITY DEFINER cunku auth schema'dan public.profiles'a yazacak.
-- RPC uzerinden disardan cagrilamasin: revoke execute from public, anon, authenticated.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_meta jsonb;
  v_display_name text;
  v_account_type_raw text;
  v_account_type text;
begin
  v_meta := coalesce(new.raw_user_meta_data, '{}'::jsonb);

  -- display_name fallback zinciri
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

  -- account_type beyaz liste; gecersizse 'individual'
  v_account_type_raw := v_meta->>'account_type';
  if v_account_type_raw in ('commercial','individual','wholesaler') then
    v_account_type := v_account_type_raw;
  else
    v_account_type := 'individual';
  end if;

  insert into public.profiles (
    id, display_name, account_type, profession_badge, city, avatar_url, email
  ) values (
    new.id,
    v_display_name,
    v_account_type,
    nullif(trim(v_meta->>'profession_badge'), ''),
    nullif(trim(v_meta->>'city'), ''),
    nullif(trim(v_meta->>'avatar_url'), ''),
    new.email
  )
  on conflict (id) do update
    set email = excluded.email,
        updated_at = now();
  -- Not: display_name/account_type/profession_badge/city/avatar_url conflict halinde
  -- KASITLI olarak ezilmez — kullanici formdan/profil ekranindan degisrmis olabilir.

  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public;
revoke execute on function public.handle_new_user() from anon;
revoke execute on function public.handle_new_user() from authenticated;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

comment on function public.handle_new_user() is 'FırınNet V1 - auth.users INSERT triggeri; public.profiles satirini olusturur, conflict halinde sadece email/updated_at update.';
