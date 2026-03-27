-- ============================================================
-- DRIVEGLOW ALL UPDATES - Combined Migration
-- Run this AFTER driveglow_master_schema.sql in Supabase SQL Editor
-- This file contains ALL updates from all migration files
-- ============================================================

-- ============================================================
-- PART 1: UNIFIED USER & STAFF SYSTEM
-- ============================================================

-- IMPORTANT: DROP TABLE statements removed to preserve user data!
-- Old staff tables are not dropped - they may not exist anyway

-- Update user_profiles with new columns
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS username TEXT UNIQUE;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS employee_id TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_username 
ON user_profiles(username) WHERE username IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_employee_id 
ON user_profiles(employee_id) WHERE employee_id IS NOT NULL;

-- RLS Functions - Updated versions
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles p
    WHERE p.id = auth.uid() AND upper(p.membership_tier) = 'ADMIN'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_staff_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles p
    WHERE p.id = auth.uid() AND upper(p.membership_tier) IN ('STAFF', 'ADMIN')
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_staff_user() TO authenticated;

-- MISSING GRANTS - CRITICAL
GRANT SELECT ON user_profiles TO authenticated;
GRANT SELECT ON user_profiles TO anon;
GRANT SELECT ON user_vehicles TO authenticated;
GRANT SELECT ON bookings TO authenticated;
GRANT SELECT ON subscription_plans TO authenticated;
GRANT SELECT ON subscription_plans TO anon;
GRANT SELECT ON standard_services TO authenticated;
GRANT SELECT ON standard_services TO anon;

-- Login & Table Permissions
DROP POLICY IF EXISTS "user_profiles_login_lookup" ON user_profiles;
CREATE POLICY "user_profiles_login_lookup" ON user_profiles
    FOR SELECT TO authenticated
    USING (true);

-- Function to get email by user_id
CREATE OR REPLACE FUNCTION public.get_user_email(p_user_id UUID)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT email FROM auth.users WHERE id = p_user_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_email(UUID) TO authenticated;

-- Function to lookup user by employee_id or username (bypasses RLS)
CREATE OR REPLACE FUNCTION public.lookup_staff_user(p_login_input TEXT)
RETURNS TABLE(id UUID, username TEXT, employee_id TEXT, membership_tier TEXT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT id, username, employee_id, membership_tier 
  FROM user_profiles 
  WHERE lower(employee_id) = lower(p_login_input) 
     OR lower(username) = lower(p_login_input)
     OR employee_id = p_login_input
     OR username = p_login_input;
$$;

GRANT EXECUTE ON FUNCTION public.lookup_staff_user(TEXT) TO authenticated;

-- Staff Requests Table
CREATE TABLE IF NOT EXISTS staff_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    request_type TEXT NOT NULL CHECK (request_type IN (
        'password_reset', 'leave', 'salary', 'profile_update', 'other'
    )),
    description TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'denied')),
    admin_comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_staff_requests_status ON staff_requests(status);
CREATE INDEX IF NOT EXISTS idx_staff_requests_type ON staff_requests(request_type);

ALTER TABLE staff_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_requests_full" ON staff_requests;
CREATE POLICY "admin_requests_full" ON staff_requests
    FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND membership_tier = 'ADMIN'))
    WITH CHECK (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND membership_tier = 'ADMIN'));

DROP POLICY IF EXISTS "staff_create_request" ON staff_requests;
CREATE POLICY "staff_create_request" ON staff_requests
    FOR INSERT TO authenticated WITH CHECK (staff_user_id = auth.uid());

DROP POLICY IF EXISTS "staff_read_own_requests" ON staff_requests;
CREATE POLICY "staff_read_own_requests" ON staff_requests
    FOR SELECT TO authenticated USING (staff_user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON TABLE staff_requests TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================
-- PART 2: STAFF ATTENDANCE CALENDAR
-- ============================================================

-- Add staff_id to service_feedback
ALTER TABLE service_feedback ADD COLUMN IF NOT EXISTS staff_id UUID REFERENCES user_profiles(id);

-- Create staff_attendance_calendar table
CREATE TABLE IF NOT EXISTS staff_attendance_calendar (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('present', 'weekoff', 'leave', 'holiday')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_attendance_calendar_staff_date 
ON staff_attendance_calendar(staff_user_id, date);

-- Create staff_weekoff_pattern table
CREATE TABLE IF NOT EXISTS staff_weekoff_pattern (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    day_of_week INT NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
    is_weekly_off BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_weekoff_pattern_staff 
ON staff_weekoff_pattern(staff_user_id);

-- RLS for attendance tables
ALTER TABLE staff_attendance_calendar ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_weekoff_pattern ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "attendance_calendar_read_own" ON staff_attendance_calendar;
CREATE POLICY "attendance_calendar_read_own" ON staff_attendance_calendar
    FOR SELECT TO authenticated USING (staff_user_id = auth.uid());

DROP POLICY IF EXISTS "attendance_calendar_admin_full" ON staff_attendance_calendar;
CREATE POLICY "attendance_calendar_admin_full" ON staff_attendance_calendar
    FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND membership_tier = 'ADMIN'))
    WITH CHECK (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND membership_tier = 'ADMIN'));

