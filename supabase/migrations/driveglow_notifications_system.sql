-- =====================================================
-- DRIVEGLOW NOTIFICATIONS SYSTEM
-- Created: March 2026
-- =====================================================

-- Enable extension if needed
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- USER NOTIFICATION PREFERENCES TABLE
-- =====================================================
DROP TABLE IF EXISTS user_notification_preferences;

CREATE TABLE user_notification_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE,
    push_enabled BOOLEAN DEFAULT true,
    email_enabled BOOLEAN DEFAULT true,
    sms_enabled BOOLEAN DEFAULT false,
    notify_booking_complete BOOLEAN DEFAULT true,
    notify_payment_done BOOLEAN DEFAULT true,
    notify_subscription_done BOOLEAN DEFAULT true,
    notify_promotions BOOLEAN DEFAULT false,
    notify_feedback_reminders BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notification_prefs_user_id ON user_notification_preferences(user_id);

-- =====================================================
-- NOTIFICATIONS TABLE
-- =====================================================
DROP TABLE IF EXISTS user_notifications;

CREATE TABLE user_notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL,
    reference_id TEXT,
    reference_type TEXT,
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON user_notifications(user_id);
CREATE INDEX idx_notifications_created_at ON user_notifications(created_at DESC);
CREATE INDEX idx_notifications_is_read ON user_notifications(user_id) WHERE is_read = false;

-- =====================================================
-- FUNCTION: Get user notification preferences
-- =====================================================
DROP FUNCTION IF EXISTS get_notification_preferences(UUID);

