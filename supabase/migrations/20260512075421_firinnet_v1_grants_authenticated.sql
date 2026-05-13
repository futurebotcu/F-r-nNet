-- Migration: firinnet_v1_grants_authenticated
-- Version: 20260512075421
-- Source: applied to remote project sjeqwiqgwzagengdukye via MCP apply_migration on 2026-05-12
-- This file is a local mirror for source control. DO NOT re-apply to remote;
-- remote already records this version.

-- Authenticated role'e V1 tablolarinda CRUD grant.
-- RLS policy'leri "to authenticated" + owner_id = auth.uid() oldugundan,
-- bu grantlar kullaniciyi kendi verisi disina cikartmaz.
-- anon'a hicbir DML verilmez (default-deny).

grant usage on schema public to anon, authenticated;

grant select, insert, update, delete on
  public.profiles,
  public.bakeries,
  public.bakery_products,
  public.recipe_calculations,
  public.production_entries,
  public.dealers,
  public.dealer_deliveries,
  public.dealer_delivery_items,
  public.waste_entries
to authenticated;

-- Bundan sonra olusturulacak yeni V1 dosyalari icin de ayni default
alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;
