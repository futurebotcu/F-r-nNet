-- Tarif havuzu: RLS (usta kendi taslağı), onay yalnız service_role,
-- drafts.kind 'recipe' kabul, adapted için source_url zorunlu.
set role service_role;
do $$
declare u1 uuid; u2 uuid; rid uuid;
begin
  select id into u1 from public.profiles where is_bot = false
    order by created_at limit 1;
  select id into u2 from public.profiles where is_bot = false and id <> u1
    order by created_at limit 1;
  perform set_config('request.jwt.claim.sub', u1::text, true);
  set local role authenticated;
  -- R1: usta kendi taslağını ekler
  insert into public.academy_recipes (title, author_name, author_user_id,
    ingredients, oven_c, minutes)
  values ('Köy Ekmeği','Usta Test',u1,
    '[{"name":"Un","grams":1000},{"name":"Su","grams":680},{"name":"Tuz","grams":20}]'::jsonb,
    230, 40) returning id into rid;
  -- R2: başkası adına ekleyemez
  begin
    insert into public.academy_recipes (title, author_name, author_user_id)
    values ('Sahte','X',u2);
    raise exception 'R2 FAIL: baskasi adina eklendi';
  exception when insufficient_privilege or check_violation then null;
  end;
  -- R3: usta kendi tarifini approved YAPAMAZ (WITH CHECK 42501 fırlatır)
  begin
    update public.academy_recipes set status='approved' where id = rid;
    raise exception 'R3 FAIL: usta kendi tarifini onayladi';
  exception when insufficient_privilege then null;
  end;
  -- R4: baskasinin tarifini goremez
  perform set_config('request.jwt.claim.sub', u2::text, true);
  if exists (select 1 from public.academy_recipes where id = rid) then
    raise exception 'R4 FAIL: baskasinin tarifi gorundu';
  end if;
  reset role;
  set local role service_role;
  -- R5: service_role onaylar
  update public.academy_recipes set status='approved' where id = rid;
  if not exists (select 1 from public.academy_recipes
                 where id = rid and status='approved') then
    raise exception 'R5 FAIL: service_role onaylayamadi';
  end if;
  -- R6: adapted kaynak URL'siz eklenemez
  begin
    insert into public.academy_recipes (title, author_name, source_kind)
    values ('Uyarlama','Bot','adapted');
    raise exception 'R6 FAIL: adapted URLsiz kabul edildi';
  exception when check_violation then null;
  end;
  -- R7: drafts.kind 'recipe' kabul, uydurma tur RED
  insert into public.academy_drafts (bot_key, kind, title, body, publishable,
    idempotency_key)
  values ('turk_urunleri','recipe','Tarif Taslağı','Gövde',false,'r7-key');
  begin
    insert into public.academy_drafts (bot_key, kind, title, body,
      publishable, idempotency_key)
    values ('turk_urunleri','saçma','X','Y',false,'r7b-key');
    raise exception 'R7b FAIL: gecersiz kind kabul edildi';
  exception when check_violation then null;
  end;
  -- R8: config kapalı
  if public.app_config_bool('academy_recipe_enabled', true) then
    raise exception 'R8 FAIL: recipe_enabled=false degil';
  end if;
  raise notice 'PASS 10 tarif havuzu (RLS/onay/adapted/kind/config)';
end
$$;
reset role;
