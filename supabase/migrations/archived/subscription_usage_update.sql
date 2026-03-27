-- Subscription Usage Tracker & Plan Updates
-- Adds unlimited display option and usage tracking per user/plan/month

-- 1. Add new columns to subscription_plans table
ALTER TABLE subscription_plans 
ADD COLUMN IF NOT EXISTS show_unlimited BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS monthly_cap_override INTEGER;

COMMENT ON COLUMN subscription_plans.show_unlimited IS 'When true, display Unlimited washes to users instead of usage stats';
COMMENT ON COLUMN subscription_plans.monthly_cap_override IS 'Admin can override the monthly usage cap for this plan';

-- 2. Create subscription_usage_tracker table
CREATE TABLE IF NOT EXISTS subscription_usage_tracker (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
    year_month TEXT NOT NULL,  -- Format: "2026-03"
    usage_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, plan_id, year_month)
);

-- Index for efficient queries
CREATE INDEX IF NOT EXISTS idx_usage_tracker_user_plan_month 
ON subscription_usage_tracker(user_id, plan_id, year_month);

-- Enable RLS
ALTER TABLE subscription_usage_tracker ENABLE ROW LEVEL SECURITY;

-- RLS Policies for usage tracker
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

-- Admin full access
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

-- 3. Function to increment usage with auto-month-reset
CREATE OR REPLACE FUNCTION increment_usage_count(
    p_user_id UUID,
    p_plan_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_year_month TEXT;
    v_current_count INTEGER;
BEGIN
    v_year_month := to_char(NOW(), 'YYYY-MM');
    
    -- Get current count
    SELECT usage_count INTO v_current_count
    FROM subscription_usage_tracker
    WHERE user_id = p_user_id 
        AND plan_id = p_plan_id 
        AND year_month = v_year_month;
    
    IF v_current_count IS NULL THEN
        -- Insert new record
        INSERT INTO subscription_usage_tracker (user_id, plan_id, year_month, usage_count)
        VALUES (p_user_id, p_plan_id, v_year_month, 1)
        ON CONFLICT (user_id, plan_id, year_month) 
        DO UPDATE SET usage_count = 1, updated_at = NOW();
    ELSE
        -- Increment existing
        UPDATE subscription_usage_tracker
        SET usage_count = v_current_count + 1, updated_at = NOW()
        WHERE user_id = p_user_id 
            AND plan_id = p_plan_id 
            AND year_month = v_year_month;
    END IF;
END;
$$;

-- 4. Function to get current month usage
CREATE OR REPLACE FUNCTION get_current_month_usage(
    p_user_id UUID,
    p_plan_id UUID
)
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

-- 5. Function to reset usage (for admin)
CREATE OR REPLACE FUNCTION reset_monthly_usage(
    p_user_id UUID,
    p_plan_id UUID,
    p_year_month TEXT,
    p_count INTEGER DEFAULT 0
)
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

-- 6. Function to get plan's effective cap
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
    -- Check for admin override
    SELECT monthly_cap_override INTO v_override
    FROM subscription_plans
    WHERE id = p_plan_id;
    
    IF v_override IS NOT NULL AND v_override > 0 THEN
        RETURN v_override;
    END IF;
    
    -- Parse from frequency_limit (e.g., "2 Washes/Month" -> 2)
    SELECT frequency_limit INTO v_frequency
    FROM subscription_plans
    WHERE id = p_plan_id;
    
    IF v_frequency IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Extract number from string
    v_limit := (regexp_match(v_frequency, '(\d+)'))[1]::INTEGER;
    RETURN v_limit;
END;
$$;
