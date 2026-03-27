-- ============================================================================
-- TESTING QUERIES
-- Purpose: One-time test queries and data seeding for testing purposes
-- IMPORTANT: Run these queries only for testing, then disable or delete
-- ============================================================================

-- ============================================================================
-- TEST 1: View all subscription bookings for a user
-- ============================================================================
-- Replace 'USER_ID_HERE' with actual user ID
/*
SELECT 
    b.id,
    b.vehicle_number,
    b.status,
    b.created_at,
    b.is_subscription_booking,
    b.plan_id,
    sp.name as plan_name,
    sp.duration
FROM bookings b
LEFT JOIN subscription_plans sp ON b.plan_id = sp.id
WHERE b.user_id = 'USER_ID_HERE'
ORDER BY b.created_at DESC;
*/

-- ============================================================================
-- TEST 2: Check subscription usage per service
-- ============================================================================
/*
SELECT 
    b.vehicle_number,
    b.service_id,
    b.status,
    b.created_at
FROM bookings b
WHERE b.user_id = 'USER_ID_HERE'
    AND b.service_id LIKE '%subscription_service%'
    AND b.status NOT IN ('cancelled')
ORDER BY b.created_at DESC;
*/

-- ============================================================================
-- TEST 3: View subscription plans with service limits
-- ============================================================================
/*
SELECT 
    name,
    duration,
    price,
    service_usage_limits,
    daily_limit,
    fair_usage_policy
FROM subscription_plans
WHERE is_active = true;
*/

-- ============================================================================
-- TEST 4: Check daily booking limit for a vehicle
-- ============================================================================
/*
SELECT COUNT(*) as today_bookings
FROM bookings 
WHERE user_id = 'USER_ID_HERE'
    AND vehicle_number = 'ABC 123'
    AND created_at >= CURRENT_DATE
    AND status NOT IN ('cancelled', 'lapsed');
*/

-- ============================================================================
-- TEST 5: Reset test user data (use with caution)
-- ============================================================================
/*
-- Delete test bookings for a user
DELETE FROM bookings WHERE user_id = 'USER_ID_HERE';

-- Reset subscription status (set to lapsed)
UPDATE bookings 
SET status = 'lapsed' 
WHERE user_id = 'USER_ID_HERE' 
    AND is_subscription_booking = true 
    AND status IN ('pending', 'confirmed');
*/

-- ============================================================================
-- TEST 6: Seed test subscription plan
-- ============================================================================
/*
INSERT INTO subscription_plans (
    name,
    tier,
    vehicle_category,
    duration,
    price,
    original_price,
    frequency_limit,
    description,
    features,
    included_service_ids,
    is_featured,
    is_active,
    display_order,
    service_usage_limits,
    daily_limit,
    fair_usage_policy
) VALUES (
    'Test Monthly Plan',
    'Silver',
    'Sedan',
    'Monthly',
    299,
    399,
    '4 Washes/Month',
    'Test subscription plan',
    ARRAY['Exterior Wash', 'Interior Cleaning'],
    ARRAY[]::uuid[],
    false,
    true,
    0,
    '{"service_id_1": 4, "service_id_2": 2}'::jsonb,
    1,
    'Test fair usage policy'
) ON CONFLICT DO NOTHING;
*/

-- ============================================================================
-- TEST 7: View all vehicles for a user
-- ============================================================================
/*
SELECT 
    id,
    model,
    license_plate,
    color,
    is_primary,
    created_at
FROM user_vehicles
WHERE user_id = 'USER_ID_HERE'
ORDER BY is_primary DESC, created_at DESC;
*/

-- ============================================================================
-- END OF TESTING QUERIES
-- ============================================================================
