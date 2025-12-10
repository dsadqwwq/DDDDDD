-- ============================================
-- CLEANUP ORPHANED AUTH SESSIONS
-- ============================================
-- Optional: Remove auth.users that have no corresponding user record
-- These are incomplete registrations

-- Show how many will be deleted
SELECT
  'Orphaned auth sessions to delete' as info,
  COUNT(*) as count
FROM auth.users au
LEFT JOIN users u ON u.auth_user_id = au.id OR u.id = au.id
WHERE u.id IS NULL;

-- UNCOMMENT TO DELETE (be careful!)
-- DELETE FROM auth.users
-- WHERE id IN (
--   SELECT au.id
--   FROM auth.users au
--   LEFT JOIN users u ON u.auth_user_id = au.id OR u.id = au.id
--   WHERE u.id IS NULL
-- );
