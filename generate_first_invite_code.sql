-- =====================================================
-- GENERATE FIRST INVITE CODE
-- =====================================================
-- This creates an invite code for an existing user
-- Run this AFTER create_invite_system.sql

-- Get the first user and create their invite code
DO $$
DECLARE
  v_user_id uuid;
  v_result record;
BEGIN
  -- Get first user
  SELECT id INTO v_user_id
  FROM users
  ORDER BY created_at ASC
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No users found! Create a user first by registering with an existing code.';
  END IF;

  RAISE NOTICE 'Creating invite code for user: %', v_user_id;

  -- Create invite code using the actual function
  SELECT * INTO v_result
  FROM create_user_invite_code(v_user_id);

  IF v_result.success THEN
    RAISE NOTICE '✓ Success! Invite code created: %', v_result.invite_code;
    RAISE NOTICE 'Share this code to invite new users!';
  ELSE
    RAISE NOTICE '✗ Failed: %', v_result.message;
  END IF;
END $$;

-- Show all invite codes
SELECT
  ic.code,
  u.display_name as creator_name,
  ic.is_used,
  ic.created_at
FROM invite_codes ic
LEFT JOIN users u ON u.id = ic.creator_user_id
ORDER BY ic.created_at DESC;
