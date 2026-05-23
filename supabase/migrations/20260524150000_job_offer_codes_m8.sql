-- =============================================================================
-- FırınNet Data Foundation M8 — Controlled job_offer_posts code fields.
-- =============================================================================
-- Hedef: işçi arayan ilanlarındaki kritik free-text alanları kontrollü
-- taxonomy code sistemine geçir. UI label gösterir; DB code yazar. Eski
-- label kolonları korunur (display fallback).
--
-- Etki:
--   * job_offer_posts.role_code        text nullable (yeni)
--   * job_offer_posts.shift_code       text nullable (yeni)
--   * job_offer_posts.experience_code  text nullable (yeni)
--   * 3 CHECK constraint:
--       role_code      → 17 profession code (FirinnetTaxonomy.professions
--                        keys ile birebir — M5 ile aynı)
--       shift_code     → gunduz / gece / vardiyali / esnek
--       experience_code → none / 0_2 / 3_5 / 5_plus
--   * Eski role_title (NOT NULL) + shift_type + experience_required text
--     kolonları KORUNUR (display fallback + backward compat).
--
-- Backfill YOK:
--   * Mevcut row sayısı düşük (M5 audit'inden 0 job_offer_posts).
--   * experience_required serbest text ("min 3 yıl") çok varyantlı; bracket
--     map'lemesi zor; null bırakmak daha güvenli.
--
-- Geri dönüş:
--   alter table public.job_offer_posts drop column role_code;
--   alter table public.job_offer_posts drop column shift_code;
--   alter table public.job_offer_posts drop column experience_code;
-- =============================================================================

-- ─── 1. Yeni nullable code kolonları ────────────────────────────────
alter table public.job_offer_posts
  add column if not exists role_code text,
  add column if not exists shift_code text,
  add column if not exists experience_code text;


-- ─── 2. CHECK constraints ───────────────────────────────────────────
-- role_code — 17 profession code (M5 profession taxonomy ile birebir)
alter table public.job_offer_posts
  drop constraint if exists job_offer_posts_role_code_chk;
alter table public.job_offer_posts
  add constraint job_offer_posts_role_code_chk
  check (
    role_code is null
    or role_code in (
      'usta_firinci','firin_sahibi','isletmeci','mayaci','hamurcu',
      'simitci','pogacaci','pasta_ustasi','pideci','cirak','kalfa',
      'uncu','susamci','toptanci','ekipman_satici','sofor','other'
    )
  );

-- shift_code — 4 entry; worker_profiles.shift_preference ile aynı taxonomy
alter table public.job_offer_posts
  drop constraint if exists job_offer_posts_shift_code_chk;
alter table public.job_offer_posts
  add constraint job_offer_posts_shift_code_chk
  check (
    shift_code is null
    or shift_code in ('gunduz', 'gece', 'vardiyali', 'esnek')
  );

-- experience_code — bracket: none/0_2/3_5/5_plus
alter table public.job_offer_posts
  drop constraint if exists job_offer_posts_experience_code_chk;
alter table public.job_offer_posts
  add constraint job_offer_posts_experience_code_chk
  check (
    experience_code is null
    or experience_code in ('none', '0_2', '3_5', '5_plus')
  );
