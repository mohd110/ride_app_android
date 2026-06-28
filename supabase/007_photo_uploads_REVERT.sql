-- ============================================================
-- Reverts 007_photo_uploads.sql ONLY.
-- Drops exactly what that migration added — the 6 storage policies,
-- the 2 storage buckets (and any files in them), and the 2 columns.
-- Does not touch any other table, column, policy, function, or
-- trigger. Run in Supabase SQL Editor.
--
-- WARNING: this deletes any photo URLs/files already uploaded via
-- these features (including the test images from verification).
-- ============================================================

-- 1. Storage policies
DROP POLICY IF EXISTS "delivery_proofs_select_all" ON storage.objects;
DROP POLICY IF EXISTS "delivery_proofs_insert_rider" ON storage.objects;
DROP POLICY IF EXISTS "delivery_proofs_update_rider" ON storage.objects;
DROP POLICY IF EXISTS "rider_profiles_select_all" ON storage.objects;
DROP POLICY IF EXISTS "rider_profiles_insert_own" ON storage.objects;
DROP POLICY IF EXISTS "rider_profiles_update_own" ON storage.objects;

-- 2. Storage buckets — must delete contained objects first (FK constraint).
DELETE FROM storage.objects WHERE bucket_id IN ('delivery-proofs', 'rider-profiles');
DELETE FROM storage.buckets WHERE id IN ('delivery-proofs', 'rider-profiles');

-- 3. Columns
ALTER TABLE public.orders DROP COLUMN IF EXISTS delivery_proof_url;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS avatar_url;

-- 4. Verify everything is gone
SELECT id FROM storage.buckets WHERE id IN ('delivery-proofs', 'rider-profiles'); -- expect 0 rows
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'public'
  AND (table_name, column_name) IN (('orders', 'delivery_proof_url'), ('profiles', 'avatar_url')); -- expect 0 rows
SELECT policyname FROM pg_policies
WHERE tablename = 'objects' AND (policyname LIKE 'delivery_proofs%' OR policyname LIKE 'rider_profiles%'); -- expect 0 rows
