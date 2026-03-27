-- ============================================================
-- UNIFIED USER & STAFF SYSTEM
-- Single migration to replace staff_management.sql and unified_login_system.sql
-- Run this AFTER driveglow_master_schema.sql
-- ============================================================

-- ============================================================
-- PART 1: CLEANUP - Drop old staff tables
-- ============================================================
DROP TABLE IF EXISTS staff_users CASCADE;
DROP TABLE IF EXISTS staff_roles CASCADE;

-- ============================================================
-- PART 2: Update user_profiles with new columns
-- ============================================================
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS username TEXT UNIQUE;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS employee_id TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_username 
ON user_profiles(username) WHERE username IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_employee_id 
ON user_profiles(employee_id) WHERE employee_id IS NOT NULL;

-- ============================================================
-- PART 3: RLS Functions
-- ============================================================
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

-- ============================================================
-- PART 4: Login & Table Permissions
-- ============================================================
GRANT SELECT ON user_profiles TO authenticated;
GRANT SELECT ON user_profiles TO anon;

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

-- ============================================================
-- PART 5: Staff Requests Table (updated to use user_profiles)
-- ============================================================
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
