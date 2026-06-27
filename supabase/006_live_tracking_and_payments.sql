-- ============================================================
-- Live rider tracking (online/idle/delivering, not just mid-order),
-- restaurant/admin read access to rider locations, a configurable
-- price-per-km, and automatic distance + payment calculation when
-- an order is marked delivered.
-- Run in Supabase SQL Editor. Safe to re-run.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. rider_locations: one row per rider, valid even with no active
--    order (was previously keyed to order_id, so an online-but-idle
--    rider had nowhere to report a position — this is why "all active
--    riders" could never show up anywhere).
-- ────────────────────────────────────────────────────────────

ALTER TABLE public.rider_locations
  ALTER COLUMN order_id DROP NOT NULL;

ALTER TABLE public.rider_locations
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'offline'
    CHECK (status IN ('online', 'idle', 'delivering', 'offline'));

-- Pre-existing test data has multiple rows per rider (one per order_id,
-- back when that was the key) — collapse to the single most-recent row
-- per rider so the new rider_id UNIQUE constraint below can be created.
DELETE FROM public.rider_locations
WHERE id IN (
  SELECT id FROM (
    SELECT id, ROW_NUMBER() OVER (
      PARTITION BY rider_id ORDER BY updated_at DESC, id DESC
    ) AS rn
    FROM public.rider_locations
  ) ranked
  WHERE rn > 1
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'rider_locations_rider_id_unique'
  ) THEN
    ALTER TABLE public.rider_locations
      ADD CONSTRAINT rider_locations_rider_id_unique UNIQUE (rider_id);
  END IF;
END $$;

-- order_id is no longer the upsert key (rider_id is) — drop the old
-- constraint so a rider switching orders doesn't collide on the new key.
ALTER TABLE public.rider_locations
  DROP CONSTRAINT IF EXISTS rider_locations_order_id_unique;

-- ────────────────────────────────────────────────────────────
-- 2. RLS: restaurant/admin can read every rider's live location.
--    (There was previously NO policy letting anyone but the rider
--    themselves read rider_locations — the admin dashboard could
--    never have shown rider positions, full stop.)
-- ────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "rider_locations_select_restaurant" ON public.rider_locations;
CREATE POLICY "rider_locations_select_restaurant"
  ON public.rider_locations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'restaurant'
    )
  );

-- Re-affirm rider insert/update policies now that order_id may be null.
DROP POLICY IF EXISTS "rider_locations_insert_rider" ON public.rider_locations;
CREATE POLICY "rider_locations_insert_rider"
  ON public.rider_locations FOR INSERT
  WITH CHECK (
    rider_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'rider'
    )
  );

DROP POLICY IF EXISTS "rider_locations_update_rider" ON public.rider_locations;
CREATE POLICY "rider_locations_update_rider"
  ON public.rider_locations FOR UPDATE
  USING (rider_id = auth.uid());

-- ────────────────────────────────────────────────────────────
-- 3. Configurable delivery rate — single row, admin-editable from
--    the restaurant dashboard, read by the rider app to show riders
--    the current rate.
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.delivery_settings (
  id int PRIMARY KEY DEFAULT 1,
  price_per_km numeric NOT NULL DEFAULT 10,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT delivery_settings_single_row CHECK (id = 1)
);

INSERT INTO public.delivery_settings (id, price_per_km)
  VALUES (1, 10)
  ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.delivery_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "delivery_settings_select_authenticated" ON public.delivery_settings;
CREATE POLICY "delivery_settings_select_authenticated"
  ON public.delivery_settings FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "delivery_settings_update_restaurant" ON public.delivery_settings;
CREATE POLICY "delivery_settings_update_restaurant"
  ON public.delivery_settings FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'restaurant'
    )
  );

-- ────────────────────────────────────────────────────────────
-- 4. Orders: delivery timing + computed distance/payment columns.
-- ────────────────────────────────────────────────────────────

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS picked_up_at timestamptz,
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz,
  ADD COLUMN IF NOT EXISTS delivery_distance_km numeric,
  ADD COLUMN IF NOT EXISTS price_per_km_used numeric,
  ADD COLUMN IF NOT EXISTS rider_payment numeric;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS delivery_duration interval
    GENERATED ALWAYS AS (delivered_at - picked_up_at) STORED;

-- ────────────────────────────────────────────────────────────
-- 5. Straight-line (haversine) distance in km. No PostGIS/extensions
--    needed. This is restaurant→customer distance — the actual
--    delivery leg — not however far the rider's GPS happened to
--    wander, which keeps payment fair and not gameable by detours.
--
--    Note: this is straight-line, not road distance. Swapping in real
--    road distance would mean calling Google's Distance Matrix API
--    (a separate billed API from Maps SDK/JS) from a Supabase Edge
--    Function — flagged as a possible follow-up, not done here.
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.haversine_km(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision
) RETURNS numeric
LANGUAGE sql IMMUTABLE
AS $$
  SELECT CASE
    WHEN lat1 IS NULL OR lng1 IS NULL OR lat2 IS NULL OR lng2 IS NULL THEN NULL
    ELSE (
      6371 * 2 * asin(sqrt(
        sin(radians(lat2 - lat1) / 2) ^ 2 +
        cos(radians(lat1)) * cos(radians(lat2)) *
        sin(radians(lng2 - lng1) / 2) ^ 2
      ))
    )::numeric
  END;
$$;

-- ────────────────────────────────────────────────────────────
-- 6. Trigger: on the UPDATE that sets status -> 'out_for_delivery',
--    stamp picked_up_at. On the UPDATE that sets status -> 'delivered',
--    stamp delivered_at and compute distance/payment using the rate
--    in effect at that moment. SECURITY DEFINER so this is correct
--    and tamper-resistant regardless of which client (rider app)
--    performs the plain status update — no app-side changes needed,
--    this fires automatically off the existing markOutForDelivery()/
--    markDelivered() calls already in the rider app.
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.finalize_delivery_payment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r_lat double precision;
  r_lng double precision;
  rate numeric;
  dist numeric;
BEGIN
  IF NEW.status = 'out_for_delivery' AND (OLD.status IS DISTINCT FROM 'out_for_delivery') THEN
    NEW.picked_up_at := COALESCE(NEW.picked_up_at, now());
  END IF;

  IF NEW.status = 'delivered' AND (OLD.status IS DISTINCT FROM 'delivered') THEN
    NEW.delivered_at := COALESCE(NEW.delivered_at, now());

    SELECT latitude, longitude INTO r_lat, r_lng
    FROM public.restaurants WHERE id = NEW.restaurant_id;

    dist := public.haversine_km(r_lat, r_lng, NEW.delivery_latitude, NEW.delivery_longitude);

    SELECT price_per_km INTO rate FROM public.delivery_settings WHERE id = 1;
    rate := COALESCE(rate, 10);

    NEW.delivery_distance_km := dist;
    NEW.price_per_km_used := rate;
    NEW.rider_payment := CASE WHEN dist IS NOT NULL THEN round(dist * rate, 2) ELSE NULL END;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_finalize_delivery_payment ON public.orders;
CREATE TRIGGER trg_finalize_delivery_payment
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.finalize_delivery_payment();

-- ────────────────────────────────────────────────────────────
-- 7. Verify
-- ────────────────────────────────────────────────────────────

SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'orders'
  AND column_name IN ('picked_up_at','delivered_at','delivery_distance_km','price_per_km_used','rider_payment','delivery_duration');

SELECT * FROM public.delivery_settings;

SELECT policyname, tablename, cmd FROM pg_policies
WHERE tablename IN ('rider_locations', 'delivery_settings')
ORDER BY tablename, policyname;
