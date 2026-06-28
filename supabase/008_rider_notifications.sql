-- ============================================================
-- Real rider notifications. The notification bell badge and the
-- whole Notifications screen were 100% hardcoded mock data (six
-- fixed entries, never connected to Supabase) — this is why the
-- count never changed no matter what actually happened to orders.
--
-- This adds a real table, logged automatically by a trigger on the
-- existing order lifecycle (assigned / picked up / delivered /
-- payment received / cancelled), and read live by the rider app.
-- Run in Supabase SQL Editor. Safe to re-run.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.rider_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id uuid NOT NULL REFERENCES public.profiles(id),
  order_id uuid REFERENCES public.orders(id),
  type text NOT NULL CHECK (type IN ('order_assigned', 'picked_up', 'delivered', 'cancelled', 'payment_received')),
  title text NOT NULL,
  body text NOT NULL,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS rider_notifications_rider_id_created_at_idx
  ON public.rider_notifications (rider_id, created_at DESC);

ALTER TABLE public.rider_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "rider_notifications_select_own" ON public.rider_notifications;
CREATE POLICY "rider_notifications_select_own"
  ON public.rider_notifications FOR SELECT
  USING (rider_id = auth.uid());

DROP POLICY IF EXISTS "rider_notifications_update_own" ON public.rider_notifications;
CREATE POLICY "rider_notifications_update_own"
  ON public.rider_notifications FOR UPDATE
  USING (rider_id = auth.uid());

-- ────────────────────────────────────────────────────────────
-- Trigger: logs a notification row on every real lifecycle event.
-- AFTER UPDATE (not BEFORE, like finalize_delivery_payment) so it can
-- read the final, already-computed rider_payment for the "payment
-- received" notification. SECURITY DEFINER so it can insert
-- regardless of which client (rider app) performed the plain status
-- update — no app-side changes needed to fire this.
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.log_rider_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  order_label text := COALESCE(NEW.order_number, '#' || left(NEW.id::text, 8));
BEGIN
  IF NEW.rider_id IS NOT NULL AND OLD.rider_id IS DISTINCT FROM NEW.rider_id THEN
    INSERT INTO public.rider_notifications (rider_id, order_id, type, title, body)
    VALUES (NEW.rider_id, NEW.id, 'order_assigned', 'New order assigned',
      'Order ' || order_label || ' has been assigned to you.');
  END IF;

  IF NEW.rider_id IS NOT NULL AND NEW.status = 'out_for_delivery' AND OLD.status IS DISTINCT FROM 'out_for_delivery' THEN
    INSERT INTO public.rider_notifications (rider_id, order_id, type, title, body)
    VALUES (NEW.rider_id, NEW.id, 'picked_up', 'Order picked up',
      'You picked up order ' || order_label || '. Head to the customer.');
  END IF;

  IF NEW.rider_id IS NOT NULL AND NEW.status = 'delivered' AND OLD.status IS DISTINCT FROM 'delivered' THEN
    INSERT INTO public.rider_notifications (rider_id, order_id, type, title, body)
    VALUES (NEW.rider_id, NEW.id, 'delivered', 'Delivery completed',
      'Order ' || order_label || ' marked delivered.');

    IF NEW.rider_payment IS NOT NULL THEN
      INSERT INTO public.rider_notifications (rider_id, order_id, type, title, body)
      VALUES (NEW.rider_id, NEW.id, 'payment_received', 'Payment received',
        '₹' || trim(to_char(NEW.rider_payment, '999990.00')) || ' credited for order ' || order_label || '.');
    END IF;
  END IF;

  IF NEW.rider_id IS NOT NULL AND NEW.status = 'cancelled' AND OLD.status IS DISTINCT FROM 'cancelled' THEN
    INSERT INTO public.rider_notifications (rider_id, order_id, type, title, body)
    VALUES (NEW.rider_id, NEW.id, 'cancelled', 'Order cancelled',
      'Order ' || order_label || ' was cancelled.');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_rider_notification ON public.orders;
CREATE TRIGGER trg_log_rider_notification
  AFTER UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.log_rider_notification();

-- ────────────────────────────────────────────────────────────
-- Enable Realtime on this table so the badge/list update live the
-- instant a notification is inserted, not just on next manual fetch.
-- ────────────────────────────────────────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'rider_notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.rider_notifications;
  END IF;
END $$;

-- ────────────────────────────────────────────────────────────
-- Verify
-- ────────────────────────────────────────────────────────────

SELECT policyname, cmd FROM pg_policies WHERE tablename = 'rider_notifications';
SELECT tgname FROM pg_trigger WHERE tgname = 'trg_log_rider_notification';
