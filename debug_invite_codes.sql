-- =====================================================
-- DEBUG INVITE CODES
-- =====================================================
-- Run this to see what's in the database

-- Check if table exists
SELECT
  'Table exists: ' || CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'invite_codes')
    THEN 'YES ✓'
    ELSE 'NO ✗'
  END as status;

-- Check if functions exist
SELECT
  'Functions installed:' as check,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'validate_invite_code') as validate_fn,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'create_user_invite_code') as create_fn,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'generate_invite_code') as generate_fn;

-- Show ALL codes in the table (bypass RLS)
SELECT
  'All codes in database:' as info;

SELECT
  code,
  creator_user_id,
  used_by_user_id,
  is_used,
  created_at
FROM invite_codes
ORDER BY created_at DESC;

-- Try to validate BOOT-STRA-P001
SELECT
  'Testing BOOT-STRA-P001 validation:' as test;

SELECT * FROM validate_invite_code('BOOT-STRA-P001');

-- Check if the code exists with exact match
SELECT
  'Direct code lookup:' as lookup,
  COUNT(*) as found
FROM invite_codes
WHERE code = 'BOOT-STRA-P001';

-- Check users table
SELECT
  'Users in database:' as info,
  COUNT(*) as user_count
FROM users;
