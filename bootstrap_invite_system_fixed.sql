-- =====================================================
-- BOOTSTRAP INVITE SYSTEM (FIXED)
-- =====================================================
-- This version uses an existing user or creates a system user

-- Step 1: Create the invite system tables and functions
CREATE TABLE IF NOT EXISTS invite_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  creator_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  used_by_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  is_used boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  used_at timestamptz,
  CONSTRAINT one_code_per_user UNIQUE(creator_user_id)
);

CREATE INDEX IF NOT EXISTS idx_invite_codes_code ON invite_codes(code);
CREATE INDEX IF NOT EXISTS idx_invite_codes_creator ON invite_codes(creator_user_id);
CREATE INDEX IF NOT EXISTS idx_invite_codes_used_by ON invite_codes(used_by_user_id);

ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own codes" ON invite_codes;
CREATE POLICY "Users can view own codes" ON invite_codes
  FOR SELECT USING (
    auth.uid() IN (
      SELECT auth_user_id FROM users WHERE id = creator_user_id
    ) OR auth.uid() IN (
      SELECT auth_user_id FROM users WHERE id = used_by_user_id
    )
  );

DROP POLICY IF EXISTS "No direct manipulation" ON invite_codes;
CREATE POLICY "No direct manipulation" ON invite_codes
  FOR ALL USING (false);

-- Functions
CREATE OR REPLACE FUNCTION generate_invite_code()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_code text;
  v_chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_exists boolean;
BEGIN
  LOOP
    v_code :=
      substring(v_chars from floor(random() * length(v_chars) + 1)::int for 1) ||
      substring(v_chars from floor(random() * length(v_chars) + 1)::int for 1) ||
      substring(v_chars from floor(random() * length(v_chars) + 1)::int for 1) ||
      substring(v_chars from floor(random() * length(v_chars) + 1)::int for 1) || '-' ||
      substring(v_chars from floor(random() * length(v_chars) + 1)::int for 1) ||
      substring(v_chars from floor(random() * length(v_chars) + 1)::int for 1) ||
      substring(v_chars from floor(random() * length(v_chars) + 1)::int for 1) ||
      substring(v_chars from floor(random() * length(v_chars) + 1)::int for 1) || '-' ||
      substring(v_chars from floor(random() * length(v_chars) + 1)::int for 1) ||
      substring(v_chars from floor(random() * length(v_chars) + 1)::int for 1) ||
      substring(v_chars from floor(random() * length(v_chars) + 1)::int for 1) ||
      substring(v_chars from floor(random() * length(v_chars) + 1)::int for 1);

    SELECT EXISTS(SELECT 1 FROM invite_codes WHERE code = v_code) INTO v_exists;
    IF NOT v_exists THEN
      RETURN v_code;
    END IF;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION validate_invite_code(p_code text)
