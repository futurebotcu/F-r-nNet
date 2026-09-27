-- Bota DM kuralı: yalnız Mizah (allow_dm=true) DM alabilir; kullanıcı-kullanıcı
-- DM davranışı ve çift-yön engel BİREBİR korunur.
begin;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000001', true);
set local role authenticated;
do $$
declare
  v_u2 uuid := '00000000-0000-4000-8000-000000000002';
  v_akademi_bot uuid := 'ab010000-0000-4000-8000-000000000001';
  v_mizah uuid := 'ab010000-0000-4000-8000-000000000011';
  c1 uuid; c2 uuid;
begin
  -- Kullanıcı→kullanıcı: açılır ve idempotent.
  c1 := public.find_or_create_direct_conversation(v_u2);
  c2 := public.find_or_create_direct_conversation(v_u2);
  if c1 is null or c1 is distinct from c2 then
    raise exception 'D1a: user-user DM bozuldu';
  end if;

  -- Akademi botu (allow_dm=false): RED.
  begin
    perform public.find_or_create_direct_conversation(v_akademi_bot);
    raise exception 'D2a: akademi botuna DM açılabildi!';
  exception when insufficient_privilege then null;
  end;

  -- Mizah (allow_dm=true): açılır.
  c1 := public.find_or_create_direct_conversation(v_mizah);
  if c1 is null then raise exception 'D3a: mizah DM açılamadı'; end if;

  -- Self-DM hâlâ yasak.
  begin
    perform public.find_or_create_direct_conversation(
      '00000000-0000-4000-8000-000000000001');
    raise exception 'D4a: self DM açılabildi';
  exception when others then
    if sqlstate <> '22023' then raise; end if;
  end;
  raise notice 'PASS 06 DM kuralları (bot istisnası + mevcut davranış)';
end
$$;
commit;

-- Çift yön engel korunuyor: u2, u1'i engellerse u1 DM açamaz.
set role service_role;
insert into public.user_blocks (blocker_id, blocked_user_id) values
  ('00000000-0000-4000-8000-000000000002',
   '00000000-0000-4000-8000-000000000001')
on conflict do nothing;
reset role;

begin;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000001', true);
set local role authenticated;
do $$
begin
  begin
    perform public.find_or_create_direct_conversation(
      '00000000-0000-4000-8000-000000000002', 'job_offer',
      gen_random_uuid());
    raise exception 'D5a: engelliyken DM açılabildi';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS 06b çift-yön engel korunuyor';
end
$$;
commit;
set role service_role;
delete from public.user_blocks
  where blocker_id = '00000000-0000-4000-8000-000000000002';
reset role;
