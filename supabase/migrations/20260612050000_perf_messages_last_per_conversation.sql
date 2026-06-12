-- =============================================================================
-- Perf — listConversations N+1 fix: son mesaj per-conversation tek sorguda.
--
-- Önce: client her conversation için ayrı "son 1 mesaj" sorgusu yapıyordu
-- (50 konuşma = 50 sorgu). Bu fonksiyon DISTINCT ON ile hepsini TEK sorguda
-- döner. SECURITY INVOKER → messages RLS aynen uygulanır (kullanıcı yalnız
-- katılımcı olduğu konuşmaların son mesajını görür; privilege escalation YOK).
-- Read-only; geri dönüş: drop function.
-- =============================================================================

create or replace function public.messages_last_per_conversation(
  p_conv_ids uuid[]
)
returns table (
  conversation_id uuid,
  content text,
  sender_id uuid,
  created_at timestamptz
)
language sql
stable
security invoker
set search_path to 'public', 'pg_temp'
as $function$
  select distinct on (m.conversation_id)
    m.conversation_id, m.content, m.sender_id, m.created_at
  from public.messages m
  where m.conversation_id = any(p_conv_ids)
    and m.deleted_at is null
  order by m.conversation_id, m.created_at desc
$function$;

grant execute on function public.messages_last_per_conversation(uuid[]) to authenticated;
