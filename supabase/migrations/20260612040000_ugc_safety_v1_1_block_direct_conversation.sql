-- =============================================================================
-- UGC Safety V1.1 — çift yön engel: find_or_create_direct_conversation.
--
-- V1'de block tek yönlü + görsel idi (blocker engellenenin içeriğini görmez).
-- Bu değişiklik conversation OLUŞTURMA sınırında çift-yön engel ekler:
-- iki kullanıcı arasında herhangi bir yönde block varsa yeni DM açılamaz.
-- - Engellenen kullanıcı, kendisini engelleyene mesaj BAŞLATAMAZ (incoming).
-- - Engelleyen de zaten UI'da engellenmiş; burada defense-in-depth.
-- Mevcut conversation'lara dokunulmaz (blocker client'ı zaten gizler).
--
-- Yalnız fonksiyon gövdesine TEK kısıt eklenir (additive/restrictive);
-- geri dönüş: bu bloğu kaldırıp önceki tanımı yeniden yükle.
-- =============================================================================

create or replace function public.find_or_create_direct_conversation(
  p_other_user uuid,
  p_context_type text default 'profile_direct'::text,
  p_context_id uuid default null::uuid
)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_me   uuid := auth.uid();
  v_conv uuid;
  v_lock_key bigint;
begin
  if v_me is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;
  if v_me = p_other_user then
    raise exception 'cannot direct-message self' using errcode = '22023';
  end if;
  -- UGC Safety V1.1 — çift yön engel: herhangi bir yönde block varsa reddet.
  if exists (
    select 1 from public.user_blocks
    where (blocker_id = p_other_user and blocked_user_id = v_me)
       or (blocker_id = v_me and blocked_user_id = p_other_user)
  ) then
    raise exception 'blocked between users' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles where id = p_other_user) then
    raise exception 'target profile not found' using errcode = '23503';
  end if;
  if p_context_type not in ('market_listing','profile_direct','job_offer','job_seek') then
    raise exception 'invalid context_type: %', p_context_type using errcode = '22023';
  end if;
  if p_context_type = 'profile_direct' and p_context_id is not null then
    raise exception 'profile_direct must not have context_id' using errcode = '22023';
  end if;
  if p_context_type in ('market_listing','job_offer','job_seek') and p_context_id is null then
    raise exception 'context_id required for %', p_context_type using errcode = '22023';
  end if;
  if p_context_type = 'market_listing' then
    if not exists (
      select 1 from public.market_listings ml
      where ml.id = p_context_id and ml.is_deleted = false and ml.owner_id = p_other_user
    ) then
      raise exception 'market_listing context invalid (not found, deleted, or owner mismatch)'
        using errcode = '23503';
    end if;
  end if;
  v_lock_key := hashtextextended(
    format('msg-direct:%s:%s:%s:%s',
      p_context_type,
      coalesce(p_context_id::text, '-'),
      least(v_me::text, p_other_user::text),
      greatest(v_me::text, p_other_user::text)
    ), 0
  );
  perform pg_advisory_xact_lock(v_lock_key);
  select c.id into v_conv
    from public.conversations c
   where c.type = 'direct'
     and c.context_type = p_context_type
     and coalesce(c.context_id, '00000000-0000-0000-0000-000000000000'::uuid)
         = coalesce(p_context_id, '00000000-0000-0000-0000-000000000000'::uuid)
     and exists (select 1 from public.conversation_participants p where p.conversation_id = c.id and p.user_id = v_me)
     and exists (select 1 from public.conversation_participants p where p.conversation_id = c.id and p.user_id = p_other_user)
   limit 1;
  if v_conv is not null then return v_conv; end if;
  insert into public.conversations (type, context_type, context_id, created_by)
  values ('direct', p_context_type, p_context_id, v_me)
  returning id into v_conv;
  insert into public.conversation_participants (conversation_id, user_id, role)
  values (v_conv, v_me, 'owner'), (v_conv, p_other_user, 'member');
  return v_conv;
end;
$function$;
