-- Migration: job_messaging_v1
-- Version: 20260516200000
-- Applied to remote: 2026-05-16 via MCP apply_migration.
--
-- FırınNet — Job messaging V1 (job_conversations + job_messages).
-- Bireysel ↔ Ticari/Toptancı arası 1-1 sohbet; job_offer_posts veya
-- job_seek_posts'a bağlı; sadece participantlar görür/yazar.

create table public.job_conversations (
  id uuid primary key default gen_random_uuid(),
  related_type text not null
    check (related_type in ('job_offer','job_seek')),
  job_offer_id uuid references public.job_offer_posts(id) on delete cascade,
  job_seek_post_id uuid references public.job_seek_posts(id) on delete cascade,
  initiator_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'open'
    check (status in ('open','closed')),
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint job_conversations_distinct_parties
    check (initiator_id <> recipient_id),
  constraint job_conversations_target_consistency check (
    (related_type = 'job_offer'
      and job_offer_id is not null and job_seek_post_id is null)
    or
    (related_type = 'job_seek'
      and job_seek_post_id is not null and job_offer_id is null)
  )
);

create unique index uq_job_conversations_offer_initiator
  on public.job_conversations (job_offer_id, initiator_id)
  where job_offer_id is not null;
create unique index uq_job_conversations_seek_initiator
  on public.job_conversations (job_seek_post_id, initiator_id)
  where job_seek_post_id is not null;

create index idx_job_conversations_recipient_last
  on public.job_conversations (recipient_id, last_message_at desc nulls last);
create index idx_job_conversations_initiator_last
  on public.job_conversations (initiator_id, last_message_at desc nulls last);

create trigger trg_job_conversations_updated_at
  before update on public.job_conversations
  for each row execute function public.set_updated_at();

create table public.job_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.job_conversations(id) on delete cascade,
  sender_id uuid not null
    references public.profiles(id) on delete cascade,
  body text not null check (length(btrim(body)) between 1 and 1000),
  is_deleted boolean not null default false,
  created_at timestamptz not null default now()
);

create index idx_job_messages_conversation_created
  on public.job_messages (conversation_id, created_at);

create or replace function public.bump_job_conversation_last_message()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.job_conversations
     set last_message_at = new.created_at,
         updated_at = now()
   where id = new.conversation_id;
  return new;
end; $$;
revoke execute on function public.bump_job_conversation_last_message() from public;
revoke execute on function public.bump_job_conversation_last_message() from anon;
revoke execute on function public.bump_job_conversation_last_message() from authenticated;

create trigger trg_job_messages_bump_conversation
  after insert on public.job_messages
  for each row execute function public.bump_job_conversation_last_message();

alter table public.job_conversations enable row level security;
alter table public.job_messages      enable row level security;

create policy job_conversations_select_participant on public.job_conversations
  for select to authenticated
  using (initiator_id = auth.uid() or recipient_id = auth.uid());

create policy job_conversations_insert_initiator on public.job_conversations
  for insert to authenticated
  with check (
    initiator_id = auth.uid()
    and recipient_id <> auth.uid()
    and (
      (related_type = 'job_offer' and exists (
        select 1 from public.job_offer_posts p
         where p.id = job_offer_id
           and p.owner_id = recipient_id
           and p.is_active = true
      ))
      or
      (related_type = 'job_seek' and exists (
        select 1 from public.job_seek_posts p
         where p.id = job_seek_post_id
           and p.owner_id = recipient_id
           and p.is_active = true
      ))
    )
  );

create policy job_conversations_update_participant on public.job_conversations
  for update to authenticated
  using (initiator_id = auth.uid() or recipient_id = auth.uid())
  with check (initiator_id = auth.uid() or recipient_id = auth.uid());

grant select, insert, update on public.job_conversations to authenticated;

create policy job_messages_select_participant on public.job_messages
  for select to authenticated
  using (
    exists (
      select 1 from public.job_conversations c
       where c.id = job_messages.conversation_id
         and (c.initiator_id = auth.uid() or c.recipient_id = auth.uid())
    )
  );

create policy job_messages_insert_sender on public.job_messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.job_conversations c
       where c.id = conversation_id
         and (c.initiator_id = auth.uid() or c.recipient_id = auth.uid())
         and c.status = 'open'
    )
  );

create policy job_messages_update_owner_softdelete on public.job_messages
  for update to authenticated
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid());

grant select, insert, update on public.job_messages to authenticated;

comment on table public.job_conversations is
  'FırınNet — 1-1 sohbet kanalı. related_type=job_offer veya job_seek; '
  'participantlar sadece görür/yazar; RLS açık; initiator post sahibinin '
  'farkında olduğundan emin.';
comment on table public.job_messages is
  'FırınNet — Sohbet mesajları. sender = auth.uid(); soft delete sender; '
  'hard delete yalnız CASCADE.';
