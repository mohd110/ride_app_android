-- ============================================================
-- Add rider support to Wali Baba Foods schema
-- Run in Supabase SQL Editor (safe to re-run).
--
-- Your current profiles.role only allows 'customer' | 'restaurant'.
-- The rider app requires role = 'rider' or nothing works.
-- ============================================================

-- 1. Allow 'rider' in profiles.role
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role = ANY (ARRAY['customer'::text, 'restaurant'::text, 'rider'::text]));

-- 2. Riders can browse unclaimed orders + their own deliveries
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

-- 3. Riders can claim unclaimed orders or update their own
DROP POLICY IF EXISTS "orders_update_rider" ON public.orders;

CREATE POLICY "orders_update_rider"
  ON public.orders FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'rider'
    )
    AND (rider_id IS NULL OR rider_id = auth.uid())
  );

-- 4. Riders can read order line items (for pickup checklist)
DROP POLICY IF EXISTS "order_items_select_rider" ON public.order_items;

CREATE POLICY "order_items_select_rider"
  ON public.order_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'rider'
    )
  );

-- 5. Riders can upsert GPS while delivering
DROP POLICY IF EXISTS "rider_locations_insert_rider" ON public.rider_locations;
DROP POLICY IF EXISTS "rider_locations_update_rider" ON public.rider_locations;
DROP POLICY IF EXISTS "rider_locations_select_rider" ON public.rider_locations;

CREATE POLICY "rider_locations_select_rider"
  ON public.rider_locations FOR SELECT
  USING (rider_id = auth.uid());

CREATE POLICY "rider_locations_insert_rider"
  ON public.rider_locations FOR INSERT
  WITH CHECK (
    rider_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'rider'
    )
  );

CREATE POLICY "rider_locations_update_rider"
  ON public.rider_locations FOR UPDATE
  USING (rider_id = auth.uid());

-- 6. Ensure signup trigger supports rider metadata (if trigger exists)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_role text;
BEGIN
  user_role := COALESCE(NEW.raw_user_meta_data->>'role', 'customer');
  IF user_role NOT IN ('customer', 'restaurant', 'rider') THEN
    user_role := 'customer';
  END IF;

  INSERT INTO public.profiles (id, role, full_name, email, phone)
  VALUES (
    NEW.id,
    user_role,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.email, ''),
    NEW.phone
  )
  ON CONFLICT (id) DO UPDATE
  SET
    role = EXCLUDED.role,
    full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), profiles.full_name),
    email = COALESCE(NULLIF(EXCLUDED.email, ''), profiles.email);

  RETURN NEW;
END;
$$;

-- 7. Fix an existing rider auth user (edit email if needed)
-- UPDATE public.profiles SET role = 'rider', full_name = 'Test Rider'
-- WHERE email = 'rider@demo.com';

SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.profiles'::regclass AND conname = 'profiles_role_check';

SELECT policyname, tablename, cmd
FROM pg_policies
WHERE tablename IN ('orders', 'order_items', 'rider_locations')
ORDER BY tablename, policyname;
