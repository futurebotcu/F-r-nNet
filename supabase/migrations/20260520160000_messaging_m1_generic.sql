-- FırınNet Messaging M1 — Generic conversations + participants + messages.
--
-- Donor pattern referansı: insideapp-srl/flutter_supabase_chat_core (Apache-2.0)
-- schema ve RLS şekli — komple SDK alınmadı, sadece desen okundu.
--
-- Hardening (kullanıcı direktifi):
--   * SECURITY DEFINER fonksiyonlarında `set search_path = public, pg_temp`
--   * is_in_conversation → stable + security definer + grant authenticated
--   * find_or_create_direct_conversation → profile var mı + me != other +
--     context_type whitelist + pg_advisory_xact_lock ile race-free dedupe
--   * context_type V1: market_listing / profile_direct / job_offer / job_seek
--   * Cross-field CHECK: profile_direct → context_id NULL; diğer 3 → NOT NULL
--   * messages V1: text + system; image V1.1'e ertelendi
--   * messages.content 1–4000 char
--   * conversation_participants.last_read_at → unread hesaplaması için
--   * Realtime publication idempotent (DO block, tekrar eklenmesin)
--   * RLS: conversations/participants/messages participant-only + sender-only
--
-- Apply YOK: bu dosya kullanıcıya gösteriliyor; onay sonrası MCP ile apply.


-- ─── 1. Tables ──────────────────────────────────────────────────────

create table if not exists public.conversations (
  id            uuid primary key default gen_random_uuid(),
  type          text not null check (type in ('direct','group')),
  context_type  text not null check (
    context_type in ('market_listing','profile_direct','job_offer','job_seek')
  ),
  context_id    uuid,
  title         text,
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  -- Cross-field invariant (Q5 hardening): profile_direct → context_id NULL;
  -- diğer 3 context_type için context_id zorunlu.
  constraint conversations_context_invariant check (
    (context_type = 'profile_direct' and context_id is null)
    or (context_type in ('market_listing','job_offer','job_seek')
        and context_id is not null)
  )
);

create table if not exists public.conversation_participants (
  conversation_id uuid not null
    references public.conversations(id) on delete cascade,
  user_id         uuid not null
    references public.profiles(id) on delete cascade,
  role            text not null default 'member'
    check (role in ('owner','admin','member')),
  joined_at       timestamptz not null default now(),
  last_read_at    timestamptz,
  primary key (conversation_id, user_id)
);

create table if not exists public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.conversations(id) on delete cascade,
  sender_id       uuid not null
    references public.profiles(id) on delete cascade,
  content         text not null check (
    length(content) between 1 and 4000
  ),
  message_type    text not null default 'text' check (
    message_type in ('text','system')  -- V1.1: 'image' eklenir
  ),
  attachments     jsonb,
  created_at      timestamptz not null default now(),
  edited_at       timestamptz,
  deleted_at      timestamptz
);


-- ─── 2. Indexes ─────────────────────────────────────────────────────

create index if not exists messages_conv_created_idx
  on public.messages (conversation_id, created_at desc)
  where deleted_at is null;

create index if not exists conv_updated_idx
  on public.conversations (updated_at desc);

create index if not exists participants_user_idx
  on public.conversation_participants (user_id);


-- ─── 3. Helper: is_in_conversation (Q2 hardening) ───────────────────
-- RLS recursion engellemek için. STABLE + SECURITY DEFINER + search_path.

create or replace function public.is_in_conversation(conv_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.conversation_participants
    where conversation_id = conv_id
      and user_id = auth.uid()
  );
$$;

revoke all on function public.is_in_conversation(uuid) from public;
grant execute on function public.is_in_conversation(uuid) to authenticated;


-- ─── 4. Bump trigger — conversations.updated_at = max(message.created_at) ──

create or replace function public.bump_conversation_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.conversations
     set updated_at = greatest(updated_at, new.created_at)
   where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists messages_bump_conv_updated_at on public.messages;
create trigger messages_bump_conv_updated_at
  after insert on public.messages
  for each row
  execute function public.bump_conversation_updated_at();


-- ─── 5. RPC: find_or_create_direct_conversation (Q3 hardening) ──────
-- Race-free dedupe: pg_advisory_xact_lock (LEAST/GREATEST user pair +
-- context_type + context_id) ile aynı iki kullanıcı + context için
-- tekrar conversation açılmaz.

