-- ============================================
-- CHECK IF AUTH USERS ARE LINKED TO USERS TABLE
-- ============================================

-- Show these recent auth users and their link to users table
SELECT
  au.id as auth_user_id,
  au.last_sign_in_at,
  u.id as user_id,
  u.display_name,
  u.auth_user_id as stored_auth_user_id,
  CASE
    WHEN u.id IS NULL THEN '❌ NO USER RECORD'
    WHEN u.auth_user_id IS NULL THEN '❌ auth_user_id IS NULL'
    WHEN u.auth_user_id != au.id THEN '❌ MISMATCH'
    ELSE '✅ OK'
  END as status
FROM auth.users au
LEFT JOIN users u ON u.auth_user_id = au.id OR u.id = au.id
WHERE au.last_sign_in_at > NOW() - INTERVAL '2 hours'
ORDER BY au.last_sign_in_at DESC
LIMIT 10;
