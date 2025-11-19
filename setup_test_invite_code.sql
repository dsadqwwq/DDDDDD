-- =====================================================
-- SETUP TEST INVITE CODE
-- =====================================================
-- Run this after create_invite_system.sql to create a test code

-- First, check if invite_codes table exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'invite_codes') THEN
    RAISE EXCEPTION 'invite_codes table does not exist. Run create_invite_system.sql first!';
  END IF;
END $$;

-- Create a test user if one doesn't exist
DO $$
DECLARE
  v_test_user_id uuid;
BEGIN
  -- Try to get an existing user
  SELECT id INTO v_test_user_id
  FROM users
  LIMIT 1;

  IF v_test_user_id IS NULL THEN
    RAISE EXCEPTION 'No users found in database. Create a user first!';
  END IF;

  -- Delete any existing test code
  DELETE FROM invite_codes WHERE code = 'TEST-CODE-0001';

  -- Create test invite code
  INSERT INTO invite_codes (code, creator_user_id, is_used)
  VALUES ('TEST-CODE-0001', v_test_user_id, false);

  RAISE NOTICE 'Test code created: TEST-CODE-0001';
  RAISE NOTICE 'Creator user ID: %', v_test_user_id;
END $$;

-- Verify the code works
SELECT
  code,
  creator_user_id,
  is_used,
  created_at
FROM invite_codes
WHERE code = 'TEST-CODE-0001';

-- Test the validation function
SELECT * FROM validate_invite_code('TEST-CODE-0001');