DROP POLICY IF EXISTS "attendance_calendar_insert_own" ON staff_attendance_calendar;
CREATE POLICY "attendance_calendar_insert_own" ON staff_attendance_calendar
    FOR INSERT TO authenticated WITH CHECK (staff_user_id = auth.uid());

DROP POLICY IF EXISTS "attendance_calendar_update_own" ON staff_attendance_calendar;
CREATE POLICY "attendance_calendar_update_own" ON staff_attendance_calendar
    FOR UPDATE TO authenticated
    USING (staff_user_id = auth.uid())
    WITH CHECK (staff_user_id = auth.uid());

DROP POLICY IF EXISTS "weekoff_pattern_read_own" ON staff_weekoff_pattern;
CREATE POLICY "weekoff_pattern_read_own" ON staff_weekoff_pattern
    FOR SELECT TO authenticated USING (staff_user_id = auth.uid());

DROP POLICY IF EXISTS "weekoff_pattern_admin_full" ON staff_weekoff_pattern;
CREATE POLICY "weekoff_pattern_admin_full" ON staff_weekoff_pattern
    FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND membership_tier = 'ADMIN'))
    WITH CHECK (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND membership_tier = 'ADMIN'));

GRANT SELECT, INSERT, UPDATE, DELETE ON staff_attendance_calendar TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON staff_weekoff_pattern TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================
-- PART 3: COMPANY CONFIG
-- ============================================================

-- NOTE: Company config INSERT commented out to preserve existing values
-- Uncomment if you want to reset company config
-- INSERT INTO app_config (key, value) VALUES
--   ('company_about', 'DriveGlow is a premium car wash and detailing service...'),
--   ('company_address', 'Drive Glow studio, Besides Hari Ram Hospital...'),
--   ('company_phone', '9999081105'),
--   ('company_email', 'contact@driveglow.com'),
--   ('company_openhours', 'Mon-Sat: 9:00 AM - 7:00 PM')
-- ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- PART 4: SUBSCRIPTION USAGE TRACKER
-- ============================================================

-- Add new columns to subscription_plans
ALTER TABLE subscription_plans 
ADD COLUMN IF NOT EXISTS show_unlimited BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS monthly_cap_override INTEGER;

COMMENT ON COLUMN subscription_plans.show_unlimited IS 'When true, display Unlimited washes to users instead of usage stats';
COMMENT ON COLUMN subscription_plans.monthly_cap_override IS 'Admin can override the monthly usage cap for this plan';

-- Create subscription_usage_tracker table
CREATE TABLE IF NOT EXISTS subscription_usage_tracker (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
    year_month TEXT NOT NULL,
    usage_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, plan_id, year_month)
);

CREATE INDEX IF NOT EXISTS idx_usage_tracker_user_plan_month 
ON subscription_usage_tracker(user_id, plan_id, year_month);

ALTER TABLE subscription_usage_tracker ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS usage_tracker_select_own ON subscription_usage_tracker;
CREATE POLICY usage_tracker_select_own ON subscription_usage_tracker
FOR SELECT TO authenticated
USING (user_id = auth.uid());

DROP POLICY IF EXISTS usage_tracker_insert_own ON subscription_usage_tracker;
CREATE POLICY usage_tracker_insert_own ON subscription_usage_tracker
FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS usage_tracker_update_own ON subscription_usage_tracker;
CREATE POLICY usage_tracker_update_own ON subscription_usage_tracker
FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS usage_tracker_admin ON subscription_usage_tracker;
CREATE POLICY usage_tracker_admin ON subscription_usage_tracker
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_profiles up 
        WHERE up.id = auth.uid() 
        AND up.membership_tier = 'ADMIN'
    )
);

