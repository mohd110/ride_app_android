-- ============================================================
-- 1. Rider profile fields — vehicle, license, address, emergency contact.
--
-- profiles currently only has: id, role, full_name, email, phone,
-- created_at, avatar_url, is_online. None of the fields below exist yet.
-- No new RLS policy is needed — "profiles_update_own" (001_init.sql,
-- local_delivery_app) already grants USING (auth.uid() = id) at the ROW
-- level, which covers any column, including these new ones.
--
-- Run in Supabase SQL Editor. Safe to re-run.
-- ============================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS vehicle_type              TEXT,
  ADD COLUMN IF NOT EXISTS vehicle_model              TEXT,
  ADD COLUMN IF NOT EXISTS vehicle_registration_number TEXT,
  ADD COLUMN IF NOT EXISTS license_number             TEXT,
  ADD COLUMN IF NOT EXISTS address                    TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_name      TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_phone     TEXT;

COMMENT ON COLUMN public.profiles.vehicle_type IS 'e.g. Bike, Scooter, Bicycle — free text, rider-entered';
COMMENT ON COLUMN public.profiles.vehicle_registration_number IS 'Number plate';

-- ============================================================
-- 2. Company info — single settings row for the rider app's
--    "Company Information" / About / Support / Legal section.
--
-- Same singleton pattern as delivery_settings (006): fixed id=1 row,
-- publicly readable (company name/support contact/hours are shown on the
-- rider app's pre-login "Contact Hub Manager" screen, so this can't be
-- gated behind auth), editable only by restaurant/admin accounts (there's
-- no separate "admin" role in this schema — role is customer/restaurant/
-- rider — so restaurant is used the same way delivery_settings_update_restaurant
-- does).
-- ============================================================

CREATE TABLE IF NOT EXISTS public.company_info (
  id                  int PRIMARY KEY DEFAULT 1,
  company_name        TEXT NOT NULL DEFAULT '',
  company_logo_url    TEXT,
  support_email       TEXT,
  support_phone       TEXT,
  office_address      TEXT,
  working_hours       TEXT,
  -- Either a full URL to a hosted page or inline plain text — the app
  -- decides how to render based on whether the value looks like a URL.
  terms_and_conditions TEXT,
  privacy_policy       TEXT,
  about_us             TEXT,
  -- Minimum/recommended app version for a future "please update" prompt.
  -- The rider app's OWN running version still comes from package_info_plus
  -- client-side — this is not a substitute for that, it's what the app
  -- compares itself against.
  min_supported_app_version TEXT,
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT company_info_single_row CHECK (id = 1)
);

INSERT INTO public.company_info (id, company_name)
  VALUES (1, 'Wali Baba Foods')
  ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.company_info ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "company_info_select_authenticated" ON public.company_info;
DROP POLICY IF EXISTS "company_info_select_public" ON public.company_info;
CREATE POLICY "company_info_select_public"
  ON public.company_info FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "company_info_update_restaurant" ON public.company_info;
CREATE POLICY "company_info_update_restaurant"
  ON public.company_info FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'restaurant'
    )
  );

-- ── Verify ────────────────────────────────────────────────────────────────────

SELECT column_name, data_type
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name   = 'profiles'
   AND column_name IN (
     'vehicle_type', 'vehicle_model', 'vehicle_registration_number',
     'license_number', 'address', 'emergency_contact_name', 'emergency_contact_phone'
   );

SELECT * FROM public.company_info;
