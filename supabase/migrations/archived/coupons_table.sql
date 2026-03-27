-- Coupons/Promos Management System
-- Create coupons table for promo codes

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

-- Index for fast lookups
CREATE INDEX idx_coupons_code ON public.coupons(code);
CREATE INDEX idx_coupons_status ON public.coupons(status);
CREATE INDEX idx_coupons_valid_until ON public.coupons(valid_until);

-- Enable RLS
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS coupons_read_all ON public.coupons;
CREATE POLICY coupons_read_all ON public.coupons FOR SELECT USING (true);

DROP POLICY IF EXISTS coupons_write_admin ON public.coupons;
CREATE POLICY coupons_write_admin ON public.coupons FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_profiles up 
        WHERE up.id = auth.uid() 
        AND up.membership_tier = 'ADMIN'
    )
);

-- Function to get active coupons for users
CREATE OR REPLACE FUNCTION get_active_coupons()
RETURNS TABLE (
    id UUID,
    code TEXT,
    description TEXT,
    type TEXT,
    value NUMERIC,
    min_purchase_amount NUMERIC,
    max_discount_amount NUMERIC,
    valid_until TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.code,
        c.description,
        c.type,
        c.value,
        c.min_purchase_amount,
        c.max_discount_amount,
        c.valid_until
    FROM coupons c
    WHERE c.status = 'active'
        AND c.valid_from <= NOW()
        AND c.valid_until >= NOW()
        AND (c.usage_limit = -1 OR c.usage_count < c.usage_limit)
    ORDER BY c.created_at DESC;
END;
$$;

-- Function to validate and apply coupon
CREATE OR REPLACE FUNCTION validate_coupon(
    p_code TEXT,
    p_purchase_amount NUMERIC
)
RETURNS TABLE (
    is_valid BOOLEAN,
    discount_amount NUMERIC,
    coupon_id UUID,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_coupon RECORD;
    v_discount NUMERIC := 0;
BEGIN
    -- Find coupon
    SELECT * INTO v_coupon
    FROM coupons
    WHERE code = p_code
        AND status = 'active'
        AND valid_from <= NOW()
        AND valid_until >= NOW()
        AND (usage_limit = -1 OR usage_count < usage_limit);

    IF v_coupon IS NULL THEN
        RETURN QUERY SELECT false, 0::NUMERIC, NULL::UUID, 'Invalid or expired coupon';
        RETURN;
    END IF;

    -- Check minimum purchase
    IF p_purchase_amount < v_coupon.min_purchase_amount THEN
        RETURN QUERY SELECT false, 0::NUMERIC, v_coupon.id, 
            'Minimum purchase of ₹' || v_coupon.min_purchase_amount || ' required';
        RETURN;
    END IF;

    -- Calculate discount
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

-- Function to increment coupon usage after successful payment
CREATE OR REPLACE FUNCTION use_coupon(p_coupon_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE coupons
    SET usage_count = usage_count + 1,
        updated_at = NOW()
    WHERE id = p_coupon_id;
END;
$$;

-- Insert some sample coupons
INSERT INTO coupons (code, description, type, value, min_purchase_amount, max_discount_amount, valid_from, valid_until, status)
VALUES 
    ('WELCOME50', 'Welcome Offer - ₹50 off', 'fixed_amount', 50, 500, 50, NOW(), NOW() + INTERVAL '90 days', 'active'),
    ('SAVE10', '10% off on all services', 'percentage', 10, 0, 200, NOW(), NOW() + INTERVAL '30 days', 'active'),
    ('PREMIUM200', '₹200 off for premium plans', 'fixed_amount', 200, 2000, 200, NOW(), NOW() + INTERVAL '60 days', 'active')
ON CONFLICT (code) DO NOTHING;
