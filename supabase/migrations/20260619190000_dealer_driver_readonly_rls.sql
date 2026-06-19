-- Bayi Yönetimi — Şoförler · Sprint 3: ŞOFÖR READ-ONLY ERİŞİMİ (additive SELECT RLS).
--
-- Şoför (dealer_drivers.driver_user_id = auth.uid()), yalnızca kendisine atanmış
-- bayileri ve o bayilerin mevcut hareketlerini OKUYABİLİR.
--
-- Prensip:
--   * Yalnız ADDITIVE SELECT politikaları; mevcut owner-only politikalar
--     DEĞİŞTİRİLMEZ/SİLİNMEZ (permissive politikalar OR'lanır → patron erişimi aynen sürer).
--   * Şoföre INSERT/UPDATE/DELETE politikası YOK → şoför yazamaz.
--   * Okuma yetkisi ATAMA (dealer_driver_assignments) üzerinden gelir;
--     transaction.driver_id dolu olması GEREKMEZ (Sprint 4'e kadar şoför yazmıyor).
--   * "Tek defter" korunur: şoför patronun (owner_id) satırlarını yalnız atama
--     kapsamında görür; başka patron / başka şoför / atanmamış bayi GÖRÜNMEZ.
-- (Production'a MCP apply_migration ile uygulanır; repo mirror.)

-- ── dealer_drivers: şoför kendi kaydını okur (driver-ness tespiti için) ──
drop policy if exists dealer_drivers_select_self on public.dealer_drivers;
create policy dealer_drivers_select_self on public.dealer_drivers
  for select to authenticated
  using (driver_user_id = auth.uid());

-- ── dealer_driver_assignments: şoför kendi atamalarını okur ──
drop policy if exists dealer_driver_assignments_select_self on public.dealer_driver_assignments;
create policy dealer_driver_assignments_select_self on public.dealer_driver_assignments
  for select to authenticated
  using (
    driver_id in (
      select id from public.dealer_drivers where driver_user_id = auth.uid()
    )
  );

-- ── dealers: şoför kendine atanmış bayiyi okur ──
drop policy if exists dealers_select_assigned_driver on public.dealers;
create policy dealers_select_assigned_driver on public.dealers
  for select to authenticated
  using (
    exists (
      select 1
      from public.dealer_driver_assignments a
      join public.dealer_drivers d on d.id = a.driver_id
      where a.dealer_id = dealers.id
        and d.driver_user_id = auth.uid()
        and d.is_active
    )
  );

-- ── dealer_transactions: atanmış bayinin hareketleri (payment/return/adjustment) ──
drop policy if exists dealer_transactions_select_assigned_driver on public.dealer_transactions;
create policy dealer_transactions_select_assigned_driver on public.dealer_transactions
  for select to authenticated
  using (
    exists (
      select 1
      from public.dealer_driver_assignments a
      join public.dealer_drivers d on d.id = a.driver_id
      where a.dealer_id = dealer_transactions.dealer_id
        and d.driver_user_id = auth.uid()
        and d.is_active
    )
  );

-- ── dealer_deliveries: atanmış bayinin teslimat başlıkları ──
drop policy if exists dealer_deliveries_select_assigned_driver on public.dealer_deliveries;
create policy dealer_deliveries_select_assigned_driver on public.dealer_deliveries
  for select to authenticated
  using (
    exists (
      select 1
      from public.dealer_driver_assignments a
      join public.dealer_drivers d on d.id = a.driver_id
      where a.dealer_id = dealer_deliveries.dealer_id
        and d.driver_user_id = auth.uid()
        and d.is_active
    )
  );

-- ── dealer_delivery_items: teslimat satırları (delivery → dealer üzerinden) ──
drop policy if exists dealer_delivery_items_select_assigned_driver on public.dealer_delivery_items;
create policy dealer_delivery_items_select_assigned_driver on public.dealer_delivery_items
  for select to authenticated
  using (
    exists (
      select 1
      from public.dealer_deliveries dd
      join public.dealer_driver_assignments a on a.dealer_id = dd.dealer_id
      join public.dealer_drivers d on d.id = a.driver_id
      where dd.id = dealer_delivery_items.delivery_id
        and d.driver_user_id = auth.uid()
        and d.is_active
    )
  );
