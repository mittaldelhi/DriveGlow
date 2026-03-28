-- ============================================================================
-- SUBSCRIPTION VEHICLE FIX
-- Run this in Supabase SQL Editor
-- ============================================================================

-- ============================================================================
-- 1. Add vehicle columns to user_subscriptions table
-- ============================================================================

ALTER TABLE user_subscriptions ADD COLUMN IF NOT EXISTS vehicle_number TEXT;
ALTER TABLE user_subscriptions ADD COLUMN IF NOT EXISTS vehicle_id UUID;

CREATE INDEX IF NOT EXISTS idx_user_subscriptions_vehicle ON user_subscriptions(vehicle_number);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_vehicle ON user_subscriptions(user_id, vehicle_number);

-- ============================================================================
-- 2. Migrate existing subscription bookings to user_subscriptions
-- ============================================================================

INSERT INTO user_subscriptions (
    id,
    user_id,
    plan_id,
    vehicle_number,
    vehicle_id,
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
    auto_renew,
    created_at,
    updated_at
)
SELECT 
    gen_random_uuid(),
    b.user_id,
    b.plan_id,
    b.vehicle_number,
    b.vehicle_id,
    COALESCE(sp.name, 'Unknown Plan'),
    COALESCE(sp.tier, 'Silver'),
    COALESCE(sp.vehicle_category, 'Sedan'),
    COALESCE(sp.duration, 'Monthly'),
    COALESCE(b.total_price, 0),
    COALESCE(sp.features, array[]::text[]),
    COALESCE(sp.included_service_ids, array[]::uuid[]),
    b.created_at,
    COALESCE(
        b.subscription_period_end,
        CASE 
            WHEN LOWER(COALESCE(sp.duration, '')) LIKE '%year%' THEN b.created_at + INTERVAL '1 year'
            ELSE b.created_at + INTERVAL '1 month'
        END
    ),
    CASE 
        WHEN b.status IN ('pending', 'confirmed', 'in_progress') THEN true 
        ELSE false 
    END,
    false,
    b.created_at,
    NOW()
FROM bookings b
LEFT JOIN subscription_plans sp ON b.plan_id = sp.id
WHERE (b.is_subscription_booking = true 
   OR b.service_id LIKE 'subscription::%'
   OR b.service_id LIKE 'subscription_service::%')
AND b.vehicle_number IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM user_subscriptions us 
    WHERE us.user_id = b.user_id 
    AND us.plan_id = b.plan_id 
    AND us.vehicle_number = b.vehicle_number
    AND us.valid_from = b.created_at
);

-- ============================================================================
-- 3. Update existing user_subscriptions without vehicle_number
-- ============================================================================

UPDATE user_subscriptions us
SET vehicle_number = b.vehicle_number,
    vehicle_id = b.vehicle_id,
    updated_at = NOW()
FROM bookings b
WHERE us.plan_id = b.plan_id 
  AND us.user_id = b.user_id
  AND us.vehicle_number IS NULL
  AND b.vehicle_number IS NOT NULL
  AND (b.is_subscription_booking = true 
   OR b.service_id LIKE 'subscription::%'
   OR b.service_id LIKE 'subscription_service::%');

-- ============================================================================
-- 4. Fix is_active based on valid_until (correct logic)
-- ============================================================================

UPDATE user_subscriptions
SET is_active = (valid_until > NOW()),
    updated_at = NOW()
WHERE vehicle_number IS NOT NULL;

-- ============================================================================
-- 5. Verify data
-- ============================================================================

SELECT 
    vehicle_number,
    COUNT(*) as total_booking_services,
    BOOL_OR(valid_until > NOW()) as has_active,
    MIN(valid_until) as earliest_expiry,
    MAX(valid_until) as latest_expiry
FROM user_subscriptions 
WHERE vehicle_number IS NOT NULL
GROUP BY vehicle_number
ORDER BY vehicle_number;