create or replace function public.find_or_create_direct_conversation(
  p_other_user uuid,
  p_context_type text default 'profile_direct',
  p_context_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_me   uuid := auth.uid();
  v_conv uuid;
  v_lock_key bigint;
begin
  -- Auth check
  if v_me is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  -- Self DM blok
  if v_me = p_other_user then
    raise exception 'cannot direct-message self' using errcode = '22023';
  end if;

  -- Profile var mı? (orphan target engelle)
  if not exists (select 1 from public.profiles where id = p_other_user) then
    raise exception 'target profile not found' using errcode = '23503';
  end if;

  -- Context whitelist
  if p_context_type not in
       ('market_listing','profile_direct','job_offer','job_seek') then
    raise exception 'invalid context_type: %', p_context_type
      using errcode = '22023';
  end if;

  -- Cross-field invariant (DB CHECK ile ikinci hat: profile_direct → null,
  -- diğer 3 → not null).
  if p_context_type = 'profile_direct' and p_context_id is not null then
    raise exception 'profile_direct must not have context_id'
      using errcode = '22023';
  end if;
  if p_context_type in ('market_listing','job_offer','job_seek')
     and p_context_id is null then
    raise exception 'context_id required for %', p_context_type
      using errcode = '22023';
  end if;

  -- Hardening (kullanıcı direktifi #3): market_listing context için
  -- ek doğrulama. Kullanıcı rastgele UUID ile conversation açamasın.
  --   * market_listings içinde context_id var olmalı
  --   * is_deleted=false (silinmiş ilana DM başlatma)
  --   * p_other_user o ilanın owner_id'si olmalı (alıcı, sadece sahibi)
  -- (Self-DM zaten yukarıda v_me = p_other_user ile reddediliyor; ilan
  -- sahibi kendi ilanına DM başlatamaz.)
  if p_context_type = 'market_listing' then
    if not exists (
      select 1
        from public.market_listings ml
       where ml.id = p_context_id
         and ml.is_deleted = false
         and ml.owner_id = p_other_user
    ) then
      raise exception 'market_listing context invalid (not found, deleted, or owner mismatch)'
        using errcode = '23503';
    end if;
  end if;

  -- Race-free dedupe: aynı (least, greatest, context) için tek seferde
  -- bir transaction çalışsın. hashtext deterministic.
  v_lock_key := hashtextextended(
    format('msg-direct:%s:%s:%s:%s',
      p_context_type,
      coalesce(p_context_id::text, '-'),
      least(v_me::text, p_other_user::text),
      greatest(v_me::text, p_other_user::text)
    ),
    0
  );
  perform pg_advisory_xact_lock(v_lock_key);

  -- Mevcut conversation var mı?
  select c.id
    into v_conv
    from public.conversations c
   where c.type = 'direct'
     and c.context_type = p_context_type
     and coalesce(c.context_id, '00000000-0000-0000-0000-000000000000'::uuid)
         = coalesce(p_context_id, '00000000-0000-0000-0000-000000000000'::uuid)
     and exists (
       select 1 from public.conversation_participants p
        where p.conversation_id = c.id and p.user_id = v_me
     )
     and exists (
       select 1 from public.conversation_participants p
        where p.conversation_id = c.id and p.user_id = p_other_user
     )
   limit 1;

  if v_conv is not null then
    return v_conv;
  end if;

  -- Yoksa oluştur
  insert into public.conversations (type, context_type, context_id, created_by)
  values ('direct', p_context_type, p_context_id, v_me)
  returning id into v_conv;

  insert into public.conversation_participants (conversation_id, user_id, role)
  values
    (v_conv, v_me, 'owner'),
    (v_conv, p_other_user, 'member');

  return v_conv;
end;
$$;

revoke all on function public.find_or_create_direct_conversation(uuid,text,uuid) from public;
grant execute on function public.find_or_create_direct_conversation(uuid,text,uuid)
  to authenticated;


-- ─── 6. RPC: conversation_unread_count (Q7 hardening) ───────────────
-- last_read_at sonrası gelen, başkası gönderdiği mesajlar.

create or replace function public.conversation_unread_count(p_conversation_id uuid)
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select count(*)::int
    from public.messages m
    join public.conversation_participants p
      on p.conversation_id = m.conversation_id
     and p.user_id = auth.uid()
   where m.conversation_id = p_conversation_id
     and m.deleted_at is null
     and m.sender_id <> auth.uid()
     and (p.last_read_at is null or m.created_at > p.last_read_at);
$$;

revoke all on function public.conversation_unread_count(uuid) from public;
grant execute on function public.conversation_unread_count(uuid) to authenticated;


-- ─── 7. RPC: mark_conversation_read ─────────────────────────────────

create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;
  update public.conversation_participants
     set last_read_at = now()
   where conversation_id = p_conversation_id
     and user_id = auth.uid();
end;
$$;

revoke all on function public.mark_conversation_read(uuid) from public;
grant execute on function public.mark_conversation_read(uuid) to authenticated;


-- ─── 8. RLS — enable + policies ─────────────────────────────────────

alter table public.conversations              enable row level security;
alter table public.conversation_participants  enable row level security;
alter table public.messages                   enable row level security;

-- conversations
drop policy if exists conversations_select_participant on public.conversations;
create policy conversations_select_participant
  on public.conversations
  for select
  to authenticated
  using (public.is_in_conversation(id));

drop policy if exists conversations_insert_creator on public.conversations;
create policy conversations_insert_creator
  on public.conversations
  for insert
  to authenticated
  with check (created_by = auth.uid());

-- Hardening (kullanıcı direktifi #2): conversations UPDATE V1'de
-- kullanıcı kanalına KAPALI. Direct conversation'da title/context/type
-- değiştirilemez. `updated_at` zaten bump trigger ile yönetilir.
-- `last_read_at` ise participants tablosunda, ayrı policy ile sadece
-- self güncellenir. Group V1.2'de admin-only update policy eklenecek.
drop policy if exists conversations_update_participant on public.conversations;
-- (UPDATE policy kasten verilmedi; RLS default deny.)

-- participants
drop policy if exists participants_select_visible on public.conversation_participants;
create policy participants_select_visible
  on public.conversation_participants
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or public.is_in_conversation(conversation_id)
  );

-- INSERT participant: ya self ekleniyor ya conversation creator/owner ekliyor.
-- (Direct DM oluşturma find_or_create RPC üzerinden olduğu için bu insert
-- yolu aslında pratikte SECURITY DEFINER RPC ile çalışır; policy savunma
-- katmanı.)
drop policy if exists participants_insert_self_or_creator on public.conversation_participants;
create policy participants_insert_self_or_creator
  on public.conversation_participants
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    or exists (
      select 1 from public.conversations c
       where c.id = conversation_id
         and c.created_by = auth.uid()
    )
  );

drop policy if exists participants_delete_self on public.conversation_participants;
create policy participants_delete_self
  on public.conversation_participants
  for delete
  to authenticated
  using (user_id = auth.uid());

drop policy if exists participants_update_self on public.conversation_participants;
create policy participants_update_self
  on public.conversation_participants
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- messages
drop policy if exists messages_select_participant on public.messages;
create policy messages_select_participant
  on public.messages
  for select
  to authenticated
  using (
    deleted_at is null
    and public.is_in_conversation(conversation_id)
  );

drop policy if exists messages_insert_sender on public.messages;
-- Hardening (kullanıcı direktifi #1): client doğrudan 'system' message
-- atamasın. V1'de sadece 'text' insert açık. System mesaj gerekirse
-- ileride SECURITY DEFINER RPC ile oluşturulur (örn. seed "konuşma
-- <ilan> üzerinden başladı"). Sender yine kendi olmalı + conversation
-- participant.
create policy messages_insert_sender
  on public.messages
  for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and public.is_in_conversation(conversation_id)
    and message_type = 'text'
  );

drop policy if exists messages_update_sender on public.messages;
create policy messages_update_sender
  on public.messages
  for update
  to authenticated
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid());

drop policy if exists messages_delete_sender_soft on public.messages;
-- Soft-delete sender'a açık; hard delete RLS dışında değil.
-- update path ile deleted_at=now() set edilir.
-- (DELETE policy yok — owner hard delete'i blokla; cascade kalır.)


-- ─── 9. Realtime publication (Q8 hardening — idempotent) ────────────

do $$
begin
  if not exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'messages'
  ) then
    execute 'alter publication supabase_realtime add table public.messages';
  end if;
end$$;
