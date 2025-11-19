-- =====================================================
-- ADD TERMS OF SERVICE ACCEPTANCE TRACKING
-- =====================================================

-- Add column to track when user accepted terms
ALTER TABLE users ADD COLUMN IF NOT EXISTS terms_accepted_at timestamp with time zone;
ALTER TABLE users ADD COLUMN IF NOT EXISTS terms_version text DEFAULT '1.0';

-- Drop old function first (to avoid signature conflicts)
DROP FUNCTION IF EXISTS register_with_wallet(text, text, text);

-- Create new register_with_wallet function with terms acceptance parameter
CREATE OR REPLACE FUNCTION register_with_wallet(
  p_wallet_address text,
  p_display_name text,
  p_invite_code text,
  p_terms_accepted boolean DEFAULT false
)
RETURNS TABLE(
  success boolean,
  message text,
  user_id uuid,
  error_code text
)
LANGUAGE plpgsql
SECURITY definer
AS $$
DECLARE
  v_code_data record;
  v_new_user_id uuid;
BEGIN
  -- Validate inputs
  IF p_wallet_address IS NULL OR p_wallet_address = '' THEN
    RETURN QUERY SELECT false, 'Wallet address is required', null::uuid, 'INVALID_WALLET';
    RETURN;
  END IF;

  IF p_display_name IS NULL OR p_display_name = '' THEN
    RETURN QUERY SELECT false, 'Display name is required', null::uuid, 'INVALID_NAME';
    RETURN;
  END IF;

  IF LENGTH(p_display_name) < 3 THEN
    RETURN QUERY SELECT false, 'Display name must be at least 3 characters', null::uuid, 'NAME_TOO_SHORT';
    RETURN;
  END IF;

  -- NEW: Require terms acceptance
  IF NOT p_terms_accepted THEN
    RETURN QUERY SELECT false, 'You must accept the Terms of Service', null::uuid, 'TERMS_NOT_ACCEPTED';
    RETURN;
  END IF;

  -- Check if wallet already registered
  IF EXISTS (SELECT 1 FROM users WHERE wallet_address = LOWER(p_wallet_address)) THEN
    RETURN QUERY SELECT false, 'Wallet already registered', null::uuid, 'WALLET_EXISTS';
    RETURN;
  END IF;

  -- Check if display name taken (case-insensitive)
  IF EXISTS (SELECT 1 FROM users WHERE LOWER(display_name) = LOWER(p_display_name)) THEN
    RETURN QUERY SELECT false, 'Display name already taken', null::uuid, 'NAME_TAKEN';
    RETURN;
  END IF;

  -- Validate invite code
  SELECT * INTO v_code_data
  FROM codes
  WHERE code = p_invite_code
  AND used_by IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'Invalid or already used invite code', null::uuid, 'INVALID_CODE';
    RETURN;
  END IF;

  -- Create user with terms acceptance timestamp
  INSERT INTO users (
    wallet_address,
    display_name,
    email,
    gp_balance,
    points,
    level,
    total_wins,
    win_streak,
    terms_accepted_at,
    terms_version
  )
  VALUES (
    LOWER(p_wallet_address),
    p_display_name,
    null,
    1000,
    0,
    1,
    0,
    0,
    now(),  -- Record when they accepted
    '1.0'   -- Terms version
  )
  RETURNING id INTO v_new_user_id;

  -- Mark code as used
  UPDATE codes
  SET used_by = v_new_user_id,
      used_at = now()
  WHERE code = p_invite_code;

  -- Generate 3 invite codes for new user
  PERFORM create_user_codes(v_new_user_id);

  RETURN QUERY SELECT true, 'Registration successful', v_new_user_id, ''::text;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION register_with_wallet TO authenticated, anon;

-- Verification
SELECT
  'Terms acceptance tracking added!' as status,
  (SELECT COUNT(*) FROM information_schema.columns
   WHERE table_name = 'users' AND column_name = 'terms_accepted_at') as has_terms_column;
