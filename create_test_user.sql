-- =====================================================
-- CREATE TEST USER FOR DATABASE TESTING
-- =====================================================
-- Run this AFTER running add_gp_balance_system.sql
-- This creates a test user you can login with

-- First, make sure the main migration has been run
-- If you get errors, run add_gp_balance_system.sql first!

-- Create test user with known credentials
INSERT INTO users (id, email, display_name, gp_balance, points, level, total_wins, win_streak)
VALUES (
  '00000000-0000-0000-0000-000000000001'::uuid,
  'test@duelpvp.com',
  'TestWarrior',
  5000,  -- Starting GP balance
  0,
  1,
  0,
  0
)
ON CONFLICT (email) DO UPDATE
SET gp_balance = 5000,
    display_name = 'TestWarrior';

-- Create a code for this test user (so they have invite codes)
INSERT INTO codes (code, created_by, used_by)
VALUES
  ('DBTEST01', '00000000-0000-0000-0000-000000000001'::uuid, null),
  ('DBTEST02', '00000000-0000-0000-0000-000000000001'::uuid, null),
  ('DBTEST03', '00000000-0000-0000-0000-000000000001'::uuid, null)
ON CONFLICT (code) DO NOTHING;

-- Verify test user was created
SELECT
  'Test user created successfully!' as status,
  id,
  email,
  display_name,
  gp_balance,
  (SELECT COUNT(*) FROM codes WHERE created_by = id) as invite_codes_created
FROM users
WHERE email = 'test@duelpvp.com';

-- =====================================================
-- TEST USER CREDENTIALS
-- =====================================================
-- Email: test@duelpvp.com
-- No password needed - this is for testing the GP database system
--
-- To use this test user in your app, modify handleLogin() to use:
--   localStorage.setItem('duelpvp_user_id', '00000000-0000-0000-0000-000000000001');
--   localStorage.setItem('duelpvp_email', 'test@duelpvp.com');
-- =====================================================
