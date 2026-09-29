-- =============================================================================
-- AKADEMİ TAM GERİ ALMA — service_role ile çalıştırılır.
-- Kapsam: 3 academy migration'ının (content_engine_v1, sources_seed_v1,
-- cron_v1) prod'a eklediği HER ŞEYİ kaldırır ve değiştirilen tek mevcut
-- fonksiyonu academy-öncesi tanıma döndürür. Kullanıcı verisine dokunmaz.
-- Sıra önemlidir. Acil durdurma için tam geri alma GEREKMEZ:
--   update public.app_runtime_config set value='false'::jsonb
--    where key='academy_enabled';
-- =============================================================================

-- 1) Cron işini kaldır (yoksa sessiz geç).
do $$ begin
  perform cron.unschedule('academy-worker-tick');
exception when others then null; end $$;
drop function if exists public.academy_cron_tick();

-- 2) Worker/motor RPC'leri — imza-bağımsız (tüm public.academy_* fonksiyonları;
--    academy_cron_tick yukarıda ayrıca düşürüldü, burada da kapsanır).
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'academy\_%' escape '\'
  loop
    execute 'drop function if exists ' || r.sig || ' cascade';
  end loop;
end $$;

-- 3) Tablolar (bağımlılık sırasıyla; hepsi academy'ye özel, kullanıcı
--    verisi içermez — humor etkileşim günlüğü dahil bilinçli silinir).
drop table if exists public.academy_humor_interactions cascade;
drop table if exists public.academy_engagement_prefs cascade;
drop table if exists public.academy_usage_daily cascade;
drop table if exists public.academy_jobs cascade;
drop table if exists public.academy_media cascade;
drop table if exists public.academy_drafts cascade;
drop table if exists public.academy_content_items cascade;
drop table if exists public.academy_bot_sources cascade;
drop table if exists public.academy_sources cascade;
drop table if exists public.academy_bot_settings cascade;
-- NOT: public.academy_bot_profiles TABLOSU DÜŞÜRÜLMEZ — PR #100 ile
-- academy'den ÖNCE prod'daydı; engine migration'ın ona eklediği kolonlar
-- (subtopics/is_humor/allow_dm/allow_self_comment/display_order) zararsızdır, istenirse:
--   alter table public.academy_bot_profiles
--     drop column if exists subtopics, drop column if exists is_humor,
--     drop column if exists allow_dm, drop column if exists allow_self_comment,
--     drop column if exists display_order;

-- 4) Config anahtarları.
delete from public.app_runtime_config where key in (
  'academy_enabled','academy_dry_run','academy_daily_post_target',
  'academy_daily_post_hard_cap','academy_bot_daily_post_cap',
  'academy_humor_daily_post_cap','academy_llm_model',
  'academy_daily_llm_request_budget','academy_daily_llm_token_budget',
  'academy_daily_fetch_budget','academy_humor_proactive_dm_enabled',
  'academy_max_active_sources'
);

-- 5) Bot hesapları (11 sabit UUID; feed_posts.owner_id bu botlara aitse
--    önce postlar silinmelidir — dry-run'da hiç post olmaz).
--    NOT: canlıda bot postları yayınlandıysa ve KORUNACAKSA bu bloğu
--    çalıştırmayın; yalnız academy_bot_profiles satırlarını bırakmak
--    güvenlidir.
delete from public.feed_posts where owner_id in (
  select id from public.academy_bot_profiles
);
delete from public.academy_bot_profiles
 where bot_key in ('ekmek_fermantasyon','un_tahil','firin_teknoloji',
   'hijyen_kalite','bilim_arge','turk_urunleri','sektor_gundemi',
   'pastacilik','isletme','ustalik_dunya','mizah');
delete from public.profiles p where p.id in (
  select ('ab010000-0000-4000-8000-0000000000'||lpad(g::text,2,'0'))::uuid
  from generate_series(1,11) g
) and p.is_bot = true;
delete from auth.users u where u.id in (
  select ('ab010000-0000-4000-8000-0000000000'||lpad(g::text,2,'0'))::uuid
  from generate_series(1,11) g
);

-- 6) Değiştirilen tek mevcut fonksiyonu geri yükle:
--    docs/academy/rollback/find_or_create_direct_conversation_prod_snapshot_20260929.sql
--    dosyasını AYNEN çalıştırın (academy-öncesi prod tanımının birebir
--    pg_get_functiondef çıktısıdır).

-- 7) Vault kayıtları (girildiyse):
--    select vault.remove_secret('academy_worker_url');  -- ad kayıt yoksa hata verebilir
--    select vault.remove_secret('academy_worker_key');
-- 8) Edge function: supabase functions delete academy-worker
