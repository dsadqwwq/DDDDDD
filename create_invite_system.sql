-- =====================================================
-- INVITE CODE SYSTEM
-- =====================================================
-- Each user gets ONE invite code that can be used once
-- Tracks who invited whom for quest rewards

-- 1. Create invite_codes table
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

-- Enable RLS
ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;

-- Users can view their own code and codes they've used
DROP POLICY IF EXISTS "Users can view own codes" ON invite_codes;
CREATE POLICY "Users can view own codes" ON invite_codes
  FOR SELECT USING (
    auth.uid() IN (
      SELECT auth_user_id FROM users WHERE id = creator_user_id
    ) OR auth.uid() IN (
      SELECT auth_user_id FROM users WHERE id = used_by_user_id
    )
  );

-- Only functions can insert/update
DROP POLICY IF EXISTS "No direct manipulation" ON invite_codes;
CREATE POLICY "No direct manipulation" ON invite_codes
  FOR ALL USING (false);

-- =====================================================
-- GENERATE UNIQUE INVITE CODE
-- =====================================================
-- Generates a random 12-character code (XXXX-XXXX-XXXX format)
CREATE OR REPLACE FUNCTION generate_invite_code()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_code text;
  v_chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Exclude similar chars
  v_exists boolean;
BEGIN
  LOOP
    -- Generate 12-character code in XXXX-XXXX-XXXX format
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

    -- Check if code already exists
    SELECT EXISTS(SELECT 1 FROM invite_codes WHERE code = v_code) INTO v_exists;

    -- If unique, return it
    IF NOT v_exists THEN
      RETURN v_code;
    END IF;
  END LOOP;
END;
$$;

-- =====================================================
-- CREATE INVITE CODE FOR USER
-- =====================================================
-- Called after warrior name is set
-- One code per user, cannot create multiple
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
  -- Check if user already has a code
  SELECT code INTO v_existing_code
  FROM invite_codes
  WHERE creator_user_id = p_user_id;

  IF FOUND THEN
    RETURN QUERY SELECT true, 'Code already exists'::text, v_existing_code;
    RETURN;
  END IF;

  -- Generate new unique code
  v_new_code := generate_invite_code();

  -- Insert code
  INSERT INTO invite_codes (code, creator_user_id, is_used)
  VALUES (v_new_code, p_user_id, false);

  RETURN QUERY SELECT true, 'Code created successfully'::text, v_new_code;
END;
$$;

-- =====================================================
-- VALIDATE INVITE CODE
-- =====================================================
-- Called during signup to check if code is valid
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
  -- Normalize code (uppercase, trim)
  p_code := UPPER(TRIM(p_code));

  -- Get code details
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

-- =====================================================
-- MARK INVITE CODE AS USED
-- =====================================================
-- Called after warrior name is set by new user
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
  -- Normalize code
  p_code := UPPER(TRIM(p_code));

  -- Update code as used
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

  -- Count how many people this user has invited
  SELECT COUNT(*) INTO v_invites_count
  FROM invite_codes
  WHERE creator_user_id = v_creator_id AND is_used = true;

  -- Update quest progress for inviter (invite_friends quest)
  -- This will be checked by the quest system
  INSERT INTO quest_progress (user_id, quest_id, progress)
  VALUES (v_creator_id, 'invite_friends', v_invites_count)
  ON CONFLICT (user_id, quest_id)
  DO UPDATE SET progress = v_invites_count;

  RETURN QUERY SELECT true, 'Code marked as used'::text, v_creator_id;
END;
$$;

-- =====================================================
-- GET USER'S INVITE CODE
-- =====================================================
-- Returns the authenticated user's invite code
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

  -- Get user ID
  SELECT id INTO v_user_id
  FROM users
  WHERE auth_user_id = v_auth_user_id;

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT NULL::text, 0, false;
    RETURN;
  END IF;

  -- Return code info
  RETURN QUERY
  SELECT
    ic.code,
    CASE WHEN ic.is_used THEN 0 ELSE 1 END as uses_remaining,
    ic.is_used
  FROM invite_codes ic
  WHERE ic.creator_user_id = v_user_id;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION generate_invite_code() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION create_user_invite_code(uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION validate_invite_code(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION mark_invite_code_used(text, uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_my_invite_code() TO authenticated, anon;

-- =====================================================
-- VERIFY SETUP
-- =====================================================
SELECT
  'Invite System Ready!' as status,
  (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'invite_codes') as has_invite_codes_table,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'generate_invite_code') as has_generate,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'create_user_invite_code') as has_create,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'validate_invite_code') as has_validate,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'mark_invite_code_used') as has_mark_used,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'get_my_invite_code') as has_get_code;
