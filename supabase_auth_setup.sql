-- ============================================
-- DUEL PVP - AUTHENTICATION RPC FUNCTIONS
-- ============================================
-- These functions handle wallet-based authentication and user registration

-- ============================================
-- USER REGISTRATION WITH WALLET
-- ============================================

CREATE OR REPLACE FUNCTION register_user_with_wallet(
  p_wallet_address TEXT,
  p_display_name TEXT,
  p_invite_code TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_code_id UUID;
  v_code_creator_id UUID;
BEGIN
  -- Check if wallet already exists
  SELECT id INTO v_user_id
  FROM users
  WHERE LOWER(wallet_address) = LOWER(p_wallet_address);

  IF v_user_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Wallet already registered'
    );
  END IF;

  -- Validate invite code if provided
  IF p_invite_code IS NOT NULL THEN
    SELECT id, created_by INTO v_code_id, v_code_creator_id
    FROM codes
    WHERE code = p_invite_code
      AND used_at IS NULL;

    IF v_code_id IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Invalid or already used invite code'
      );
    END IF;
  END IF;

  -- Create new user with starting GC (1000 GC to start)
  INSERT INTO users (wallet_address, display_name, gc_balance)
  VALUES (p_wallet_address, p_display_name, 1000)
  RETURNING id INTO v_user_id;

  -- Mark invite code as used
  IF v_code_id IS NOT NULL THEN
    UPDATE codes
    SET used_by = v_user_id, used_at = NOW()
    WHERE id = v_code_id;

    -- Award referral bonus to code creator (500 GC)
    IF v_code_creator_id IS NOT NULL THEN
      UPDATE users
      SET gc_balance = gc_balance + 500
      WHERE id = v_code_creator_id;

      INSERT INTO transactions (user_id, amount, transaction_type, metadata)
      VALUES (v_code_creator_id, 500, 'referral', jsonb_build_object('referred_user', v_user_id));
    END IF;
  END IF;

  -- Generate 3 invite codes for the new user
  INSERT INTO codes (code, created_by)
  SELECT
    substring(md5(random()::text || p_wallet_address) from 1 for 8),
    v_user_id
  FROM generate_series(1, 3);

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'wallet_address', p_wallet_address,
    'display_name', p_display_name,
    'starting_balance', 1000
  );
END;
$$;

-- ============================================
-- LOGIN WITH WALLET
-- ============================================

CREATE OR REPLACE FUNCTION login_with_wallet(
  p_wallet_address TEXT,
  p_signature TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user RECORD;
BEGIN
  -- Find user by wallet address (case-insensitive)
  SELECT
    id,
    wallet_address,
    display_name,
    email,
    gc_balance,
    created_at
  INTO v_user
  FROM users
  WHERE LOWER(wallet_address) = LOWER(p_wallet_address);

  -- If user not found
  IF v_user.id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Wallet not registered'
    );
  END IF;

  -- Update last login timestamp
  UPDATE users
  SET updated_at = NOW()
  WHERE id = v_user.id;

  -- Return user data
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user.id,
    'wallet_address', v_user.wallet_address,
    'display_name', v_user.display_name,
    'email', v_user.email,
    'gc_balance', v_user.gc_balance,
    'created_at', v_user.created_at
  );
END;
$$;

-- ============================================
-- VALIDATE INVITE CODE
-- ============================================

CREATE OR REPLACE FUNCTION validate_invite_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_code RECORD;
  v_creator_name TEXT;
BEGIN
  -- Find the code
  SELECT id, created_by, used_at
  INTO v_code
  FROM codes
  WHERE code = p_code;

  -- Code doesn't exist
  IF v_code.id IS NULL THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error', 'Invalid code'
    );
  END IF;

  -- Code already used
  IF v_code.used_at IS NOT NULL THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error', 'Code already used'
    );
  END IF;

  -- Get creator's name
  SELECT display_name INTO v_creator_name
  FROM users
  WHERE id = v_code.created_by;

  RETURN jsonb_build_object(
    'valid', true,
    'created_by', v_creator_name
  );
END;
$$;

-- ============================================
-- RESERVE INVITE CODE (for registration flow)
-- ============================================

CREATE OR REPLACE FUNCTION reserve_invite_code(
  p_code TEXT,
  p_wallet_address TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_code_id UUID;
BEGIN
  -- Check if code exists and is unused
  SELECT id INTO v_code_id
  FROM codes
  WHERE code = p_code
    AND used_at IS NULL;

  IF v_code_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid or already used code'
    );
  END IF;

  -- Note: Actual reservation logic can be added here if needed
  -- For now, just validate the code is available

  RETURN jsonb_build_object(
    'success', true,
    'code', p_code
  );
END;
$$;

-- ============================================
-- LINK AUTH TO USER (for Supabase Auth integration)
-- ============================================

CREATE OR REPLACE FUNCTION link_auth_to_user(
  p_user_id UUID,
  p_wallet_address TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Verify user exists
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User not found'
    );
  END IF;

  -- Link is successful (actual Supabase Auth linking happens client-side)
  RETURN jsonb_build_object(
    'success', true,
    'user_id', p_user_id
  );
END;
$$;

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

GRANT EXECUTE ON FUNCTION register_user_with_wallet TO authenticated, anon;
GRANT EXECUTE ON FUNCTION login_with_wallet TO authenticated, anon;
GRANT EXECUTE ON FUNCTION validate_invite_code TO authenticated, anon;
GRANT EXECUTE ON FUNCTION reserve_invite_code TO authenticated, anon;
GRANT EXECUTE ON FUNCTION link_auth_to_user TO authenticated, anon;

-- ============================================
-- VERIFICATION
-- ============================================

-- Test registration:
-- SELECT register_user_with_wallet('0xTEST123...', 'TestWarrior', NULL);

-- Test login:
-- SELECT login_with_wallet('0xTEST123...');

-- Test invite code validation:
-- SELECT validate_invite_code('abc12345');
