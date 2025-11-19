-- =====================================================
-- BOOTSTRAP INVITE SYSTEM
-- =====================================================
-- Run this ONCE to set everything up and create the first code

-- Step 1: Create the invite system (if not exists)
-- This is copied from create_invite_system.sql but condensed

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

-- Step 2: Create necessary functions
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION generate_invite_code() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION validate_invite_code(text) TO authenticated, anon;

-- Step 3: Create a BOOTSTRAP code
-- This is a special temporary code just for initial setup
DO $$
DECLARE
  v_bootstrap_code text := 'BOOT-STRA-P001';
  v_fake_user_id uuid := gen_random_uuid(); -- Temporary fake user ID
BEGIN
  -- Delete if exists
  DELETE FROM invite_codes WHERE code = v_bootstrap_code;

  -- Insert bootstrap code with a fake user ID (will be cleaned up later)
  INSERT INTO invite_codes (code, creator_user_id, is_used)
  VALUES (v_bootstrap_code, v_fake_user_id, false)
  ON CONFLICT (code) DO NOTHING;

  RAISE NOTICE '════════════════════════════════════════';
  RAISE NOTICE 'BOOTSTRAP CODE CREATED: %', v_bootstrap_code;
  RAISE NOTICE '════════════════════════════════════════';
  RAISE NOTICE 'Use this code to register your first user!';
  RAISE NOTICE 'After registration, that user will get their own code.';
  RAISE NOTICE '';
END $$;

-- Show the bootstrap code
SELECT
  '🎯 USE THIS CODE TO REGISTER 🎯' as instruction,
  code,
  'Bootstrap Code (temporary)' as note
FROM invite_codes
WHERE code = 'BOOT-STRA-P001';

-- Verify function works
SELECT '✓ Testing validation...' as status;
SELECT * FROM validate_invite_code('BOOT-STRA-P001');
