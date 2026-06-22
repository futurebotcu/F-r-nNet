-- ============================================================
-- Push notifications PR-2 — delivery log + dispatch trigger (ADDITIVE)
-- ============================================================
-- notifications INSERT → push-dispatch edge function (FCM HTTP v1).
-- Drop/delete yok. Dispatch tamamen exception-guard'lı: pg_net/vault/secret
-- eksik veya hatalıysa in-app notification akışı ETKİLENMEZ (trigger no-op).

-- pg_net — trigger'ın edge function'ı HTTP ile çağırması için (additive).
create extension if not exists pg_net with schema extensions;

-- ─────────────────────────────────────────────────────────
-- notification_push_deliveries — delivery log + duplicate guard
-- (notification_id, token_id) unique → aynı bildirim aynı cihaza 1 kez.
-- ─────────────────────────────────────────────────────────
create table if not exists public.notification_push_deliveries (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null
    references public.notifications(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  token_id uuid not null
    references public.user_push_tokens(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'sent', 'error')),
  error text,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  constraint notification_push_deliveries_dedup unique (notification_id, token_id)
);

create index if not exists idx_npd_notification
  on public.notification_push_deliveries (notification_id);

-- RLS: kullanıcı yalnız kendi delivery kayıtlarını GÖRÜR; yazma yalnız
-- service-role (edge function) ile (RLS bypass) — client write yok.
alter table public.notification_push_deliveries enable row level security;

drop policy if exists npd_select_own on public.notification_push_deliveries;
create policy npd_select_own on public.notification_push_deliveries
  for select to authenticated
  using (user_id = auth.uid());

grant select on public.notification_push_deliveries to authenticated;

-- ─────────────────────────────────────────────────────────
-- Dispatch trigger — notifications AFTER INSERT → edge function.
-- URL + bearer Vault'tan (push_dispatch_url / push_dispatch_key). Vault
-- secret yoksa veya herhangi bir hata olursa: trigger sessizce no-op döner
-- (in-app bildirim INSERT'i ASLA başarısız olmaz).
-- ─────────────────────────────────────────────────────────
create or replace function public.dispatch_notification_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_key text;
begin
  begin
    select decrypted_secret into v_url
      from vault.decrypted_secrets where name = 'push_dispatch_url';
    select decrypted_secret into v_key
      from vault.decrypted_secrets where name = 'push_dispatch_key';
    if v_url is null or v_key is null then
      return new; -- dispatch yapılandırılmamış → no-op
    end if;
    perform net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_key
      ),
      body := jsonb_build_object('notification_id', new.id)
    );
  exception when others then
    -- Dispatch hatası in-app bildirimini ETKİLEMEZ.
    null;
  end;
  return new;
end;
$$;
revoke execute on function public.dispatch_notification_push() from public;
revoke execute on function public.dispatch_notification_push() from anon;
revoke execute on function public.dispatch_notification_push() from authenticated;

drop trigger if exists trg_notifications_push_dispatch on public.notifications;
create trigger trg_notifications_push_dispatch
  after insert on public.notifications
  for each row execute function public.dispatch_notification_push();

comment on table public.notification_push_deliveries is
  'FirinNet — push gonderim logu + duplicate guard (notification_id, token_id unique). Yazma service-role (edge function).';
