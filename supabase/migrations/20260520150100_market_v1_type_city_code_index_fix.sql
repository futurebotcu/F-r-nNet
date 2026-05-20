-- FırınNet V1 Market M2 — controlled-data index fix.
--
-- 150000_market_v1_controlled_data_codes.sql `market_listings_type_city_idx`
-- index'ini oluştururken aynı isimde eski (M1'den) index zaten vardı
-- (`listing_type, city` text üstünde); `IF NOT EXISTS` yeni
-- `city_code` versiyonunu skip etti. Burada eski indexi drop + doğru
-- `city_code` üstünde rename ile yeniden oluştur.

drop index if exists public.market_listings_type_city_idx;

create index if not exists market_listings_type_city_code_idx
  on public.market_listings (listing_type, city_code)
  where is_deleted = false;
