-- ============================================================
-- Single active session per rider + race-condition-safe order claiming.
--
-- Problem 1 — Multiple active devices:
--   A rider who logs in on a second phone kept receiving orders on the first
--   phone too. Nothing invalidated the previous device's Realtime/service.
--
-- Problem 2 — Race-condition order claims:
--   Two riders (or the same rider on two devices) could both see an order as
--   available and both send UPDATE ... WHERE rider_id IS NULL. Postgres
--   serialises these at the row level, but the existing Flutter code checked
--   `(claimed as List).isEmpty` AFTER the UPDATE, which is unreliable under
--   concurrent writes. The new RPC returns an explicit result code.
--
-- Run in Supabase SQL Editor. Safe to re-run.
-- ============================================================

-- ── 1. rider_sessions ───────────────────────────────────────────────────────
-- One row per (rider, device). Only one row per rider may have is_active=true.
-- The register_rider_session() RPC enforces this transactionally.
-- Riders subscribe to this table via Realtime: when their device's row flips
-- to is_active=false, they force-logout immediately.

CREATE TABLE IF NOT EXISTS public.rider_sessions (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id      uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  device_id     text        NOT NULL,
  is_active     boolean     NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  last_seen_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (rider_id, device_id)
);

ALTER TABLE public.rider_sessions ENABLE ROW LEVEL SECURITY;

-- Riders can read their own sessions (used by the Realtime subscription that
-- detects when another device has taken over).
DROP POLICY IF EXISTS "rider_sessions_select_own" ON public.rider_sessions;
CREATE POLICY "rider_sessions_select_own"
  ON public.rider_sessions FOR SELECT
  USING (auth.uid() = rider_id);

-- ── 2. register_rider_session() RPC ─────────────────────────────────────────
-- Called by the Flutter app immediately after a successful login.
-- Deactivates every OTHER session for this rider (other devices will detect
-- the change via their Realtime subscription and auto-logout), then upserts
-- this device as the sole active session.
--
-- Uses SECURITY DEFINER so it can UPDATE rows that belong to the same rider
-- without requiring an explicit UPDATE policy on the table.

CREATE OR REPLACE FUNCTION public.register_rider_session(p_device_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rider_id uuid := auth.uid();
BEGIN
  IF v_rider_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Mark all other devices as inactive.  The Realtime UPDATE event will reach
  -- those devices within < 1 second and trigger their force-logout path.
  UPDATE public.rider_sessions
     SET is_active    = false,
         last_seen_at = now()
   WHERE rider_id  = v_rider_id
     AND device_id != p_device_id;

  -- Upsert this device as the new active session.
  INSERT INTO public.rider_sessions (rider_id, device_id, is_active, last_seen_at)
    VALUES (v_rider_id, p_device_id, true, now())
    ON CONFLICT (rider_id, device_id)
    DO UPDATE SET is_active    = true,
                  last_seen_at = now();
END;
$$;

GRANT EXECUTE ON FUNCTION public.register_rider_session(text) TO authenticated;

-- ── 3. claim_order_atomic() RPC ──────────────────────────────────────────────
-- Returns one of three result codes:
--   'success'         — this rider successfully claimed the order
--   'already_claimed' — another rider (or device) got there first
--   'session_expired' — this device no longer has an active session;
--                       the app should force-logout
--
-- The UPDATE is inherently atomic in Postgres: concurrent callers all try to
-- UPDATE the same row; only the first one finds rider_id IS NULL and succeeds.
-- Subsequent callers find rider_id already set and get ROW_COUNT = 0.
--
-- Using SECURITY DEFINER both to bypass the caller's RLS UPDATE permission
-- on orders (which may not exist) and to read rider_sessions without a
-- separate SELECT policy.

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

  -- Verify this specific device has an active session before allowing it
  -- to claim.  This prevents a force-logged-out device from still claiming
  -- orders after it has been superseded by another phone.
  SELECT is_active
    INTO v_session_ok
    FROM public.rider_sessions
   WHERE rider_id  = v_rider_id
     AND device_id = p_device_id;

  IF v_session_ok IS NULL OR NOT v_session_ok THEN
    RETURN 'session_expired';
  END IF;

  -- Atomic claim: only succeeds if no rider_id is set yet on the order.
  UPDATE public.orders
     SET rider_id = v_rider_id,
         status   = 'accepted'
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

-- ── 4. Verify ────────────────────────────────────────────────────────────────

SELECT table_name
  FROM information_schema.tables
 WHERE table_schema = 'public'
   AND table_name   = 'rider_sessions';

SELECT routine_name
  FROM information_schema.routines
 WHERE routine_schema = 'public'
   AND routine_name IN ('register_rider_session', 'claim_order_atomic');
