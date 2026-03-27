-- Check Username Availability Function
-- Used during signup to validate unique usernames

CREATE OR REPLACE FUNCTION check_username_available(p_username TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM user_profiles 
        WHERE LOWER(username) = LOWER(p_username)
    ) INTO v_exists;
    
    RETURN NOT v_exists;
END;
$$;

GRANT EXECUTE ON FUNCTION check_username_available(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION check_username_available(TEXT) TO anon;
