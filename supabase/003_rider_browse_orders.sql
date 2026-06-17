-- ============================================================
-- Fix: riders cannot see unclaimed orders in Available Orders
-- Run in Supabase SQL Editor (safe to re-run).
--
-- Without this, a SELECT policy like "rider_id = auth.uid()" hides
-- every order that has not been claimed yet.
-- ============================================================

DROP POLICY IF EXISTS "orders_select_rider" ON public.orders;
DROP POLICY IF EXISTS "Riders read own orders" ON public.orders;

CREATE POLICY "orders_select_rider"
  ON public.orders FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'rider'
    )
  );

DROP POLICY IF EXISTS "order_items_select_rider" ON public.order_items;

CREATE POLICY "order_items_select_rider"
  ON public.order_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'rider'
    )
  );

SELECT policyname, cmd
FROM pg_policies
WHERE tablename IN ('orders', 'order_items')
ORDER BY tablename, policyname;
