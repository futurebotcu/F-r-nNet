-- ============================================================
-- FırınNet — Reçete metadata sütunu
-- Tarih: 2026-05-13
-- Amaç: recipe_calculations tablosuna malzeme/adım/not/pişirme bilgisi
--       gibi zengin alanları taşıyacak tek bir jsonb sütun eklemek.
-- RLS  : Değişiklik yok (mevcut owner-only policy yeterli).
-- Trigger: Değişiklik yok (hesap alanlarını dolduran trigger korunur).
-- Geri dönüş: ALTER TABLE ... DROP COLUMN metadata;
-- ============================================================

alter table public.recipe_calculations
  add column if not exists metadata jsonb not null default '{}'::jsonb;

comment on column public.recipe_calculations.metadata is
  'FırınNet — reçete kütüphanesi için zengin alanlar (ingredients[], steps[], notes, bake, mediaHints, title, description, updatedAt). Schema serbest; uygulama tarafında doğrulanır.';
