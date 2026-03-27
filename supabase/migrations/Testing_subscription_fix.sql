-- ============================================================================
-- SUBSCRIPTION SYSTEM ENHANCEMENT - Test Migration
-- Run this in Supabase SQL Editor to fix foreign key constraint issue
-- ============================================================================

-- ============================================================================
-- 1. Create user_subscriptions table (stores plan snapshot)
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id UUID REFERENCES subscription_plans(id),
    
    plan_name TEXT NOT NULL,
    plan_tier TEXT NOT NULL DEFAULT 'Silver',
    vehicle_category TEXT NOT NULL DEFAULT 'Sedan',
    duration TEXT NOT NULL,
    price_paid NUMERIC(10,2) NOT NULL,
    features TEXT[] DEFAULT array[]::text[],
    included_service_ids UUID[] DEFAULT array[]::uuid[],
    service_usage_limits JSONB DEFAULT '{}'::jsonb,
    
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_until TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    auto_renew BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user ON user_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_valid ON user_subscriptions(valid_from, valid_until);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_active ON user_subscriptions(is_active);

-- ============================================================================
-- 2. Add user_subscription_id to bookings table
-- ============================================================================

ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS user_subscription_id UUID REFERENCES user_subscriptions(id);

CREATE INDEX IF NOT EXISTS idx_bookings_user_subscription ON bookings(user_subscription_id);

-- ============================================================================
-- 3. Grant permissions
-- ============================================================================

GRANT SELECT ON user_subscriptions TO authenticated;
GRANT SELECT ON user_subscriptions TO anon;
GRANT ALL ON user_subscriptions TO authenticated;
GRANT ALL ON user_subscriptions TO service_role;

-- ============================================================================
-- 4. RLS Policies
-- ============================================================================

ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_subscriptions_own" ON user_subscriptions;
CREATE POLICY "user_subscriptions_own" ON user_subscriptions
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "user_subscriptions_insert_own" ON user_subscriptions;
CREATE POLICY "user_subscriptions_insert_own" ON user_subscriptions
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "user_subscriptions_admin" ON user_subscriptions;
CREATE POLICY "user_subscriptions_admin" ON user_subscriptions
    FOR ALL TO authenticated
    USING (
        EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND membership_tier = 'ADMIN')
    );

-- ============================================================================
-- 5. Migrate existing subscription bookings (ONE-TIME)
-- ============================================================================

INSERT INTO user_subscriptions (
    user_id,
    plan_id,
    plan_name,
    plan_tier,
    vehicle_category,
    duration,
    price_paid,
    features,
    included_service_ids,
    valid_from,
    valid_until,
    is_active,
    auto_renew
)
SELECT 
    b.user_id,
    b.plan_id,
    COALESCE(sp.name, 'Unknown Plan'),
    COALESCE(sp.tier, 'Silver'),
    COALESCE(sp.vehicle_category, 'Sedan'),
    COALESCE(sp.duration, 'Monthly'),
    COALESCE(sp.price, 0),
    COALESCE(sp.features, array[]::text[]),
    COALESCE(sp.included_service_ids, array[]::uuid[]),
    b.created_at,
    CASE WHEN sp.duration = 'Yearly' THEN b.created_at + INTERVAL '1 year' ELSE b.created_at + INTERVAL '1 month' END,
    CASE WHEN b.status IN ('pending', 'confirmed', 'inProgress') THEN TRUE ELSE FALSE END,
    FALSE
FROM bookings b
LEFT JOIN subscription_plans sp ON b.plan_id = sp.id
WHERE b.is_subscription_booking = TRUE AND b.plan_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- Update bookings to reference user_subscriptions
UPDATE bookings b
SET user_subscription_id = us.id
FROM user_subscriptions us
WHERE b.plan_id = us.plan_id AND b.user_id = us.user_id
  AND b.is_subscription_booking = TRUE AND b.user_subscription_id IS NULL;

-- ============================================================================
-- 6. Remove frequency_limit column from subscription_plans
-- ============================================================================

ALTER TABLE subscription_plans DROP COLUMN IF EXISTS frequency_limit;

-- ============================================================================
-- 7. Make plan_id nullable in bookings (keep for backward compat)
-- ============================================================================

ALTER TABLE bookings ALTER COLUMN plan_id DROP NOT NULL;

-- ============================================================================
-- DONE
-- ============================================================================
