-- =============================================================================
-- FırınNet Listing Contact Phone Sprint — opsiyonel telefon paylaşımı.
-- =============================================================================
-- Hedef: kullanıcı kendi isteğiyle ilanına telefon ekleyebilsin; ilanı
-- görenler "Ara" butonuyla `tel:` link'i açabilsin. Telefon doğrulama
-- yok, OTP/SMS yok, kullanıcı rıza ile public gösterir.
--
-- Etki:
--   * job_offer_posts.contact_phone text nullable (yeni)
--   * job_seek_posts.contact_phone text nullable (yeni)
--   * job_seek_posts.contact_preference text not null default 'in_app'
--     (yeni — şu an kolon yok; default 'in_app' mevcut satırları korur)
--   * 2 CHECK constraint: contact_preference IN ('in_app','phone','whatsapp')
--     job_offer_posts + job_seek_posts için
--
-- Market'e dokunmuyoruz:
--   * market_listings.contact_phone/contact_whatsapp/contact_preference
--     zaten mevcut ve `MarketplaceContactPanel` ile çalışıyor.
--   * market_listings.contact_preference için DB CHECK eklemiyoruz (mevcut
--     satırları riske atmamak için; "Market'e dokunma" kuralı).
--
-- Geri dönüş:
--   alter table public.job_offer_posts  drop column contact_phone;
--   alter table public.job_seek_posts   drop column contact_phone;
--   alter table public.job_seek_posts   drop column contact_preference;
-- =============================================================================

-- ─── 1. Yeni nullable contact_phone kolonları ───────────────────────
alter table public.job_offer_posts
  add column if not exists contact_phone text;

alter table public.job_seek_posts
  add column if not exists contact_phone text;

-- ─── 2. job_seek_posts.contact_preference (yeni) ────────────────────
-- Default 'in_app' — mevcut row'lar otomatik dolacak; UI default zaten
-- "uygulama içi mesaj".
alter table public.job_seek_posts
  add column if not exists contact_preference text not null default 'in_app';


-- ─── 3. CHECK constraints — contact_preference allowed values ───────
alter table public.job_offer_posts
  drop constraint if exists job_offer_posts_contact_preference_chk;
alter table public.job_offer_posts
  add constraint job_offer_posts_contact_preference_chk
  check (contact_preference in ('in_app', 'phone', 'whatsapp'));

alter table public.job_seek_posts
  drop constraint if exists job_seek_posts_contact_preference_chk;
alter table public.job_seek_posts
  add constraint job_seek_posts_contact_preference_chk
  check (contact_preference in ('in_app', 'phone', 'whatsapp'));