RETURNS TABLE(
  valid boolean,
  message text,
  creator_user_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code_record record;
BEGIN
  p_code := UPPER(TRIM(p_code));

  SELECT * INTO v_code_record
  FROM invite_codes
  WHERE code = p_code;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'Invalid invite code'::text, NULL::uuid;
    RETURN;
  END IF;

  IF v_code_record.is_used THEN
    RETURN QUERY SELECT false, 'This code has already been used'::text, NULL::uuid;
    RETURN;
  END IF;

  RETURN QUERY SELECT true, 'Valid code'::text, v_code_record.creator_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION create_user_invite_code(p_user_id uuid)
RETURNS TABLE(
  success boolean,
  message text,
  invite_code text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_code text;
  v_new_code text;
BEGIN
  SELECT code INTO v_existing_code
  FROM invite_codes
  WHERE creator_user_id = p_user_id;

  IF FOUND THEN
    RETURN QUERY SELECT true, 'Code already exists'::text, v_existing_code;
    RETURN;
  END IF;

  v_new_code := generate_invite_code();

  INSERT INTO invite_codes (code, creator_user_id, is_used)
  VALUES (v_new_code, p_user_id, false);

  RETURN QUERY SELECT true, 'Code created successfully'::text, v_new_code;
END;
$$;

CREATE OR REPLACE FUNCTION mark_invite_code_used(
  p_code text,
  p_used_by_user_id uuid
)
RETURNS TABLE(
  success boolean,
  message text,
  inviter_user_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_creator_id uuid;
  v_invites_count int;
BEGIN
  p_code := UPPER(TRIM(p_code));

  UPDATE invite_codes
  SET is_used = true,
      used_by_user_id = p_used_by_user_id,
      used_at = now()
  WHERE code = p_code AND is_used = false
  RETURNING creator_user_id INTO v_creator_id;

  IF v_creator_id IS NULL THEN
    RETURN QUERY SELECT false, 'Invalid or already used code'::text, NULL::uuid;
    RETURN;
  END IF;

  SELECT COUNT(*) INTO v_invites_count
  FROM invite_codes
  WHERE creator_user_id = v_creator_id AND is_used = true;

  INSERT INTO quest_progress (user_id, quest_id, progress)
  VALUES (v_creator_id, 'invite_friends', v_invites_count)
  ON CONFLICT (user_id, quest_id)
  DO UPDATE SET progress = v_invites_count;

  RETURN QUERY SELECT true, 'Code marked as used'::text, v_creator_id;
END;
$$;

CREATE OR REPLACE FUNCTION get_my_invite_code()
RETURNS TABLE(
  code text,
  uses_remaining int,
  used boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_user_id uuid;
  v_user_id uuid;
BEGIN
  v_auth_user_id := auth.uid();

  IF v_auth_user_id IS NULL THEN
    RETURN QUERY SELECT NULL::text, 0, false;
    RETURN;
  END IF;

  SELECT id INTO v_user_id
  FROM users
  WHERE auth_user_id = v_auth_user_id;

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT NULL::text, 0, false;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    ic.code,
    CASE WHEN ic.is_used THEN 0 ELSE 1 END as uses_remaining,
    ic.is_used
  FROM invite_codes ic
  WHERE ic.creator_user_id = v_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION generate_invite_code() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION validate_invite_code(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION create_user_invite_code(uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION mark_invite_code_used(text, uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_my_invite_code() TO authenticated, anon;

-- Step 2: Create bootstrap code using FIRST existing user OR create system user
DO $$
DECLARE
  v_bootstrap_code text := 'BOOT-STRA-P001';
  v_user_id uuid;
  v_system_user_id uuid;
BEGIN
  -- Try to find an existing user
  SELECT id INTO v_user_id
  FROM users
  ORDER BY created_at ASC
  LIMIT 1;

  -- If no users exist, create a system user
  IF v_user_id IS NULL THEN
    -- Create a system user for the bootstrap code
    INSERT INTO users (
      id,
      display_name,
      wallet_address,
      gp_balance,
      created_at
    ) VALUES (
      gen_random_uuid(),
      'SYSTEM',
      '0x0000000000000000000000000000000000000000',
      0,
      now()
    )
    RETURNING id INTO v_system_user_id;

    v_user_id := v_system_user_id;
    RAISE NOTICE 'Created system user: %', v_user_id;
  END IF;

  -- Delete existing bootstrap code if any
  DELETE FROM invite_codes WHERE code = v_bootstrap_code;

  -- Insert bootstrap code
  INSERT INTO invite_codes (code, creator_user_id, is_used)
  VALUES (v_bootstrap_code, v_user_id, false)
  ON CONFLICT (code) DO NOTHING;

  RAISE NOTICE '════════════════════════════════════════';
  RAISE NOTICE 'BOOTSTRAP CODE CREATED: %', v_bootstrap_code;
  RAISE NOTICE '════════════════════════════════════════';
  RAISE NOTICE 'Creator User ID: %', v_user_id;
  RAISE NOTICE '';
  RAISE NOTICE 'Use BOOT-STRA-P001 to register your first user!';
  RAISE NOTICE '';
END $$;

-- Show result
SELECT
  '🎯 YOUR BOOTSTRAP CODE 🎯' as instruction,
  code,
  creator_user_id,
  is_used
FROM invite_codes
WHERE code = 'BOOT-STRA-P001';

-- Test validation
SELECT '✓ Testing validation...' as status;
SELECT * FROM validate_invite_code('BOOT-STRA-P001');
