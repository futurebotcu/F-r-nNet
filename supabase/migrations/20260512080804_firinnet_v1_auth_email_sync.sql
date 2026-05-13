-- Migration: firinnet_v1_auth_email_sync
-- Version: 20260512080804
-- Source: applied to remote project sjeqwiqgwzagengdukye via MCP apply_migration on 2026-05-12
-- This file is a local mirror for source control. DO NOT re-apply to remote;
-- remote already records this version.

-- FırınNet V1 — auth.users.email UPDATE olunca public.profiles.email senkronize.
-- handle_new_user'in tamamlayicisi: o INSERT, bu UPDATE yolunu kapatir.

create or replace function public.sync_profile_email()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  update public.profiles
  set email = new.email,
      updated_at = now()
  where id = new.id;
  return new;
end;
$$;

revoke execute on function public.sync_profile_email() from public;
revoke execute on function public.sync_profile_email() from anon;
revoke execute on function public.sync_profile_email() from authenticated;

create trigger on_auth_user_email_updated
after update of email on auth.users
for each row
when (old.email is distinct from new.email)
execute function public.sync_profile_email();

comment on function public.sync_profile_email() is 'FırınNet V1 - auth.users.email UPDATE triggeri; iliskili public.profiles satirinin email + updated_at alanini guncellestirir.';
