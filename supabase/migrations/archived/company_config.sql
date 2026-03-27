-- ============================================================
-- COMPANY CONFIG - About Us & Contact
-- Run this in Supabase SQL Editor
-- ============================================================

INSERT INTO app_config (key, value) VALUES
  ('company_about', 'DriveGlow is a premium car wash and detailing service with advanced technology and expert professionals. We provide the best care for your vehicle.'),
  ('company_address', 'Drive Glow studio, Besides Hari Ram Hospital, Bhiwadi, Rajasthan, India 301019'),
  ('company_phone', '9999081105'),
  ('company_email', 'contact@driveglow.com'),
  ('company_openhours', 'Mon-Sat: 9:00 AM - 7:00 PM')
ON CONFLICT (key) DO NOTHING;
