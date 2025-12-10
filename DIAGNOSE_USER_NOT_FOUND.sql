-- ============================================
-- DIAGNOSE "USER NOT FOUND" ERRORS
-- ============================================
-- Run this in your LIVE Supabase SQL Editor

-- Step 1: Check total users
SELECT 'Total users in database' as check_name, COUNT(*) as count FROM users;

-- Step 2: Check how many users have auth_user_id set
SELECT
  'Users with auth_user_id' as check_name,
  COUNT(*) as count
FROM users
WHERE auth_user_id IS NOT NULL;

-- Step 3: Check how many auth.users exist (actual Supabase auth accounts)
SELECT 'Total auth users' as check_name, COUNT(*) as count FROM auth.users;

-- Step 4: Show users with mismatched auth_user_id (this causes "user not found")
SELECT
  'Users with INVALID auth_user_id' as issue,
  u.id,
  u.display_name,
  u.auth_user_id,
  CASE
    WHEN au.id IS NULL THEN 'Auth user does not exist'
    ELSE 'OK'
  END as problem
FROM users u
LEFT JOIN auth.users au ON au.id = u.auth_user_id
WHERE u.auth_user_id IS NOT NULL
  AND au.id IS NULL
LIMIT 10;

-- Step 5: Show auth users without corresponding users table entry
SELECT
  'Auth users without database entry' as issue,
  au.id,
  au.email,
  au.created_at
FROM auth.users au
LEFT JOIN users u ON u.auth_user_id = au.id OR u.id = au.id
WHERE u.id IS NULL
LIMIT 10;

-- Step 6: Check a specific user (replace with actual user_id if you have one)
-- SELECT
--   u.id,
--   u.display_name,
--   u.auth_user_id,
--   u.gc_balance,
--   au.id as actual_auth_id,
--   au.email
-- FROM users u
-- LEFT JOIN auth.users au ON au.id = u.auth_user_id
-- WHERE u.display_name = 'PUT_USERNAME_HERE';
