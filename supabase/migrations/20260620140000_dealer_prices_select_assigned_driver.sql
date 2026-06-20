-- fix/dealer-prices-driver-select-rls
-- BUG: dealer_prices'ta assigned-driver SELECT policy yok → atanmış şoför
-- (yarı/tam) bayinin fiyatlarını okuyamıyor (teslimat formu otomatik fiyatı
-- boş kalır; full şoför driver_set_price ile yazsa bile geri göremez). Diğer
-- bayi tablolarında (dealers / dealer_transactions / dealer_deliveries /
-- dealer_delivery_items) bu policy zaten var; yalnız dealer_prices'ta eksik.
--
-- FIX: yalnızca SELECT (okuma) policy ekle. Yazma RLS'i (insert/update/delete
-- owner-only) DEĞİŞMEZ; predicate dealer_transactions_select_assigned_driver
-- ile birebir aynı desen (atanmış + aktif şoför).
-- NOT: MCP apply_migration ile uygulanan migration'ın izlenebilir kopyasıdır.

CREATE POLICY dealer_prices_select_assigned_driver
ON public.dealer_prices
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.dealer_driver_assignments a
    JOIN public.dealer_drivers d ON d.id = a.driver_id
    WHERE a.dealer_id = dealer_prices.dealer_id
      AND d.driver_user_id = auth.uid()
      AND d.is_active
  )
);
