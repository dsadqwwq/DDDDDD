-- =====================================================
-- MANUALLY CREATE INVITE CODE
-- =====================================================
-- Use this if bootstrap isn't working

-- First, check if we have any users
DO $$
DECLARE
  v_user_count int;
  v_user_id uuid;
  v_code_exists boolean;
BEGIN
  SELECT COUNT(*) INTO v_user_count FROM users;

  RAISE NOTICE '═══════════════════════════════════════';
  RAISE NOTICE 'Users in database: %', v_user_count;

  IF v_user_count = 0 THEN
    RAISE NOTICE 'NO USERS FOUND!';
    RAISE NOTICE 'Creating a system user...';

    INSERT INTO users (
      display_name,
      wallet_address,
      gp_balance
    ) VALUES (
      'SYSTEM',
      '0x0000000000000000000000000000000000000000',
      0
    )
    RETURNING id INTO v_user_id;

    RAISE NOTICE 'System user created: %', v_user_id;
  ELSE
    -- Get first user
    SELECT id INTO v_user_id FROM users ORDER BY created_at ASC LIMIT 1;
    RAISE NOTICE 'Using existing user: %', v_user_id;
  END IF;

  -- Check if code exists
  SELECT EXISTS(SELECT 1 FROM invite_codes WHERE code = 'BOOT-STRA-P001')
  INTO v_code_exists;

  IF v_code_exists THEN
    RAISE NOTICE 'Code BOOT-STRA-P001 already exists!';

    -- Show it
    RAISE NOTICE 'Current status:';
    RAISE NOTICE 'Code: BOOT-STRA-P001';
    RAISE NOTICE 'Is Used: %', (SELECT is_used FROM invite_codes WHERE code = 'BOOT-STRA-P001');
  ELSE
    RAISE NOTICE 'Creating code BOOT-STRA-P001...';

    -- Delete any existing first
    DELETE FROM invite_codes WHERE code = 'BOOT-STRA-P001';

    -- Insert fresh code
    INSERT INTO invite_codes (code, creator_user_id, is_used)
    VALUES ('BOOT-STRA-P001', v_user_id, false);

    RAISE NOTICE '✓ Code created successfully!';
  END IF;

  RAISE NOTICE '═══════════════════════════════════════';
  RAISE NOTICE 'YOUR CODE: BOOT-STRA-P001';
  RAISE NOTICE '═══════════════════════════════════════';
END $$;

-- Verify it works
SELECT
  code,
  is_used,
  creator_user_id,
  created_at
FROM invite_codes
WHERE code = 'BOOT-STRA-P001';

-- Test validation
SELECT '--- Testing validation ---' as status;
SELECT * FROM validate_invite_code('BOOT-STRA-P001');
SELECT * FROM validate_invite_code('boot-stra-p001');  -- Test lowercase
