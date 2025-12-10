-- ============================================
-- FIX USERS WITH NULL auth_user_id
-- ============================================
-- This fixes GC not updating for some users
-- Run this in Supabase SQL Editor

-- 1. Check how many users have NULL auth_user_id
SELECT
  COUNT(*) as total_users,
  COUNT(auth_user_id) as users_with_auth,
  COUNT(*) - COUNT(auth_user_id) as users_without_auth
FROM users;

-- 2. Show users without auth_user_id (these users will have GC update issues)
SELECT id, display_name, wallet_address, gc_balance, auth_user_id, created_at
FROM users
WHERE auth_user_id IS NULL
ORDER BY created_at DESC
LIMIT 20;

-- 3. FIX: Link auth sessions to users by matching user IDs
-- This assumes auth.users.id matches users.id for users created via anonymous auth
UPDATE users
SET auth_user_id = id
WHERE auth_user_id IS NULL;

-- 4. Verify the fix
SELECT
  COUNT(*) as total_users,
  COUNT(auth_user_id) as users_with_auth,
  COUNT(*) - COUNT(auth_user_id) as users_still_broken
FROM users;
