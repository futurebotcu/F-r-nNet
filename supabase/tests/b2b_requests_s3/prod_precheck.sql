-- S3 migration ÖNCESİ production kontrolü (SALT-OKUNUR; MCP execute_sql).
-- Beklenen: tutarsız/çakışan kayıt yok; S3 nesneleri henüz yok.
select 'replies_total' k, count(*)::text v from public.b2b_quote_replies
union all select 'replies_inconsistent_insert', count(*)::text
  from public.b2b_quote_replies where status <> 'sent' and accepted = false
union all select 'requests_total', count(*)::text from public.b2b_quote_requests
union all select 'requests_bad_status', count(*)::text
  from public.b2b_quote_requests where status not in ('open','answered','closed','cancelled')
union all select 'requests_decided_but_reply_not_accepted', count(*)::text
  from public.b2b_quote_requests qr
  where qr.accepted_reply_id is not null
    and not exists (select 1 from public.b2b_quote_replies r where r.id = qr.accepted_reply_id and r.accepted)
union all select 'shops_verified', count(*)::text from public.b2b_supplier_shops where is_verified
union all select 'shops_has_contact_cols', (exists (select 1 from information_schema.columns
  where table_name = 'b2b_supplier_shops' and column_name = 'phone'))::text
union all select 's3_objects_present', (exists (select 1 from pg_proc where proname = 'b2b_my_replied_requests'))::text
union all select 'notif_dedupe_conflicts', count(*)::text from (
  select recipient_id, entity_id from public.notifications
  where type = 'b2b_quote_request_created' group by 1,2 having count(*) > 1) t
union all select 'accept_fn_has_for_update',
  (position('for update' in pg_get_functiondef('public.b2b_accept_quote_reply(uuid)'::regprocedure)) > 0)::text;
