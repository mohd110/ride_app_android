-- ============================================================
-- Real earnings, order-history, and payout tracking for the rider app.
--
-- Today's/weekly/monthly/lifetime earnings, order counts, and wallet
-- balance were previously hardcoded numbers in the Flutter app that
-- only ever incremented in-memory during a session and reset on every
-- login. None of it was ever read from the database. This migration
-- adds the missing pieces: a payout ledger, and RPC functions that
-- compute everything straight from orders.rider_payment (already the
-- authoritative per-order earnings figure from migration 006).
--
-- Run in Supabase SQL Editor. Safe to re-run.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. rider_payouts: a ledger of payout batches (e.g. a weekly bank/UPI
--    settlement). Riders can only ever read their own; creating/marking
--    a payout is an admin action, done via the SQL Editor (service role)
--    for now since the rider app has no admin role to grant this to.
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.rider_payouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id uuid NOT NULL REFERENCES public.profiles(id),
  amount numeric NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid')),
  period_start date NOT NULL,
  period_end date NOT NULL,
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS payout_id uuid REFERENCES public.rider_payouts(id) ON DELETE SET NULL;

ALTER TABLE public.rider_payouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "rider_payouts_select_own" ON public.rider_payouts;
CREATE POLICY "rider_payouts_select_own"
  ON public.rider_payouts FOR SELECT
  USING (auth.uid() = rider_id);

-- ────────────────────────────────────────────────────────────
-- 2. Earnings summary — today/week/month/lifetime + order counts +
--    wallet balance (delivered orders not yet attached to a payout).
--    Always scoped to the calling rider via auth.uid(), never a param,
--    so one rider can never query another's earnings.
--
--    Day/week/month boundaries are computed in Asia/Kolkata, not UTC —
--    riders and the restaurant are India-only, and UTC midnight is
--    5:30am IST, which would make "today" silently roll over hours
--    early/late and double count or undercount deliveries.
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_my_earnings_summary()
RETURNS TABLE (
  today_earnings numeric,
  week_earnings numeric,
  month_earnings numeric,
  lifetime_earnings numeric,
  today_orders bigint,
  total_orders bigint,
  wallet_balance numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    COALESCE(SUM(rider_payment) FILTER (
      WHERE delivered_at >= (date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata')
    ), 0),
    COALESCE(SUM(rider_payment) FILTER (
      WHERE delivered_at >= (date_trunc('week', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata')
    ), 0),
    COALESCE(SUM(rider_payment) FILTER (
      WHERE delivered_at >= (date_trunc('month', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata')
    ), 0),
    COALESCE(SUM(rider_payment), 0),
    COUNT(*) FILTER (
      WHERE delivered_at >= (date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata')
    ),
    COUNT(*),
    COALESCE(SUM(rider_payment) FILTER (WHERE payout_id IS NULL), 0)
  FROM public.orders
  WHERE rider_id = auth.uid() AND status = 'delivered';
$$;

GRANT EXECUTE ON FUNCTION public.get_my_earnings_summary() TO authenticated;

-- ────────────────────────────────────────────────────────────
-- 3. Daily earnings series (zero-filled) for the earnings chart — one
--    call covers the daily/weekly/monthly chart views, bucketed
--    client-side, instead of three separate fake hardcoded data sets.
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_my_daily_earnings(p_days integer DEFAULT 30)
RETURNS TABLE (day date, total numeric)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  -- d is a timestamptz; casting it straight to ::date uses the session's
  -- timezone (UTC on Supabase), which silently mislabels every bucket one
  -- day early (midnight IST today is 18:30 UTC *yesterday*). Converting
  -- through "AT TIME ZONE 'Asia/Kolkata'" first gives the IST wall-clock
  -- date, matching the boundary this function was built to generate.
  SELECT (d AT TIME ZONE 'Asia/Kolkata')::date AS day, COALESCE(SUM(o.rider_payment), 0) AS total
  FROM generate_series(
    (date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata') - (greatest(p_days, 1) - 1) * interval '1 day',
    (date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata'),
    interval '1 day'
  ) d
  LEFT JOIN public.orders o
    ON o.rider_id = auth.uid()
    AND o.status = 'delivered'
    AND (o.delivered_at AT TIME ZONE 'Asia/Kolkata')::date = (d AT TIME ZONE 'Asia/Kolkata')::date
  GROUP BY d
  ORDER BY d;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_daily_earnings(integer) TO authenticated;

-- ────────────────────────────────────────────────────────────
-- 4. Verify
-- ────────────────────────────────────────────────────────────

SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'payout_id';

SELECT policyname, tablename, cmd FROM pg_policies
WHERE tablename = 'rider_payouts';

SELECT * FROM public.get_my_earnings_summary();
SELECT * FROM public.get_my_daily_earnings(7);
