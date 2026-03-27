-- ============================================================
-- STAFF ATTENDANCE CALENDAR & RATING SYSTEM
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Add staff_id column to service_feedback (allow staff to rate customers)
ALTER TABLE service_feedback ADD COLUMN IF NOT EXISTS staff_id UUID REFERENCES user_profiles(id);

-- 2. Create staff_attendance_calendar table
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

-- 3. Create staff_weekoff_pattern table (rotating weekoff)
CREATE TABLE IF NOT EXISTS staff_weekoff_pattern (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    day_of_week INT NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6), -- 0=Sunday
    is_weekly_off BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_weekoff_pattern_staff 
ON staff_weekoff_pattern(staff_user_id);

-- 4. Enable RLS on new tables
ALTER TABLE staff_attendance_calendar ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_weekoff_pattern ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies for staff_attendance_calendar
-- Staff can read their own attendance
DROP POLICY IF EXISTS "attendance_calendar_read_own" ON staff_attendance_calendar;
CREATE POLICY "attendance_calendar_read_own" ON staff_attendance_calendar
    FOR SELECT TO authenticated
    USING (staff_user_id = auth.uid());

-- Admin can do everything
DROP POLICY IF EXISTS "attendance_calendar_admin_full" ON staff_attendance_calendar;
CREATE POLICY "attendance_calendar_admin_full" ON staff_attendance_calendar
    FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND membership_tier = 'ADMIN'))
    WITH CHECK (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND membership_tier = 'ADMIN'));

-- Staff can insert their own attendance
DROP POLICY IF EXISTS "attendance_calendar_insert_own" ON staff_attendance_calendar;
CREATE POLICY "attendance_calendar_insert_own" ON staff_attendance_calendar
    FOR INSERT TO authenticated
    WITH CHECK (staff_user_id = auth.uid());

-- Staff can update their own attendance
DROP POLICY IF EXISTS "attendance_calendar_update_own" ON staff_attendance_calendar;
CREATE POLICY "attendance_calendar_update_own" ON staff_attendance_calendar
    FOR UPDATE TO authenticated
    USING (staff_user_id = auth.uid())
    WITH CHECK (staff_user_id = auth.uid());

-- 6. RLS Policies for staff_weekoff_pattern
DROP POLICY IF EXISTS "weekoff_pattern_read_own" ON staff_weekoff_pattern;
CREATE POLICY "weekoff_pattern_read_own" ON staff_weekoff_pattern
    FOR SELECT TO authenticated
    USING (staff_user_id = auth.uid());

DROP POLICY IF EXISTS "weekoff_pattern_admin_full" ON staff_weekoff_pattern;
CREATE POLICY "weekoff_pattern_admin_full" ON staff_weekoff_pattern
    FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND membership_tier = 'ADMIN'))
    WITH CHECK (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND membership_tier = 'ADMIN'));

-- 7. Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON staff_attendance_calendar TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON staff_weekoff_pattern TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
