-- ============================================================
-- Push notifications PR-1 — user_push_tokens (FCM device tokens) (ADDITIVE)
-- ============================================================
-- Uygulama-dışı (sistem tepsisi) push için cihaz FCM token'ları. RLS owner-only.
-- Token GLOBAL unique (bir cihaz = bir token); aynı cihaz farklı kullanıcıya
-- geçince token o kullanıcıya devredilir → SECURITY DEFINER RPC ile (client
-- RLS başkasının satırını UPDATE edemez). Migration additif; drop/delete yok.

create table if not exists public.user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  platform text not null default 'android'
    check (platform in ('android', 'ios', 'web')),
  device_id text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  constraint user_push_tokens_token_key unique (token)
);

create index if not exists idx_user_push_tokens_user_active
  on public.user_push_tokens (user_id)
  where is_active;

drop trigger if exists trg_user_push_tokens_updated_at on public.user_push_tokens;
create trigger trg_user_push_tokens_updated_at
  before update on public.user_push_tokens
  for each row execute function public.set_updated_at();

-- ─────────────────────────────────────────────────────────
-- RLS — owner-only (başkasının token'ı okunamaz/yazılamaz)
-- ─────────────────────────────────────────────────────────
alter table public.user_push_tokens enable row level security;

drop policy if exists user_push_tokens_select_own on public.user_push_tokens;
create policy user_push_tokens_select_own on public.user_push_tokens
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists user_push_tokens_insert_own on public.user_push_tokens;
create policy user_push_tokens_insert_own on public.user_push_tokens
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists user_push_tokens_update_own on public.user_push_tokens;
create policy user_push_tokens_update_own on public.user_push_tokens
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists user_push_tokens_delete_own on public.user_push_tokens;
create policy user_push_tokens_delete_own on public.user_push_tokens
  for delete to authenticated
  using (user_id = auth.uid());

grant select, insert, update, delete on public.user_push_tokens to authenticated;

-- ─────────────────────────────────────────────────────────
-- register_push_token — login/refresh'te token kaydı (device reassignment
-- güvenli). SECURITY DEFINER: token başka kullanıcıdaysa o kullanıcıdan alınır
-- (B, A'nın bildirimini almasın). auth.uid() zorunlu.
-- ─────────────────────────────────────────────────────────
create or replace function public.register_push_token(
  p_token text,
  p_platform text default 'android',
  p_device_id text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'auth required';
  end if;
  if p_token is null or length(trim(p_token)) = 0 then
    raise exception 'token required';
  end if;
  -- Token'ı başka kullanıcıdan al (aynı cihaz devri).
  delete from public.user_push_tokens
    where token = p_token and user_id <> auth.uid();
  insert into public.user_push_tokens (
    user_id, token, platform, device_id, is_active, last_seen_at, updated_at
  )
  values (
    auth.uid(), p_token, coalesce(p_platform, 'android'), p_device_id,
    true, now(), now()
  )
  on conflict (token) do update
    set user_id = auth.uid(),
        platform = excluded.platform,
        device_id = coalesce(excluded.device_id, user_push_tokens.device_id),
        is_active = true,
        last_seen_at = now(),
        updated_at = now();
end;
$$;
revoke execute on function public.register_push_token(text, text, text) from public;
revoke execute on function public.register_push_token(text, text, text) from anon;
grant execute on function public.register_push_token(text, text, text)
  to authenticated;

-- ─────────────────────────────────────────────────────────
-- deactivate_push_token — logout'ta kendi token'ını pasifleştir.
-- ─────────────────────────────────────────────────────────
create or replace function public.deactivate_push_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return;
  end if;
  update public.user_push_tokens
    set is_active = false, updated_at = now()
    where token = p_token and user_id = auth.uid();
end;
$$;
revoke execute on function public.deactivate_push_token(text) from public;
revoke execute on function public.deactivate_push_token(text) from anon;
grant execute on function public.deactivate_push_token(text) to authenticated;

comment on table public.user_push_tokens is
  'FirinNet — kullanici push (FCM) device token tablosu. RLS owner-only. Token global unique; register_push_token RPC ile cihaz devri guvenli.';
