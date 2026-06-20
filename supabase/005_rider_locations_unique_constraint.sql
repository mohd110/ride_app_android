-- ============================================================
-- One location row per order
-- Run in Supabase SQL Editor (safe to re-run).
--
-- lib/services/order_service.dart upserts into rider_locations
-- with onConflict: 'order_id' every 5 seconds while a rider is
-- out for delivery. Postgres rejects that upsert with "no unique
-- or exclusion constraint matching the ON CONFLICT specification"
-- until this constraint exists.
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'rider_locations_order_id_unique'
  ) THEN
    ALTER TABLE public.rider_locations
      ADD CONSTRAINT rider_locations_order_id_unique UNIQUE (order_id);
  END IF;
END $$;

SELECT conname FROM pg_constraint WHERE conname = 'rider_locations_order_id_unique';
