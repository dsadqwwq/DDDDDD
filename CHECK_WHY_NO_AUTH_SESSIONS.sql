-- ============================================
-- CHECK WHY AUTH SESSIONS AREN'T WORKING
-- ============================================
-- Run this in your LIVE Supabase SQL Editor

-- 1. Check if anonymous auth provider is enabled
SELECT
  'Anonymous auth provider status' as check_name,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM auth.providers WHERE provider = 'anonymous'
    ) THEN 'Enabled ✅'
    ELSE 'DISABLED ❌ - THIS IS THE PROBLEM'
  END as status;

-- 2. Check how many auth.users exist (people with auth sessions)
SELECT
  'Total auth.users' as check_name,
  COUNT(*) as count
FROM auth.users;

-- 3. Check how many users in your users table
SELECT
  'Total users in users table' as check_name,
  COUNT(*) as count
FROM users;

-- 4. Check how many users have auth_user_id set
SELECT
  'Users with auth_user_id linked' as check_name,
  COUNT(*) as count
FROM users
WHERE auth_user_id IS NOT NULL;

-- 5. Show recent auth.users (who logged in recently)
SELECT
  'Recent auth logins (last 24 hours)' as check_name,
  COUNT(*) as count
FROM auth.users
WHERE last_sign_in_at > NOW() - INTERVAL '24 hours';

-- 6. Show sample of users without auth
SELECT
  u.id,
  u.display_name,
  u.wallet_address,
  u.auth_user_id,
  u.created_at,
  'NO AUTH SESSION' as problem
FROM users u
LEFT JOIN auth.users au ON u.auth_user_id = au.id
WHERE u.auth_user_id IS NULL
   OR au.id IS NULL
LIMIT 5;