CREATE FUNCTION get_notification_preferences(p_user_id UUID)
RETURNS TABLE (
    push_enabled BOOLEAN,
    email_enabled BOOLEAN,
    sms_enabled BOOLEAN,
    notify_booking_complete BOOLEAN,
    notify_payment_done BOOLEAN,
    notify_subscription_done BOOLEAN,
    notify_promotions BOOLEAN,
    notify_feedback_reminders BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(p.push_enabled, true),
        COALESCE(p.email_enabled, true),
        COALESCE(p.sms_enabled, false),
        COALESCE(p.notify_booking_complete, true),
        COALESCE(p.notify_payment_done, true),
        COALESCE(p.notify_subscription_done, true),
        COALESCE(p.notify_promotions, false),
        COALESCE(p.notify_feedback_reminders, true)
    FROM user_notification_preferences p
    WHERE p.user_id = p_user_id;
END;
$$;

-- =====================================================
-- FUNCTION: Update notification preferences
-- =====================================================
DROP FUNCTION IF EXISTS update_notification_preferences(UUID, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN);

CREATE FUNCTION update_notification_preferences(
    p_user_id UUID,
    p_push_enabled BOOLEAN DEFAULT NULL,
    p_email_enabled BOOLEAN DEFAULT NULL,
    p_sms_enabled BOOLEAN DEFAULT NULL,
    p_notify_booking_complete BOOLEAN DEFAULT NULL,
    p_notify_payment_done BOOLEAN DEFAULT NULL,
    p_notify_subscription_done BOOLEAN DEFAULT NULL,
    p_notify_promotions BOOLEAN DEFAULT NULL,
    p_notify_feedback_reminders BOOLEAN DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO user_notification_preferences (
        user_id, push_enabled, email_enabled, sms_enabled,
        notify_booking_complete, notify_payment_done, notify_subscription_done,
        notify_promotions, notify_feedback_reminders
    ) VALUES (
        p_user_id, 
        COALESCE(p_push_enabled, true),
        COALESCE(p_email_enabled, true),
        COALESCE(p_sms_enabled, false),
        COALESCE(p_notify_booking_complete, true),
        COALESCE(p_notify_payment_done, true),
        COALESCE(p_notify_subscription_done, true),
        COALESCE(p_notify_promotions, false),
        COALESCE(p_notify_feedback_reminders, true)
    )
    ON CONFLICT (user_id) DO UPDATE SET
        push_enabled = COALESCE(p_push_enabled, user_notification_preferences.push_enabled),
        email_enabled = COALESCE(p_email_enabled, user_notification_preferences.email_enabled),
        sms_enabled = COALESCE(p_sms_enabled, user_notification_preferences.sms_enabled),
        notify_booking_complete = COALESCE(p_notify_booking_complete, user_notification_preferences.notify_booking_complete),
        notify_payment_done = COALESCE(p_notify_payment_done, user_notification_preferences.notify_payment_done),
        notify_subscription_done = COALESCE(p_notify_subscription_done, user_notification_preferences.notify_subscription_done),
        notify_promotions = COALESCE(p_notify_promotions, user_notification_preferences.notify_promotions),
        notify_feedback_reminders = COALESCE(p_notify_feedback_reminders, user_notification_preferences.notify_feedback_reminders),
        updated_at = NOW();
    
    RETURN true;
END;
$$;

-- =====================================================
-- FUNCTION: Get user notifications
-- =====================================================
DROP FUNCTION IF EXISTS get_user_notifications(UUID, INT);

CREATE FUNCTION get_user_notifications(p_user_id UUID, p_limit INT DEFAULT 20)
RETURNS TABLE (
    id UUID,
    title TEXT,
    message TEXT,
    type TEXT,
    reference_id TEXT,
    reference_type TEXT,
    is_read BOOLEAN,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.id, n.title, n.message, n.type, 
        n.reference_id, n.reference_type,
        n.is_read, n.read_at, n.created_at
    FROM user_notifications n
    WHERE n.user_id = p_user_id
    ORDER BY n.created_at DESC
    LIMIT p_limit;
END;
$$;

-- =====================================================
-- FUNCTION: Mark notification as read
-- =====================================================
DROP FUNCTION IF EXISTS mark_notification_read(UUID, UUID);

CREATE FUNCTION mark_notification_read(p_notification_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE user_notifications 
    SET is_read = true, read_at = NOW()
    WHERE id = p_notification_id AND user_id = p_user_id;
    
    RETURN true;
END;
$$;

-- =====================================================
-- FUNCTION: Mark all notifications as read
-- =====================================================
DROP FUNCTION IF EXISTS mark_all_notifications_read(UUID);

CREATE FUNCTION mark_all_notifications_read(p_user_id UUID)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INT;
BEGIN
    UPDATE user_notifications 
    SET is_read = true, read_at = NOW()
    WHERE user_id = p_user_id AND is_read = false;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

-- =====================================================
-- FUNCTION: Create a notification
-- =====================================================
DROP FUNCTION IF EXISTS create_notification(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT);

CREATE FUNCTION create_notification(
    p_user_id TEXT,
    p_title TEXT,
    p_message TEXT,
    p_type TEXT,
    p_reference_id TEXT DEFAULT NULL,
    p_reference_type TEXT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_notification_id TEXT;
BEGIN
    v_notification_id := uuid_generate_v4()::TEXT;
    
    INSERT INTO user_notifications (
        id, user_id, title, message, type, reference_id, reference_type
    ) VALUES (
        v_notification_id::UUID, p_user_id::UUID, p_title, p_message, p_type, p_reference_id, p_reference_type
    );
    
    RETURN v_notification_id;
END;
$$;

-- =====================================================
-- FUNCTION: Get unread notification count
-- =====================================================
DROP FUNCTION IF EXISTS get_unread_notification_count(TEXT);

CREATE FUNCTION get_unread_notification_count(p_user_id TEXT)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM user_notifications
    WHERE user_id::TEXT = p_user_id AND is_read = false;
    
    RETURN v_count;
END;
$$;

-- =====================================================
-- Enable RLS
-- =====================================================
ALTER TABLE user_notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_notification_preferences
DROP POLICY IF EXISTS "Users can view own notification prefs" ON user_notification_preferences;
CREATE POLICY "Users can view own notification prefs" ON user_notification_preferences
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notification prefs" ON user_notification_preferences;
CREATE POLICY "Users can update own notification prefs" ON user_notification_preferences
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own notification prefs" ON user_notification_preferences;
CREATE POLICY "Users can insert own notification prefs" ON user_notification_preferences
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- RLS Policies for user_notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON user_notifications;
CREATE POLICY "Users can view own notifications" ON user_notifications
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own notifications" ON user_notifications;
CREATE POLICY "Users can insert own notifications" ON user_notifications
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON user_notifications;
CREATE POLICY "Users can update own notifications" ON user_notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- =====================================================
-- END OF NOTIFICATIONS SYSTEM
-- =====================================================
