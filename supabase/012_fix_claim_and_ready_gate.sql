-- ============================================================
-- Fix claim_order_atomic: do NOT reset order status when a rider claims.
--
-- Bug in 011_single_session.sql: the original RPC wrote
--   SET rider_id = v_rider_id, status = 'accepted'
-- This destroyed the restaurant's status progress. If the restaurant had
-- already moved the order to 'preparing' or 'ready', claiming it silently
-- reset it back to 'accepted', forcing the admin to click through
-- Start Preparing → Mark Ready again after every claim.
--
-- Fix: only set rider_id. The restaurant's status progression is preserved.
-- The rider app now gates "Start Delivery" on status = 'ready', so the
-- restaurant's Mark Ready action is the real unlock signal.
--
-- Safe to re-run.
-- ============================================================

CREATE OR REPLACE FUNCTION public.claim_order_atomic(
  p_order_id uuid,
  p_device_id text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rider_id     uuid    := auth.uid();
  v_session_ok   boolean;
  v_rows_updated integer;
BEGIN
  IF v_rider_id IS NULL THEN
    RETURN 'session_expired';
  END IF;

  -- Verify this device still has an active session.
  SELECT is_active
    INTO v_session_ok
    FROM public.rider_sessions
   WHERE rider_id  = v_rider_id
     AND device_id = p_device_id;

  IF v_session_ok IS NULL OR NOT v_session_ok THEN
    RETURN 'session_expired';
  END IF;

  -- Atomic claim: only set rider_id. Do NOT change status.
  -- The restaurant's status progression (accepted → preparing → ready) must
  -- be preserved intact so the rider app can gate Start Delivery on 'ready'.
  UPDATE public.orders
     SET rider_id = v_rider_id
   WHERE id        = p_order_id
     AND rider_id IS NULL
     AND status   IN ('ready', 'preparing', 'accepted');

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    RETURN 'already_claimed';
  END IF;

  -- Refresh last_seen while we're here.
  UPDATE public.rider_sessions
     SET last_seen_at = now()
   WHERE rider_id  = v_rider_id
     AND device_id = p_device_id;

  RETURN 'success';
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_order_atomic(uuid, text) TO authenticated;

-- Verify
SELECT routine_name, routine_definition
  FROM information_schema.routines
 WHERE routine_schema = 'public'
   AND routine_name   = 'claim_order_atomic';
