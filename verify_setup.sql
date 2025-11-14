-- Quick verification: Check if registration will work
-- Run this in Supabase SQL Editor

SELECT
  -- Check tables exist
  (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'users') as users_table_exists,
  (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'codes') as codes_table_exists,

  -- Check function exists
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'create_user_codes') as function_exists,

  -- Check available codes
  (SELECT COUNT(*) FROM codes WHERE used_by IS NULL) as available_codes,

  -- Check users count
  (SELECT COUNT(*) FROM users) as total_users;

-- If you see:
-- users_table_exists: 1
-- codes_table_exists: 1
-- function_exists: 1
-- available_codes: 20 (or any number > 0)
-- total_users: 0 (or any number)
--
-- Then you're READY TO GO! ✅
