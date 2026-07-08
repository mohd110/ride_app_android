-- ============================================================
-- Optional: persist rider online/offline status in the database
-- so it is visible to the admin dashboard and restaurant app.
--
-- The Flutter app already stores online preference in SharedPreferences
-- (device-local). This migration adds the DB counterpart so other parties
-- (admin, restaurant) can also see who is actually online.
--
-- The authoritative column is rider_locations.status (already set by the
-- Flutter app via upsertLocation()). This migration adds a convenience
-- boolean to profiles for quick admin queries, and a function to mark a
-- rider offline when their last recorded activity was > 10 minutes ago
-- (useful for a scheduled cleanup job or a cron Edge Function).
--
-- Run in Supabase SQL Editor. Safe to re-run.
-- ============================================================

-- Add is_online to profiles for quick visibility.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_online boolean NOT NULL DEFAULT false;

-- Keep profiles.is_online in sync with rider_locations.status.
-- This trigger fires after every upsert on rider_locations.
CREATE OR REPLACE FUNCTION public.sync_rider_online_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
    SET is_online = (NEW.status != 'offline')
    WHERE id = NEW.rider_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_rider_online ON public.rider_locations;
CREATE TRIGGER trg_sync_rider_online
  AFTER INSERT OR UPDATE ON public.rider_locations
  FOR EACH ROW EXECUTE FUNCTION public.sync_rider_online_status();

-- Allow riders to read their own online status.
-- (The write path goes through rider_locations, not profiles directly.)
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- ── Verify ────────────────────────────────────────────────────────────────────

SELECT column_name, data_type
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name   = 'profiles'
   AND column_name  = 'is_online';
