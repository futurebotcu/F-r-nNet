-- Kaynak sicili seed: aday sayısı, idempotency, bot eşleştirme dağılımı.
set role service_role;
do $$
declare n int; nmap int;
begin
  select count(*) into n from public.academy_sources;
  if n < 40 then
    raise exception 'S1a: aday kaynak % (>=40 bekleniyordu)', n;
  end if;
  -- Hepsi candidate başlar; hiçbiri kendiliğinden active olamaz.
  if exists (select 1 from public.academy_sources
             where status <> 'candidate') then
    raise exception 'S1b: seed active/diğer status üretti';
  end if;
  -- Slug tekil (2. uygulama kopya üretmedi — runner iki kez uyguladı).
  select count(*) - count(distinct slug) into n from public.academy_sources;
  if n <> 0 then raise exception 'S1c: slug kopyası var'; end if;

  -- Bot eşleştirmeleri konu üzerinden kuruldu; mizah botuna kaynak YOK.
  select count(*) into nmap from public.academy_bot_sources;
  if nmap < 50 then
    raise exception 'S2a: eşleştirme sayısı % (>=50)', nmap;
  end if;
  if exists (select 1 from public.academy_bot_sources
             where bot_key = 'mizah') then
    raise exception 'S2b: mizah botuna kaynak eşleşmiş';
  end if;
  -- Her akademi botunun en az 2 kaynağı var.
  if exists (
    select b.bot_key from public.academy_bot_profiles b
    left join public.academy_bot_sources m on m.bot_key = b.bot_key
    where not b.is_humor
    group by b.bot_key having count(m.source_id) < 2
  ) then
    raise exception 'S2c: kaynaksız/az kaynaklı akademi botu var';
  end if;
  raise notice 'PASS 07 kaynak sicili seed (% kaynak, % eşleştirme)',
    (select count(*) from public.academy_sources), nmap;
end
$$;
reset role;
