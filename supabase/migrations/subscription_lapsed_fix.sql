-- ============================================================================
-- SUBSCRIPTION LAPSED & CANCELLED FIX
-- Run this in Supabase SQL Editor
-- ============================================================================

-- ============================================================================
-- 1. Add missing columns to bookings table
-- ============================================================================

-- Add cancelled_at column
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

-- Add lapsed_at column
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS lapsed_at TIMESTAMPTZ;

-- ============================================================================
-- 2. Enable pg_cron extension
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ============================================================================
-- 3. Update check_and_lapse_subscriptions function
-- Lapses all subscription bookings from previous day not completed by midnight
-- ============================================================================

CREATE OR REPLACE FUNCTION check_and_lapse_subscriptions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Lapse all subscription bookings from previous day not completed
    UPDATE bookings
    SET status = 'lapsed', 
        lapsed_at = CURRENT_DATE + INTERVAL '0 seconds',  -- Midnight 12:00 AM
        updated_at = NOW()
    WHERE is_subscription_booking = true
      AND status IN ('pending', 'confirmed', 'in_progress')
      AND DATE(created_at) < CURRENT_DATE;  -- Created before today
END;
$$;

-- ============================================================================
-- 4. Remove existing cron job if any (to avoid duplicates)
-- ============================================================================

SELECT cron.unschedule('lapse-uncompleted-subscriptions');

-- ============================================================================
-- 5. Add cron job - Runs at midnight 12:00 AM daily
-- ============================================================================

SELECT cron.schedule(
    'lapse-uncompleted-subscriptions',
    '0 0 * * *',  -- 12:00 AM daily
    'SELECT check_and_lapse_subscriptions()'
);

-- ============================================================================
-- 6. Verify setup
-- ============================================================================

-- Check scheduled jobs
SELECT * FROM cron.job;

-- Check bookings table columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'bookings' 
AND column_name IN ('cancelled_at', 'lapsed_at');

-- ============================================================================
-- DONE
-- ============================================================================
