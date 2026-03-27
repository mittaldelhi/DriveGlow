-- ================================================================
-- BACKUP: Old Staff Tables (Before Unified System)
-- Date: 2026-03-08
-- These tables have been replaced by the unified user_profiles system
-- ================================================================

-- Backup staff_roles
CREATE TABLE IF NOT EXISTS backup_staff_roles AS 
SELECT * FROM staff_roles WHERE 1=1;

-- Backup staff_users
CREATE TABLE IF NOT EXISTS backup_staff_users AS 
SELECT * FROM staff_users WHERE 1=1;

-- Backup attendance_logs
CREATE TABLE IF NOT EXISTS backup_attendance_logs AS 
SELECT * FROM attendance_logs WHERE 1=1;

-- Backup service_logs
CREATE TABLE IF NOT EXISTS backup_service_logs AS 
SELECT * FROM service_logs WHERE 1=1;

-- Backup job_assignments
CREATE TABLE IF NOT EXISTS backup_job_assignments AS 
SELECT * FROM job_assignments WHERE 1=1;

-- ================================================================
-- END BACKUP
-- ================================================================
