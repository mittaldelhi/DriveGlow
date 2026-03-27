-- Booking Status & Start Service Updates
-- Adds lapsed status, started_at timestamp, and is_subscription_booking flag

-- 1. Add new columns to bookings table
ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS is_subscription_booking BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS plan_id UUID REFERENCES subscription_plans(id);

COMMENT ON COLUMN bookings.is_subscription_booking IS 'True if this booking was made from a subscription plan';
COMMENT ON COLUMN bookings.started_at IS 'Timestamp when user clicked Start Service button';
COMMENT ON COLUMN bookings.plan_id IS 'The subscription plan ID if this is a subscription booking';

-- 2. Update the status check constraint to include 'lapsed'
-- First drop the existing constraint
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_status_check;

-- Recreate with lapsed status
ALTER TABLE bookings ADD CONSTRAINT bookings_status_check 
CHECK (status IN ('pending', 'confirmed', 'inProgress', 'completed', 'cancelled', 'lapsed'));

-- 3. Function to check and auto-lapse subscription bookings after 24 hours
CREATE OR REPLACE FUNCTION check_and_lapse_subscriptions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_lapsed_bookings RECORD;
BEGIN
    -- Find subscription bookings that are still pending/confirmed
    -- and have been created more than 24 hours ago without being started
    FOR v_lapsed_bookings IN
        SELECT id FROM bookings
        WHERE is_subscription_booking = TRUE
            AND status IN ('pending', 'confirmed')
            AND created_at < NOW() - INTERVAL '24 hours'
            AND started_at IS NULL
    LOOP
        UPDATE bookings
        SET status = 'lapsed', updated_at = NOW()
        WHERE id = v_lapsed_bookings.id;
    END LOOP;
END;
$$;

-- 4. Function to start a service (user clicks Start Service)
CREATE OR REPLACE FUNCTION start_booking_service(
    p_booking_id TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Only allow starting if booking is pending/confirmed and not lapsed
    UPDATE bookings
    SET status = 'inProgress',
        started_at = NOW(),
        updated_at = NOW()
    WHERE id = p_booking_id
        AND status IN ('pending', 'confirmed')
        AND (is_subscription_booking = FALSE OR 
             (is_subscription_booking = TRUE AND started_at IS NULL AND created_at > NOW() - INTERVAL '24 hours'));
END;
$$;

-- 5. Function to get bookings visible to staff (only active/inProgress)
CREATE OR REPLACE FUNCTION get_staff_visible_bookings()
RETURNS TABLE (
    id TEXT,
    user_id UUID,
    service_id TEXT,
    vehicle_name TEXT,
    vehicle_number TEXT,
    appointment_date TIMESTAMPTZ,
    status TEXT,
    total_price NUMERIC,
    qr_code_data TEXT,
    check_in_time TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ,
    is_subscription_booking BOOLEAN,
    started_at TIMESTAMPTZ,
    plan_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id, b.user_id, b.service_id, b.vehicle_name, b.vehicle_number,
        b.appointment_date, b.status, b.total_price, b.qr_code_data,
        b.check_in_time, b.completed_at, b.created_at,
        b.is_subscription_booking, b.started_at, b.plan_id
    FROM bookings b
    WHERE b.status = 'inProgress'
       OR (b.status IN ('pending', 'confirmed') AND b.started_at IS NOT NULL)
    ORDER BY b.appointment_date ASC;
END;
$$;

-- 6. Function to check if a subscription booking can still be started
CREATE OR REPLACE FUNCTION can_start_subscription_booking(p_booking_id TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_booking RECORD;
    v_can_start BOOLEAN := FALSE;
BEGIN
    SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id;
    
    IF v_booking IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Must be subscription booking
    IF v_booking.is_subscription_booking != TRUE THEN
        -- Non-subscription bookings can always be started
        RETURN v_booking.status IN ('pending', 'confirmed');
    END IF;
    
    -- For subscription: must be pending/confirmed, not started, and within 24 hours
    IF v_booking.status IN ('pending', 'confirmed') 
        AND v_booking.started_at IS NULL 
        AND v_booking.created_at > NOW() - INTERVAL '24 hours' THEN
        v_can_start := TRUE;
    END IF;
    
    RETURN v_can_start;
END;
$$;

-- 7. Create index for staff queries
CREATE INDEX IF NOT EXISTS idx_bookings_staff_view 
ON bookings(status, started_at, is_subscription_booking, created_at);

-- 8. Create index for user subscription queries
CREATE INDEX IF NOT EXISTS idx_bookings_subscription 
ON bookings(user_id, is_subscription_booking, status) 
WHERE is_subscription_booking = TRUE;
