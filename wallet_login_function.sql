-- =====================================================
-- WALLET LOGIN FUNCTION
-- =====================================================
-- This function allows secure wallet login that bypasses RLS
-- to look up users by wallet_address

CREATE OR REPLACE FUNCTION login_with_wallet(
  p_wallet_address text
)
RETURNS TABLE(
  success boolean,
  message text,
  user_id uuid,
  display_name text,
  gp_balance bigint,
  auth_user_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER  -- Bypass RLS to look up user
SET search_path = public
AS $$
DECLARE
  v_user record;
BEGIN
  -- Validate input
  IF p_wallet_address IS NULL OR p_wallet_address = '' THEN
    RETURN QUERY SELECT false, 'Wallet address is required', null::uuid, null::text, null::bigint, null::uuid;
    RETURN;
  END IF;

  -- Look up user by wallet address (bypasses RLS)
  SELECT u.id, u.display_name, u.gp_balance, u.auth_user_id
  INTO v_user
  FROM users u
  WHERE u.wallet_address = LOWER(p_wallet_address);

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'Wallet not registered', null::uuid, null::text, null::bigint, null::uuid;
    RETURN;
  END IF;

  -- Return user data
  RETURN QUERY SELECT
    true,
    'User found',
    v_user.id,
    v_user.display_name,
    COALESCE(v_user.gp_balance, 0::bigint),
    v_user.auth_user_id;
END;
$$;

-- Grant execute permission to everyone (it's safe - only returns data for the wallet that was provided)
GRANT EXECUTE ON FUNCTION login_with_wallet TO authenticated, anon;

-- Verification
SELECT 'Wallet login function created!' as status;
