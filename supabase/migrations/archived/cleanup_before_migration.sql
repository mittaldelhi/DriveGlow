-- ================================================================
-- CLEANUP: Drop old unused tables before running migrations
-- Run this FIRST if you have issues with duplicate objects
-- ================================================================

-- Drop old staff tables (replaced by unified user_profiles system)
DROP TABLE IF EXISTS public.staff_roles CASCADE;
DROP TABLE IF EXISTS public.staff_users CASCADE;

-- Drop any duplicate indexes that might cause conflicts
DROP INDEX IF EXISTS public.idx_coupons_code;
DROP INDEX IF EXISTS public.idx_coupons_status;
DROP INDEX IF EXISTS public.idx_coupons_valid_until;

-- ================================================================
-- Then run:
-- 1. driveglow_master_schema.sql
-- 2. driveglow_all_updates.sql
-- ================================================================
