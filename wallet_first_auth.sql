-- =====================================================
-- WALLET-FIRST AUTH SYSTEM
-- =====================================================
-- Updates database schema to support wallet-primary authentication
-- Run this to enable wallet-only registration (no email required)

-- 1. Make email optional, wallet_address required
ALTER TABLE users ALTER COLUMN email DROP NOT NULL;
ALTER TABLE users ADD CONSTRAINT users_wallet_address_key UNIQUE (wallet_address);

-- 2. Add index for faster wallet lookups
CREATE INDEX IF NOT EXISTS idx_users_wallet_address ON users(wallet_address);

-- 3. Update users table to allow NULL emails (for wallet-only accounts)
-- Existing users with emails are unaffected

-- 4. Create function to register with wallet
CREATE OR REPLACE FUNCTION register_with_wallet(
  p_wallet_address text,
  p_display_name text,
  p_invite_code text
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

  -- Check if wallet already registered
  IF EXISTS (SELECT 1 FROM users WHERE wallet_address = p_wallet_address) THEN
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

  -- Create user
  INSERT INTO users (wallet_address, display_name, email, gp_balance, points, level, total_wins, win_streak)
  VALUES (p_wallet_address, p_display_name, null, 1000, 0, 1, 0, 0)
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

-- 5. Verify setup
SELECT
  'Wallet-First Auth Ready!' as status,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'register_with_wallet') as has_register_function;

-- Test example
-- SELECT * FROM register_with_wallet('0x1234...', 'TestWarrior', 'TEST1234');
