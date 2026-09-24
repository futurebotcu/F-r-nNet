-- MİGRATION ÖNCESİ koşulur (yalnız replica modunda): eski backend'de free
-- ticari kullanıcının açtığı ilan 50 TL pending durumuna düşer — lansman
-- migration'ının bu durumu nasıl devraldığı 15_old_app_compat.sql'de test
-- edilir.
begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000007', true);
set local role authenticated;
insert into public.job_offer_posts (id, owner_id, title, role_title)
values ('00000000-0000-4000-8000-00000000aa07',
        '00000000-0000-4000-8000-000000000007', 'Eski app ilanı', 'Usta');
commit;

do $$
declare v_status text;
begin
  select fee_status into v_status from public.job_offer_posts
  where id = '00000000-0000-4000-8000-00000000aa07';
  if v_status <> 'pending' then
    raise exception
      '09: eski backend pending üretmedi (%) — ön koşul bozuk', v_status;
  end if;
  raise notice 'PASS 09 eski backend pending ilan seed';
end
$$;
