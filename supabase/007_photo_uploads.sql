-- ============================================================
-- Real photo uploads: delivery proof + rider profile photo.
-- Both features existed only as fake UI (a hardcoded local asset
-- swapped in on tap) — nothing was ever actually uploaded anywhere.
-- This adds the storage buckets, columns, and policies needed for
-- the real thing. Run in Supabase SQL Editor. Safe to re-run.
-- ============================================================

-- 1. Columns to hold the uploaded public URLs.
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS delivery_proof_url text;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS avatar_url text;

-- 2. Storage buckets (public read — these are delivery-proof photos and
-- profile pictures, not sensitive documents, so public read is correct;
-- write access is restricted by the storage policies below).
INSERT INTO storage.buckets (id, name, public)
VALUES ('delivery-proofs', 'delivery-proofs', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('rider-profiles', 'rider-profiles', true)
ON CONFLICT (id) DO NOTHING;

-- 3. Storage policies.
-- delivery-proofs: any authenticated user can view (customer/restaurant/
-- rider all need to see it); only the assigned rider can upload, and only
-- for their own order (path must start with their own order's id, enforced
-- by uploading to "<order_id>.jpg" and checking that order belongs to them).
DROP POLICY IF EXISTS "delivery_proofs_select_all" ON storage.objects;
CREATE POLICY "delivery_proofs_select_all"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'delivery-proofs');

DROP POLICY IF EXISTS "delivery_proofs_insert_rider" ON storage.objects;
CREATE POLICY "delivery_proofs_insert_rider"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'delivery-proofs'
    AND EXISTS (
      SELECT 1 FROM public.orders
      WHERE id::text = split_part(name, '.', 1)
        AND rider_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "delivery_proofs_update_rider" ON storage.objects;
CREATE POLICY "delivery_proofs_update_rider"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'delivery-proofs'
    AND EXISTS (
      SELECT 1 FROM public.orders
      WHERE id::text = split_part(name, '.', 1)
        AND rider_id = auth.uid()
    )
  );

-- rider-profiles: public read (shown to restaurant/customer/admin too);
-- a rider can only upload/replace their own photo, named "<rider_id>.jpg".
DROP POLICY IF EXISTS "rider_profiles_select_all" ON storage.objects;
CREATE POLICY "rider_profiles_select_all"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'rider-profiles');

DROP POLICY IF EXISTS "rider_profiles_insert_own" ON storage.objects;
CREATE POLICY "rider_profiles_insert_own"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'rider-profiles'
    AND split_part(name, '.', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS "rider_profiles_update_own" ON storage.objects;
CREATE POLICY "rider_profiles_update_own"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'rider-profiles'
    AND split_part(name, '.', 1) = auth.uid()::text
  );

-- 4. Verify
SELECT id, name, public FROM storage.buckets WHERE id IN ('delivery-proofs', 'rider-profiles');
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'public'
  AND (table_name, column_name) IN (('orders', 'delivery_proof_url'), ('profiles', 'avatar_url'));
SELECT policyname FROM pg_policies
WHERE tablename = 'objects' AND policyname LIKE 'delivery_proofs%' OR policyname LIKE 'rider_profiles%';
