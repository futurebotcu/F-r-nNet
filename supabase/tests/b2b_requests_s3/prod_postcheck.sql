-- S3 migration SONRASI production kontrolü (SALT-OKUNUR; MCP execute_sql).
-- Beklenen: tüm değerler true / beklenen sayı; grant matrisi doğru.
select 'fn_'||p.proname k, (p.prosecdef and pg_get_functiondef(p.oid) like '%search_path%')::text v
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in (
  'b2b_my_replied_requests','b2b_open_quote_requests_page','b2b_supplier_request_counts',
  'notify_b2b_quote_request_created','b2b_qr_guard_columns','b2b_replies_guard_insert',
  'b2b_shops_guard_columns','b2b_mark_request_answered','b2b_accept_quote_reply')
union all select 'trg_'||tgname, (tgenabled <> 'D')::text from pg_trigger where tgname in (
  'trg_notify_b2b_quote_request_created','trg_b2b_qr_guard_columns',
  'trg_b2b_replies_guard_insert','trg_b2b_shops_guard_columns','trg_b2b_reply_answered')
union all select 'idx_'||indexname, 'true' from pg_indexes where indexname in (
  'notifications_b2b_qr_dedupe_idx','idx_b2b_qr_open_cat_city',
  'idx_b2b_replies_shop_created','idx_b2b_shops_owner_active')
union all select 'accept_fn_has_for_update',
  (position('for update' in pg_get_functiondef('public.b2b_accept_quote_reply(uuid)'::regprocedure)) > 0)::text
union all select 'mark_answered_sets_guc',
  (position('b2b.reply_write' in pg_get_functiondef('public.b2b_mark_request_answered()'::regprocedure)) > 0)::text
union all select 'anon_cannot_exec_history',
  (not has_function_privilege('anon', 'public.b2b_my_replied_requests()', 'execute'))::text
union all select 'anon_cannot_exec_page',
  (not has_function_privilege('anon', 'public.b2b_open_quote_requests_page(text[],text[],boolean,integer,integer)', 'execute'))::text
union all select 'authenticated_can_exec_history',
  has_function_privilege('authenticated', 'public.b2b_my_replied_requests()', 'execute')::text
union all select 'authenticated_cannot_exec_guard',
  (not has_function_privilege('authenticated', 'public.b2b_qr_guard_columns()', 'execute'))::text
union all select 'contact_cols', (select count(*)::text from information_schema.columns
  where table_name = 'b2b_supplier_shops' and column_name in ('phone','whatsapp','website','address'));
