-- ============================================================
-- DB Integrity Guards (PR-4)
-- Audit: FN-AUDIT-011 / 012 / 016 / 019 / 009
-- ADDITIF. Drop/delete YOK (idempotent create-or-replace + 1 CHECK).
-- Production'a apply ONAY ile (bu dosya repo mirror).
--
-- NOT (guard trigger'ları): SECURITY INVOKER (definer DEĞİL). Definer olsaydı
-- current_user her zaman definer olur, client (authenticated) ayrımı çökerdi.
-- INVOKER ile: client UPDATE → current_user='authenticated' (bloklanır);
-- counter/bump SECURITY DEFINER fonksiyonu içinden gelen UPDATE → current_user
-- definer rolü (geçer). returns trigger → PostgREST RPC olarak çağrılamaz.
-- ============================================================

-- ─────────────────────────────────────────────────────────
-- FN-AUDIT-011 — Sosyal denormalize sayaçları client UPDATE ile değişemez.
-- feed_posts.{like_count,comment_count,repost_count} + feed_comments.like_count
-- yalnız sunucu (counter trigger) tarafından yazılır.
-- ─────────────────────────────────────────────────────────
create or replace function public.feed_guard_server_counters()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('authenticated', 'anon') then
    if tg_table_name = 'feed_posts' then
      if new.like_count is distinct from old.like_count
         or new.comment_count is distinct from old.comment_count
         or new.repost_count is distinct from old.repost_count then
        raise exception 'counters are server-managed';
      end if;
    elsif tg_table_name = 'feed_comments' then
      if new.like_count is distinct from old.like_count then
        raise exception 'counters are server-managed';
      end if;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_feed_posts_guard_counters on public.feed_posts;
create trigger trg_feed_posts_guard_counters
  before update on public.feed_posts
  for each row execute function public.feed_guard_server_counters();

drop trigger if exists trg_feed_comments_guard_counters on public.feed_comments;
create trigger trg_feed_comments_guard_counters
  before update on public.feed_comments
  for each row execute function public.feed_guard_server_counters();

-- ─────────────────────────────────────────────────────────
-- FN-AUDIT-019 — job_conversations lifecycle (status/last_message_at) client
-- UPDATE ile manipüle edilemez. last_message_at yalnız bump (definer) ile;
-- status değişimi (close vb.) varsa ileride RPC ile yapılır. (Uygulama şu an
-- bu alanları doğrudan UPDATE etmiyor — generic messaging'e geçildi.)
-- ─────────────────────────────────────────────────────────
create or replace function public.job_conversations_guard_lifecycle()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('authenticated', 'anon')
     and (new.status is distinct from old.status
          or new.last_message_at is distinct from old.last_message_at) then
    raise exception 'conversation lifecycle is server-managed';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_job_conversations_guard_lifecycle
  on public.job_conversations;
create trigger trg_job_conversations_guard_lifecycle
  before update on public.job_conversations
  for each row execute function public.job_conversations_guard_lifecycle();

-- ─────────────────────────────────────────────────────────
-- FN-AUDIT-016 — dealer_transactions.amount işaret bütünlüğü.
-- payment/return/delivery negatif olamaz; adjustment imzalı (düzeltme) kalır.
-- APPLY ÖNCESİ read-only kontrol gerekir (bkz. PR notu):
--   select count(*) from public.dealer_transactions
--   where type <> 'adjustment' and amount < 0;  -- 0 olmalı
-- ─────────────────────────────────────────────────────────
alter table public.dealer_transactions
  add constraint dealer_transactions_amount_sign
  check (type = 'adjustment' or amount >= 0);

-- ─────────────────────────────────────────────────────────
-- FN-AUDIT-009 — Şoför not eklerse owner_id PATRON'a yazılır (görünmez not
-- olmasın). driver_add_transaction deseni: atama + owner doğrulanır,
-- owner_id = patron. Patron normal addNote akışı (owner-only RLS) değişmez.
-- ─────────────────────────────────────────────────────────
create or replace function public.driver_add_note(
  p_dealer_id uuid,
  p_note text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_driver uuid;
  v_owner uuid;
  v_dealer_owner uuid;
  v_id uuid;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if coalesce(trim(p_note), '') = '' then raise exception 'empty note'; end if;

  select dd.id, dd.owner_id into v_driver, v_owner
  from public.dealer_driver_assignments a
  join public.dealer_drivers dd on dd.id = a.driver_id
  where a.dealer_id = p_dealer_id
    and dd.driver_user_id = v_uid
    and dd.is_active = true
  limit 1;
  if v_driver is null then raise exception 'not assigned to this dealer'; end if;

  select owner_id into v_dealer_owner from public.dealers where id = p_dealer_id;
  if v_dealer_owner is null then raise exception 'dealer not found'; end if;
  if v_dealer_owner <> v_owner then raise exception 'owner mismatch'; end if;

  insert into public.dealer_notes(owner_id, dealer_id, note)
  values (v_owner, p_dealer_id, trim(p_note))
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.driver_add_note(uuid, text) from public, anon;
grant execute on function public.driver_add_note(uuid, text) to authenticated;

-- ─────────────────────────────────────────────────────────
-- FN-AUDIT-012 — create_driver_invite: FN-ID var/yok + ilişki durumu MESAJDAN
-- anlaşılmasın (çözümlenemeyen / self / zaten-şoför / bekleyen → tek generic
-- 'invite failed') + owner başına SAATLİK davet rate-limit (enumeration yavaşlat).
-- ─────────────────────────────────────────────────────────
create or replace function public.create_driver_invite(
  p_target_firinnet_id text,
  p_driver_name text default null::text,
  p_driver_phone text default null::text,
  p_note text default null::text,
  p_permission_level text default 'half'
) returns uuid
  language plpgsql security definer set search_path to ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_fn text := upper(trim(coalesce(p_target_firinnet_id, '')));
  v_perm text := lower(coalesce(p_permission_level, 'half'));
  v_target uuid;
  v_pending_count int;
  v_recent_count int;
  v_id uuid;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if coalesce(trim(p_driver_name), '') = '' then raise exception 'name required'; end if;
  if v_perm not in ('half','full') then raise exception 'invalid permission'; end if;

  -- Rate-limit: owner başına son 1 saatte oluşturulan davet sayısı.
  select count(*) into v_recent_count
  from public.dealer_driver_invites
  where owner_id = v_uid and created_at > now() - interval '1 hour';
  if v_recent_count >= 15 then raise exception 'too many invites'; end if;

  -- Pending cap (mevcut güçlendirme).
  select count(*) into v_pending_count
  from public.dealer_driver_invites where owner_id = v_uid and status = 'pending';
  if v_pending_count >= 20 then raise exception 'too many invites'; end if;

  -- FN-ID çözümü: bulunamadı / self / zaten şoför / bekleyen davet → TEK mesaj.
  select id into v_target from public.profiles where firinnet_id = v_fn;
  if v_target is null
     or v_target = v_uid
     or exists (select 1 from public.dealer_drivers
                where owner_id = v_uid and driver_user_id = v_target)
     or exists (select 1 from public.dealer_driver_invites
                where owner_id = v_uid and invited_user_id = v_target and status = 'pending')
  then
    raise exception 'invite failed';
  end if;

  insert into public.dealer_driver_invites
    (owner_id, invited_user_id, driver_name, driver_phone, note, permission_level)
  values (v_uid, v_target, trim(p_driver_name), nullif(p_driver_phone, ''),
          nullif(p_note, ''), v_perm)
  returning id into v_id;
  return v_id;
end;
$function$;
revoke execute on function public.create_driver_invite(text,text,text,text,text)
  from public, anon;
grant execute on function public.create_driver_invite(text,text,text,text,text)
  to authenticated;