-- Usage tracking functions
CREATE OR REPLACE FUNCTION increment_usage_count(p_user_id UUID, p_plan_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_year_month TEXT;
    v_current_count INTEGER;
BEGIN
    v_year_month := to_char(NOW(), 'YYYY-MM');
    
    SELECT usage_count INTO v_current_count
    FROM subscription_usage_tracker
    WHERE user_id = p_user_id 
        AND plan_id = p_plan_id 
        AND year_month = v_year_month;
    
    IF v_current_count IS NULL THEN
        INSERT INTO subscription_usage_tracker (user_id, plan_id, year_month, usage_count)
        VALUES (p_user_id, p_plan_id, v_year_month, 1)
        ON CONFLICT (user_id, plan_id, year_month) 
        DO UPDATE SET usage_count = 1, updated_at = NOW();
    ELSE
        UPDATE subscription_usage_tracker
        SET usage_count = v_current_count + 1, updated_at = NOW()
        WHERE user_id = p_user_id 
            AND plan_id = p_plan_id 
            AND year_month = v_year_month;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION get_current_month_usage(p_user_id UUID, p_plan_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_year_month TEXT;
    v_count INTEGER;
BEGIN
    v_year_month := to_char(NOW(), 'YYYY-MM');
    
    SELECT COALESCE(usage_count, 0) INTO v_count
    FROM subscription_usage_tracker
    WHERE user_id = p_user_id 
        AND plan_id = p_plan_id 
        AND year_month = v_year_month;
    
    RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION reset_monthly_usage(p_user_id UUID, p_plan_id UUID, p_year_month TEXT, p_count INTEGER DEFAULT 0)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE subscription_usage_tracker
    SET usage_count = p_count, updated_at = NOW()
    WHERE user_id = p_user_id 
        AND plan_id = p_plan_id 
        AND year_month = p_year_month;
END;
$$;

CREATE OR REPLACE FUNCTION get_plan_effective_cap(p_plan_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_override INTEGER;
    v_frequency TEXT;
    v_limit INTEGER;
BEGIN
    SELECT monthly_cap_override INTO v_override
    FROM subscription_plans WHERE id = p_plan_id;
    
    IF v_override IS NOT NULL AND v_override > 0 THEN
        RETURN v_override;
    END IF;
    
    SELECT frequency_limit INTO v_frequency
    FROM subscription_plans WHERE id = p_plan_id;
    
    IF v_frequency IS NULL THEN
        RETURN NULL;
    END IF;
    
    v_limit := (regexp_match(v_frequency, '(\d+)'))[1]::INTEGER;
    RETURN v_limit;
END;
$$;

-- ============================================================
-- PART 5: BOOKING STATUS UPDATES
-- ============================================================

-- Add new columns to bookings
ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS is_subscription_booking BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS plan_id UUID REFERENCES subscription_plans(id);

COMMENT ON COLUMN bookings.is_subscription_booking IS 'True if this booking was made from a subscription plan';
COMMENT ON COLUMN bookings.started_at IS 'Timestamp when user clicked Start Service button';
COMMENT ON COLUMN bookings.plan_id IS 'The subscription plan ID if this is a subscription booking';

-- Update status check constraint to include 'lapsed'
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
ALTER TABLE bookings ADD CONSTRAINT bookings_status_check 
CHECK (status IN ('pending', 'confirmed', 'inProgress', 'completed', 'cancelled', 'lapsed'));

-- Booking functions
CREATE OR REPLACE FUNCTION check_and_lapse_subscriptions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_lapsed_bookings RECORD;
BEGIN
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

CREATE OR REPLACE FUNCTION start_booking_service(p_booking_id TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
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

CREATE OR REPLACE FUNCTION get_staff_visible_bookings()
RETURNS TABLE (
    id TEXT, user_id UUID, service_id TEXT, vehicle_name TEXT, vehicle_number TEXT,
    appointment_date TIMESTAMPTZ, status TEXT, total_price NUMERIC, qr_code_data TEXT,
    check_in_time TIMESTAMPTZ, completed_at TIMESTAMPTZ, created_at TIMESTAMPTZ,
    is_subscription_booking BOOLEAN, started_at TIMESTAMPTZ, plan_id UUID
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
    
    IF v_booking.is_subscription_booking != TRUE THEN
        RETURN v_booking.status IN ('pending', 'confirmed');
    END IF;
    
    IF v_booking.status IN ('pending', 'confirmed') 
        AND v_booking.started_at IS NULL 
        AND v_booking.created_at > NOW() - INTERVAL '24 hours' THEN
        v_can_start := TRUE;
    END IF;
    
    RETURN v_can_start;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_bookings_staff_view 
ON bookings(status, started_at, is_subscription_booking, created_at);

CREATE INDEX IF NOT EXISTS idx_bookings_subscription 
ON bookings(user_id, is_subscription_booking, status) 
WHERE is_subscription_booking = TRUE;

-- ============================================================
-- PART 6: FEEDBACK TICKET SYSTEM
-- ============================================================

-- Add new columns to service_feedback
ALTER TABLE service_feedback 
ADD COLUMN IF NOT EXISTS is_complaint BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS ticket_number TEXT,
ADD COLUMN IF NOT EXISTS ticket_status TEXT DEFAULT 'open' CHECK (ticket_status IN ('open', 'in_progress', 'resolved', 'closed')),
ADD COLUMN IF NOT EXISTS ticket_priority TEXT DEFAULT 'normal' CHECK (ticket_priority IN ('normal', 'high')),
ADD COLUMN IF NOT EXISTS admin_notes TEXT,
ADD COLUMN IF NOT EXISTS feedback_updated_at TIMESTAMPTZ;

COMMENT ON COLUMN service_feedback.is_complaint IS 'True if customer marked this as a complaint';
COMMENT ON COLUMN service_feedback.ticket_number IS 'Auto-generated ticket number (e.g., TKT-20260307-0001)';
COMMENT ON COLUMN service_feedback.ticket_status IS 'Ticket workflow status';
COMMENT ON COLUMN service_feedback.ticket_priority IS 'Priority level - high for complaints';
COMMENT ON COLUMN service_feedback.admin_notes IS 'Internal notes from admin';
COMMENT ON COLUMN service_feedback.feedback_updated_at IS 'Last update timestamp for feedback';

-- Ticket counter table
CREATE TABLE IF NOT EXISTS ticket_counter (
    id INTEGER PRIMARY KEY DEFAULT 1,
    last_date TEXT,
    sequence_num INTEGER DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO ticket_counter (id, last_date, sequence_num)
VALUES (1, '', 0)
ON CONFLICT (id) DO NOTHING;

-- Ticket functions
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_today TEXT;
    v_last_date TEXT;
    v_sequence INTEGER;
    v_ticket_number TEXT;
BEGIN
    v_today := to_char(NOW(), 'YYYYMMDD');
    
    SELECT COALESCE(last_date, ''), COALESCE(sequence_num, 0) INTO v_last_date, v_sequence
    FROM ticket_counter WHERE id = 1;
    
    IF v_last_date != v_today THEN
        v_sequence := 0;
    END IF;
    
    v_sequence := v_sequence + 1;
    v_ticket_number := 'TKT-' || v_today || '-' || LPAD(v_sequence::TEXT, 4, '0');
    
    UPDATE ticket_counter
    SET last_date = v_today, sequence_num = v_sequence, updated_at = NOW()
    WHERE id = 1;
    
    RETURN v_ticket_number;
END;
$$;

CREATE OR REPLACE FUNCTION save_feedback_with_ticket(
    p_booking_id TEXT, p_user_id UUID, p_rating NUMERIC(3,1), p_comment TEXT,
    p_tags TEXT[], p_is_complaint BOOLEAN DEFAULT FALSE, p_staff_id UUID DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_feedback_id TEXT;
    v_ticket_number TEXT;
    v_existing_count INTEGER;
BEGIN
    v_feedback_id := 'fb_' || gen_random_uuid()::TEXT;
    
    -- Check if feedback already exists for this booking
    SELECT COUNT(*) INTO v_existing_count FROM service_feedback WHERE booking_id = p_booking_id;
    
    IF v_existing_count > 0 THEN
        -- Update existing feedback (don't regenerate ticket number)
        UPDATE service_feedback SET
            rating = p_rating, 
            comment = p_comment, 
            tags = p_tags,
            is_complaint = p_is_complaint, 
            staff_id = COALESCE(p_staff_id, staff_id),
            feedback_updated_at = NOW()
        WHERE booking_id = p_booking_id;
        
        RETURN (SELECT id FROM service_feedback WHERE booking_id = p_booking_id LIMIT 1);
    END IF;
    
    -- Only generate ticket for new complaints
    IF p_is_complaint = TRUE THEN
        v_ticket_number := generate_ticket_number();
    END IF;
    
    INSERT INTO service_feedback (
        id, booking_id, user_id, rating, comment, tags,
        is_complaint, ticket_number, ticket_status, ticket_priority,
        staff_id, created_at, feedback_updated_at
    ) VALUES (
        v_feedback_id, p_booking_id, p_user_id, p_rating, p_comment, p_tags,
        p_is_complaint, v_ticket_number, 
        CASE WHEN p_is_complaint THEN 'open' ELSE NULL END,
        CASE WHEN p_is_complaint THEN 'high' ELSE 'normal' END,
        p_staff_id, NOW(), NOW()
    );
    
    RETURN v_feedback_id;
END;
$$;

CREATE OR REPLACE FUNCTION update_ticket_status(p_feedback_id TEXT, p_status TEXT, p_admin_notes TEXT DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE service_feedback
    SET ticket_status = p_status, admin_notes = COALESCE(p_admin_notes, admin_notes), feedback_updated_at = NOW()
    WHERE id = p_feedback_id AND ticket_number IS NOT NULL;
END;
$$;

CREATE OR REPLACE FUNCTION get_all_tickets()
RETURNS TABLE (
    id TEXT, booking_id TEXT, user_id UUID, rating NUMERIC(3,1), comment TEXT,
    tags TEXT[], is_complaint BOOLEAN, ticket_number TEXT, ticket_status TEXT,
    ticket_priority TEXT, admin_notes TEXT, created_at TIMESTAMPTZ, feedback_updated_at TIMESTAMPTZ,
    customer_name TEXT, service_name TEXT, staff_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        fb.id, fb.booking_id, fb.user_id, fb.rating, fb.comment, fb.tags,
        fb.is_complaint, fb.ticket_number, fb.ticket_status, fb.ticket_priority,
        fb.admin_notes, fb.created_at, fb.feedback_updated_at,
        COALESCE(up.full_name, 'Unknown') as customer_name,
        COALESCE(ss.name, b.service_id) as service_name,
        COALESCE(staff.full_name, 'Unassigned') as staff_name
    FROM service_feedback fb
    LEFT JOIN bookings b ON fb.booking_id = b.id
    LEFT JOIN user_profiles up ON fb.user_id = up.id
    LEFT JOIN standard_services ss ON b.service_id = ss.id::TEXT
    LEFT JOIN user_profiles staff ON fb.staff_id = staff.id
    WHERE fb.ticket_number IS NOT NULL
    ORDER BY CASE fb.ticket_priority WHEN 'high' THEN 1 ELSE 2 END, fb.created_at DESC;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_feedback_ticket_number ON service_feedback(ticket_number) WHERE ticket_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_feedback_ticket_status ON service_feedback(ticket_status) WHERE ticket_status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_feedback_ticket_priority ON service_feedback(ticket_priority) WHERE ticket_priority IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_feedback_is_complaint ON service_feedback(is_complaint) WHERE is_complaint = TRUE;

-- Complaint stats view
CREATE OR REPLACE VIEW complaint_stats AS
SELECT 
    COUNT(*) FILTER (WHERE is_complaint = TRUE) as total_complaints,
    COUNT(*) FILTER (WHERE is_complaint = TRUE AND ticket_status = 'open') as open_complaints,
    COUNT(*) FILTER (WHERE is_complaint = TRUE AND ticket_status = 'in_progress') as in_progress_complaints,
    COUNT(*) FILTER (WHERE is_complaint = TRUE AND ticket_status = 'resolved') as resolved_complaints,
    COUNT(*) FILTER (WHERE is_complaint = TRUE AND ticket_status = 'closed') as closed_complaints,
    COUNT(*) FILTER (WHERE is_complaint = FALSE) as total_feedback,
    AVG(rating) FILTER (WHERE is_complaint = FALSE) as avg_rating
FROM service_feedback;

-- ============================================================
-- PART 7: COUPONS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.coupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    description TEXT,
    type TEXT NOT NULL CHECK (type IN ('percentage', 'fixed_amount')),
    value NUMERIC(10,2) NOT NULL,
    min_purchase_amount NUMERIC(10,2) DEFAULT 0,
    max_discount_amount NUMERIC(10,2),
    usage_limit INTEGER DEFAULT -1,
    usage_count INTEGER DEFAULT 0,
    valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'expired')),
    applicable_plans UUID[] DEFAULT array[]::UUID[],
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_coupons_code ON public.coupons(code);
CREATE INDEX IF NOT EXISTS idx_coupons_status ON public.coupons(status);
CREATE INDEX IF NOT EXISTS idx_coupons_valid_until ON public.coupons(valid_until);

ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS coupons_read_all ON public.coupons;
CREATE POLICY coupons_read_all ON public.coupons FOR SELECT USING (true);

DROP POLICY IF EXISTS coupons_write_admin ON public.coupons;
CREATE POLICY coupons_write_admin ON public.coupons FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND membership_tier = 'ADMIN'));

-- Coupon functions
CREATE OR REPLACE FUNCTION get_active_coupons()
RETURNS TABLE (
    id UUID, code TEXT, description TEXT, type TEXT, value NUMERIC,
    min_purchase_amount NUMERIC, max_discount_amount NUMERIC, valid_until TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.code, c.description, c.type, c.value, c.min_purchase_amount, c.max_discount_amount, c.valid_until
    FROM coupons c
    WHERE c.status = 'active' AND c.valid_from <= NOW() AND c.valid_until >= NOW()
    AND (c.usage_limit = -1 OR c.usage_count < c.usage_limit)
    ORDER BY c.created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION validate_coupon(p_code TEXT, p_purchase_amount NUMERIC)
RETURNS TABLE (is_valid BOOLEAN, discount_amount NUMERIC, coupon_id UUID, message TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_coupon RECORD;
    v_discount NUMERIC := 0;
BEGIN
    SELECT * INTO v_coupon
    FROM coupons
    WHERE code = p_code AND status = 'active' AND valid_from <= NOW() AND valid_until >= NOW()
    AND (usage_limit = -1 OR usage_count < usage_limit);

    IF v_coupon IS NULL THEN
        RETURN QUERY SELECT false, 0::NUMERIC, NULL::UUID, 'Invalid or expired coupon';
        RETURN;
    END IF;

    IF p_purchase_amount < v_coupon.min_purchase_amount THEN
        RETURN QUERY SELECT false, 0::NUMERIC, v_coupon.id, 'Minimum purchase of ₹' || v_coupon.min_purchase_amount || ' required';
        RETURN;
    END IF;

    IF v_coupon.type = 'percentage' THEN
        v_discount := p_purchase_amount * (v_coupon.value / 100);
        IF v_coupon.max_discount_amount IS NOT NULL AND v_discount > v_coupon.max_discount_amount THEN
            v_discount := v_coupon.max_discount_amount;
        END IF;
    ELSE
        v_discount := v_coupon.value;
    END IF;

    RETURN QUERY SELECT true, v_discount, v_coupon.id, 'Coupon applied successfully';
END;
$$;

CREATE OR REPLACE FUNCTION use_coupon(p_coupon_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE coupons SET usage_count = usage_count + 1, updated_at = NOW() WHERE id = p_coupon_id;
END;
$$;

-- ============================================================
-- Sample coupons - COMMENTED OUT to preserve existing coupons
-- Uncomment if you want to reset coupons
-- INSERT INTO coupons (code, description, type, value, min_purchase_amount, max_discount_amount, valid_from, valid_until, status)
-- VALUES 
--     ('WELCOME50', 'Welcome Offer - ₹50 off', 'fixed_amount', 50, 500, 50, NOW(), NOW() + INTERVAL '90 days', 'active'),
--     ('SAVE10', '10% off on all services', 'percentage', 10, 0, 200, NOW(), NOW() + INTERVAL '30 days', 'active'),
--     ('PREMIUM200', '₹200 off for premium plans', 'fixed_amount', 200, 2000, 200, NOW(), NOW() + INTERVAL '60 days', 'active')
-- ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- PART 8: USERNAME CHECK FUNCTION
-- ============================================================

-- Username availability check - simple COUNT approach
CREATE OR REPLACE FUNCTION public.check_username_availability(p_username TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count 
    FROM user_profiles 
    WHERE LOWER(username) = LOWER(p_username);
    
    RETURN v_count = 0;
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_username_availability(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.check_username_availability(TEXT) TO authenticated;

-- Alternative: Simple SQL function (more reliable)
CREATE OR REPLACE FUNCTION public.is_username_available(p_username TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT (SELECT COUNT(*) FROM user_profiles WHERE LOWER(username) = LOWER(p_username)) = 0;
$$;

GRANT EXECUTE ON FUNCTION public.is_username_available(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.is_username_available(TEXT) TO authenticated;

-- ============================================================
-- PART 9: ADDITIONAL GRANTS & RLS POLICIES
-- ============================================================

-- Ensure anon can read user_profiles for username check
DROP POLICY IF EXISTS "user_profiles_public_read" ON user_profiles;
CREATE POLICY "user_profiles_public_read" ON user_profiles
    FOR SELECT TO anon USING (true);

-- Ensure authenticated users can read all user_profiles (needed for login lookup)
DROP POLICY IF EXISTS "user_profiles_auth_read" ON user_profiles;
CREATE POLICY "user_profiles_auth_read" ON user_profiles
    FOR SELECT TO authenticated USING (true);

-- FIX ADMIN BOOTSTRAP - Don't overwrite existing admin
DO $$
DECLARE v_admin_id uuid;
DECLARE v_admin_email TEXT := 'admin@gmail.com';
BEGIN
    -- Only set admin if no admin exists yet
    IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE membership_tier = 'ADMIN') THEN
        SELECT id INTO v_admin_id
        FROM auth.users
        WHERE lower(email) = lower(v_admin_email)
        LIMIT 1;

        IF v_admin_id IS NOT NULL THEN
            INSERT INTO public.user_profiles (id, full_name, membership_tier)
            VALUES (v_admin_id, 'Admin', 'ADMIN')
            ON CONFLICT (id) DO UPDATE
            SET membership_tier = 'ADMIN';
        END IF;
    END IF;
END $$;

-- FIX: Create user_profiles for all orphaned auth.users
INSERT INTO user_profiles (id, full_name, membership_tier)
SELECT 
    id,
    COALESCE(
        NULLIF(trim(raw_user_meta_data->>'full_name'), ''),
        split_part(coalesce(email, 'User'), '@', 1),
        'User'
    ) as full_name,
    COALESCE(
        NULLIF(upper(raw_user_meta_data->>'membership_tier'), ''),
        'FREE'
    ) as membership_tier
FROM auth.users
WHERE NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.users.id)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- PART 10: SAMPLE DATA FOR TESTING
-- ============================================================

-- Add sample user_vehicles for testing (only if none exist)
-- Note: We need actual user IDs from auth.users
DO $$
DECLARE v_user_id uuid;
BEGIN
    -- Get first user ID
    SELECT id INTO v_user_id FROM auth.users LIMIT 1;
    
    IF v_user_id IS NOT NULL THEN
        -- Insert sample vehicles
        INSERT INTO user_vehicles (user_id, model, license_plate, color, is_primary)
        VALUES 
            (v_user_id, 'Honda City', 'DL 01 AB 1234', 'White', true),
            (v_user_id, 'Maruti Swift', 'DL 01 CD 5678', 'Red', false)
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- ============================================================
-- PART 11: USER NOTIFICATIONS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS user_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT DEFAULT 'booking' CHECK (type IN ('booking', 'system', 'promo', 'reminder')),
    is_read BOOLEAN DEFAULT FALSE,
    booking_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON user_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON user_notifications(is_read) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON user_notifications(created_at DESC);

ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_read_own" ON user_notifications;
CREATE POLICY "notifications_read_own" ON user_notifications 
    FOR SELECT TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS "notifications_insert_own" ON user_notifications;
CREATE POLICY "notifications_insert_own" ON user_notifications 
    FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid() OR user_id IN (
        SELECT id FROM user_profiles WHERE membership_tier = 'ADMIN'
    ));

-- Function to create booking completion notification
CREATE OR REPLACE FUNCTION public.notify_booking_complete(
    p_booking_id TEXT,
    p_customer_id UUID,
    p_service_name TEXT,
    p_vehicle_number TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO user_notifications (user_id, title, message, type, booking_id)
    VALUES (
        p_customer_id,
        'Service Completed!',
        'Your car wash service (' || p_service_name || ') for vehicle ' || p_vehicle_number || ' has been completed. Thank you for choosing DriveGlow!',
        'booking',
        p_booking_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.notify_booking_complete(TEXT, UUID, TEXT, TEXT) TO authenticated;

-- Function to get unread notification count
CREATE OR REPLACE FUNCTION public.get_unread_notification_count(p_user_id UUID)
RETURNS INTEGER
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT COUNT(*) FROM user_notifications 
    WHERE user_id = p_user_id AND is_read = FALSE;
$$;

GRANT EXECUTE ON FUNCTION public.get_unread_notification_count(UUID) TO authenticated;

-- Function to mark notification as read
CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id UUID)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
    UPDATE user_notifications SET is_read = TRUE WHERE id = p_notification_id;
$$;

GRANT EXECUTE ON FUNCTION public.mark_notification_read(UUID) TO authenticated;

-- ============================================================
-- PART 12: STAFF ATTENDANCE ENHANCEMENTS
-- ============================================================

-- Add leave request table
CREATE TABLE IF NOT EXISTS leave_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    leave_type TEXT NOT NULL CHECK (leave_type IN ('sick', 'casual', 'emergency', 'other')),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'denied')),
    admin_comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_leave_requests_staff ON leave_requests(staff_user_id);
CREATE INDEX IF NOT EXISTS idx_leave_requests_status ON leave_requests(status);

ALTER TABLE leave_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "leave_requests_read_own" ON leave_requests;
CREATE POLICY "leave_requests_read_own" ON leave_requests 
    FOR SELECT TO authenticated USING (staff_user_id = auth.uid());

DROP POLICY IF EXISTS "leave_requests_insert" ON leave_requests;
CREATE POLICY "leave_requests_insert" ON leave_requests 
    FOR INSERT TO authenticated WITH CHECK (staff_user_id = auth.uid());

DROP POLICY IF EXISTS "leave_requests_admin_full" ON leave_requests;
CREATE POLICY "leave_requests_admin_full" ON leave_requests 
    FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND membership_tier = 'ADMIN'))
    WITH CHECK (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND membership_tier = 'ADMIN'));

GRANT SELECT, INSERT, UPDATE ON leave_requests TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Function to get staff attendance with leave status
CREATE OR REPLACE FUNCTION public.get_staff_attendance_with_leave(
    p_staff_id UUID,
    p_month INTEGER,
    p_year INTEGER
)
RETURNS TABLE (
    date DATE,
    status TEXT,
    is_approved BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cal.date,
        COALESCE(
            CASE 
                WHEN lr.status = 'approved' THEN lr.leave_type
                WHEN lr.status = 'pending' THEN 'leave_pending'
                ELSE NULL
            END,
            CASE 
                WHEN sac.status = 'present' THEN 'present'
                WHEN sac.status = 'weekoff' THEN 'weekoff'
                WHEN sac.status = 'leave' THEN 'leave'
                WHEN sac.status = 'holiday' THEN 'holiday'
                ELSE 'absent'
            END
        ) as status,
        CASE WHEN lr.status = 'approved' THEN TRUE ELSE FALSE END as is_approved
    FROM (
        SELECT generate_date as date 
        FROM generate_date(p_year::int || '-' || p_month::int || '-01'::date, 
                          (p_year::int || '-' || p_month::int || '-01'::date + INTERVAL '1 month - 1 day'))
    ) cal
    LEFT JOIN staff_attendance_calendar sac 
        ON sac.staff_user_id = p_staff_id 
        AND sac.date = cal.date
    LEFT JOIN leave_requests lr 
        ON lr.staff_user_id = p_staff_id 
        AND lr.start_date <= cal.date 
        AND lr.end_date >= cal.date
        AND lr.status IN ('pending', 'approved')
    WHERE cal.date <= CURRENT_DATE
    ORDER BY cal.date;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_staff_attendance_with_leave(UUID, INTEGER, INTEGER) TO authenticated;

-- ============================================================
-- PART 13: ENHANCED FEEDBACK SYSTEM
-- ============================================================

-- Add new columns to service_feedback table for enhanced feedback
ALTER TABLE service_feedback ADD COLUMN IF NOT EXISTS staff_rating INTEGER;
ALTER TABLE service_feedback ADD COLUMN IF NOT EXISTS staff_behavior TEXT;
ALTER TABLE service_feedback ADD COLUMN IF NOT EXISTS staff_comment TEXT;
ALTER TABLE service_feedback ADD COLUMN IF NOT EXISTS would_recommend BOOLEAN;
ALTER TABLE service_feedback ADD COLUMN IF NOT EXISTS admin_reply TEXT;
ALTER TABLE service_feedback ADD COLUMN IF NOT EXISTS admin_reply_at TIMESTAMPTZ;
ALTER TABLE service_feedback ADD COLUMN IF NOT EXISTS editable_until TIMESTAMPTZ;
ALTER TABLE service_feedback ADD COLUMN IF NOT EXISTS feedback_type TEXT DEFAULT 'user_to_staff';

-- Create new table for staff to customer feedback
CREATE TABLE IF NOT EXISTS customer_feedback_from_staff (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    booking_id TEXT,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    behavior_type TEXT CHECK (behavior_type IN ('professional', 'friendly', 'neutral', 'rude', 'very_poor')),
    comment TEXT,
    is_positive BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cfs_staff_id ON customer_feedback_from_staff(staff_user_id);
CREATE INDEX IF NOT EXISTS idx_cfs_customer_id ON customer_feedback_from_staff(customer_id);
CREATE INDEX IF NOT EXISTS idx_cfs_created_at ON customer_feedback_from_staff(created_at DESC);

ALTER TABLE customer_feedback_from_staff ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "cfs_read_all" ON customer_feedback_from_staff;
CREATE POLICY "cfs_read_all" ON customer_feedback_from_staff 
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "cfs_insert_staff" ON customer_feedback_from_staff;
CREATE POLICY "cfs_insert_staff" ON customer_feedback_from_staff 
    FOR INSERT TO authenticated WITH CHECK (
        staff_user_id IN (SELECT id FROM user_profiles WHERE membership_tier IN ('STAFF', 'ADMIN'))
    );

-- Add customer average rating to user_profiles for staff/admin view
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS customer_rating DECIMAL(3,2) DEFAULT 0;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS total_customer_feedbacks INTEGER DEFAULT 0;

-- Function to calculate customer average rating
CREATE OR REPLACE FUNCTION public.calculate_customer_rating(p_customer_id UUID)
RETURNS TABLE(avg_rating DECIMAL, total_count INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(AVG(rating)::DECIMAL(3,2), 0)::DECIMAL(3,2) as avg_rating,
        COUNT(*)::INTEGER as total_count
    FROM customer_feedback_from_staff
    WHERE customer_id = p_customer_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_customer_rating(UUID) TO authenticated;

-- ============================================================
-- END OF ALL UPDATES
-- ============================================================
