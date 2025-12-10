-- ============================================
-- SIMPLE AUTH CHECK
-- ============================================

-- 1. How many auth.users exist?
SELECT 'Total auth.users' as check_name, COUNT(*) as count FROM auth.users;

-- 2. How many users in users table?
SELECT 'Total users' as check_name, COUNT(*) as count FROM users;

-- 3. How many users have auth_user_id?
SELECT 'Users with auth_user_id' as check_name, COUNT(*) as count
FROM users WHERE auth_user_id IS NOT NULL;

-- 4. Sample of auth.users to see what's there
SELECT id, email, created_at, last_sign_in_at
FROM auth.users
ORDER BY last_sign_in_at DESC NULLS LAST
LIMIT 5;
