-- Feedback Ticket System
-- Adds ticket generation for complaints with priority and status tracking

-- 1. Add new columns to service_feedback table
ALTER TABLE service_feedback 
ADD COLUMN IF NOT EXISTS staff_id UUID REFERENCES user_profiles(id),
ADD COLUMN IF NOT EXISTS is_complaint BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS ticket_number TEXT,
ADD COLUMN IF NOT EXISTS ticket_status TEXT DEFAULT 'open' CHECK (ticket_status IN ('open', 'in_progress', 'resolved', 'closed')),
ADD COLUMN IF NOT EXISTS ticket_priority TEXT DEFAULT 'normal' CHECK (ticket_priority IN ('normal', 'high')),
ADD COLUMN IF NOT EXISTS admin_notes TEXT,
ADD COLUMN IF NOT EXISTS feedback_updated_at TIMESTAMPTZ;

COMMENT ON COLUMN service_feedback.staff_id IS 'Staff member who served this customer';
COMMENT ON COLUMN service_feedback.is_complaint IS 'True if customer marked this as a complaint';
COMMENT ON COLUMN service_feedback.ticket_number IS 'Auto-generated ticket number (e.g., TKT-20260307-0001)';
COMMENT ON COLUMN service_feedback.ticket_status IS 'Ticket workflow status';
COMMENT ON COLUMN service_feedback.ticket_priority IS 'Priority level - high for complaints';
COMMENT ON COLUMN service_feedback.admin_notes IS 'Internal notes from admin';
COMMENT ON COLUMN service_feedback.feedback_updated_at IS 'Last update timestamp for feedback';

-- 2. Create ticket counter table for generating sequential ticket numbers
CREATE TABLE IF NOT EXISTS ticket_counter (
    id INTEGER PRIMARY KEY DEFAULT 1,
    last_date TEXT,  -- Format: YYYYMMDD
    sequence_num INTEGER DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Initialize with default row
INSERT INTO ticket_counter (id, last_date, sequence_num)
VALUES (1, '', 0)
ON CONFLICT (id) DO NOTHING;

-- 3. Function to generate ticket number
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_today TEXT;
    v_sequence INTEGER;
    v_ticket_number TEXT;
BEGIN
    v_today := to_char(NOW(), 'YYYYMMDD');
    
    -- Get current sequence
    SELECT sequence_num INTO v_sequence
    FROM ticket_counter
    WHERE id = 1;
    
    -- Reset if new day
    IF last_date != v_today THEN
        v_sequence := 0;
    END IF;
    
    -- Increment
    v_sequence := v_sequence + 1;
    
    -- Generate ticket number: TKT-YYYYMMDD-XXXX
    v_ticket_number := 'TKT-' || v_today || '-' || LPAD(v_sequence::TEXT, 4, '0');
    
    -- Update counter
    UPDATE ticket_counter
    SET last_date = v_today, sequence_num = v_sequence, updated_at = NOW()
    WHERE id = 1;
    
    RETURN v_ticket_number;
END;
$$;

-- 4. Function to save feedback with ticket generation
CREATE OR REPLACE FUNCTION save_feedback_with_ticket(
    p_booking_id TEXT,
    p_user_id UUID,
    p_rating NUMERIC(3,1),
    p_comment TEXT,
    p_tags TEXT[],
    p_is_complaint BOOLEAN DEFAULT FALSE,
    p_staff_id UUID DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_feedback_id TEXT;
    v_ticket_number TEXT;
BEGIN
    -- Generate feedback ID
    v_feedback_id := 'fb_' || gen_random_uuid()::TEXT;
    
    -- Generate ticket if complaint
    IF p_is_complaint = TRUE THEN
        v_ticket_number := generate_ticket_number();
    END IF;
    
    -- Insert feedback
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
    )
    ON CONFLICT (booking_id) DO UPDATE SET
        rating = p_rating,
        comment = p_comment,
        tags = p_tags,
        is_complaint = p_is_complaint,
        staff_id = COALESCE(p_staff_id, service_feedback.staff_id),
        feedback_updated_at = NOW();
    
    RETURN v_feedback_id;
END;
$$;

-- 5. Function to update ticket status (admin)
CREATE OR REPLACE FUNCTION update_ticket_status(
    p_feedback_id TEXT,
    p_status TEXT,
    p_admin_notes TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE service_feedback
    SET ticket_status = p_status,
        admin_notes = COALESCE(p_admin_notes, admin_notes),
        feedback_updated_at = NOW()
    WHERE id = p_feedback_id
        AND ticket_number IS NOT NULL;
END;
$$;

-- 6. Function to get all tickets (for admin)
CREATE OR REPLACE FUNCTION get_all_tickets()
RETURNS TABLE (
    id TEXT,
    booking_id TEXT,
    user_id UUID,
    rating NUMERIC(3,1),
    comment TEXT,
    tags TEXT[],
    is_complaint BOOLEAN,
    ticket_number TEXT,
    ticket_status TEXT,
    ticket_priority TEXT,
    admin_notes TEXT,
    created_at TIMESTAMPTZ,
    feedback_updated_at TIMESTAMPTZ,
    customer_name TEXT,
    service_name TEXT,
    staff_name TEXT
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
    ORDER BY 
        CASE fb.ticket_priority 
            WHEN 'high' THEN 1 
            ELSE 2 
        END,
        fb.created_at DESC;
END;
$$;

-- 7. Create indexes for ticket queries
CREATE INDEX IF NOT EXISTS idx_feedback_ticket_number ON service_feedback(ticket_number) WHERE ticket_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_feedback_ticket_status ON service_feedback(ticket_status) WHERE ticket_status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_feedback_ticket_priority ON service_feedback(ticket_priority) WHERE ticket_priority IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_feedback_is_complaint ON service_feedback(is_complaint) WHERE is_complaint = TRUE;

-- 8. Create view for admin dashboard - complaint stats
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
