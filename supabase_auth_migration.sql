-- =====================================================
-- SUPABASE AUTH MIGRATION FOR WALLET LOGIN
-- =====================================================
-- This enables JWT-based authentication for wallet users

-- 1. Update users table to link with Supabase Auth
ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_user_id uuid REFERENCES auth.users(id);
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON users(auth_user_id);

-- 2. Function to create or get Supabase Auth user for wallet
CREATE OR REPLACE FUNCTION create_auth_user_for_wallet(
  p_wallet_address text,
  p_display_name text,
  p_user_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_user_id uuid;
  v_email text;
BEGIN
  -- Create a pseudo-email from wallet address
  v_email := lower(p_wallet_address) || '@wallet.duelpvp.local';

  -- Check if auth user already exists for this wallet
  SELECT auth_user_id INTO v_auth_user_id
  FROM users
  WHERE id = p_user_id AND auth_user_id IS NOT NULL;

  IF v_auth_user_id IS NOT NULL THEN
    RETURN v_auth_user_id;
  END IF;

  -- Create auth user (using admin function)
  -- Note: This requires Supabase service role key from client
  -- We'll handle this differently - see implementation below

  RETURN NULL; -- Placeholder, actual creation happens client-side
END;
$$;

-- 3. Update secure GP functions to work with both auth.uid() and fallback
CREATE OR REPLACE FUNCTION secure_get_gp()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_user_id uuid;
  v_user_id uuid;
  v_balance bigint;
BEGIN
  -- Get authenticated user ID from JWT token
  v_auth_user_id := auth.uid();

  IF v_auth_user_id IS NULL THEN
    RETURN 0;
  END IF;

  -- Get user_id from users table using auth_user_id
  SELECT id, gp_balance INTO v_user_id, v_balance
  FROM users
  WHERE auth_user_id = v_auth_user_id;

  IF v_user_id IS NULL THEN
    -- Try direct match (for users created before auth migration)
    SELECT gp_balance INTO v_balance
    FROM users
    WHERE id = v_auth_user_id;
  END IF;

  RETURN COALESCE(v_balance, 0);
END;
$$;

-- 4. Update secure update function similarly
CREATE OR REPLACE FUNCTION secure_update_gp(
  p_amount bigint,
  p_transaction_type text DEFAULT 'game',
  p_game_type text DEFAULT null,
  p_reference_id uuid DEFAULT null
)
RETURNS TABLE(new_balance bigint, success boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_user_id uuid;
  v_user_id uuid;
  v_current_balance bigint;
  v_new_balance bigint;
BEGIN
  -- Get authenticated user ID from JWT token
  v_auth_user_id := auth.uid();

  IF v_auth_user_id IS NULL THEN
    RETURN QUERY SELECT 0::bigint, false, 'Not authenticated';
    RETURN;
  END IF;

  -- Get user_id from users table
  SELECT id INTO v_user_id
  FROM users
  WHERE auth_user_id = v_auth_user_id;

  IF v_user_id IS NULL THEN
    -- Try direct match
    v_user_id := v_auth_user_id;
  END IF;

  -- Validate amount
  IF p_amount > 100000 THEN
    RETURN QUERY SELECT 0::bigint, false, 'Amount too large (max 100k per transaction)';
    RETURN;
  END IF;

  IF p_amount < -100000 THEN
    RETURN QUERY SELECT 0::bigint, false, 'Amount too negative (max -100k per transaction)';
    RETURN;
  END IF;

  -- Get current balance with row lock
  SELECT gp_balance INTO v_current_balance
  FROM users
  WHERE id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT 0::bigint, false, 'User not found';
    RETURN;
  END IF;

  -- Calculate new balance
  v_new_balance := v_current_balance + p_amount;

  -- Prevent negative balance
  IF v_new_balance < 0 THEN
    RETURN QUERY SELECT v_current_balance, false, 'Insufficient balance';
    RETURN;
  END IF;

  -- Update balance
  UPDATE users
  SET gp_balance = v_new_balance,
      updated_at = now()
  WHERE id = v_user_id;

  -- Log transaction
  INSERT INTO gp_transactions (
    user_id,
    amount,
    balance_before,
    balance_after,
    transaction_type,
    game_type,
    reference_id
  ) VALUES (
    v_user_id,
    p_amount,
    v_current_balance,
    v_new_balance,
    p_transaction_type,
    p_game_type,
    p_reference_id
  );

  RETURN QUERY SELECT v_new_balance, true, 'Balance updated';
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION secure_get_gp TO authenticated;
GRANT EXECUTE ON FUNCTION secure_get_gp TO anon;
GRANT EXECUTE ON FUNCTION secure_update_gp TO authenticated;
GRANT EXECUTE ON FUNCTION secure_update_gp TO anon;

-- Verification
SELECT 'Migration SQL Complete - Now deploy client code' as status;
