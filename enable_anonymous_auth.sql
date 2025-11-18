-- =====================================================
-- ENABLE ANONYMOUS AUTH FOR WALLET USERS
-- =====================================================
-- This migration enables Supabase anonymous authentication
-- which is the proper way to handle wallet-based users

-- =====================================================
-- STEP 1: Enable Anonymous Auth in Supabase Dashboard
-- =====================================================
-- You MUST do this manually in the Supabase Dashboard:
--
-- 1. Go to: https://app.supabase.com/project/YOUR_PROJECT/auth/providers
-- 2. Find "Anonymous Sign-Ins" section
-- 3. Toggle ON "Enable anonymous sign-ins"
-- 4. Click "Save"
--
-- THIS IS REQUIRED - The SQL below won't work without it!
-- =====================================================

-- Ensure auth_user_id column exists (should already exist from previous migration)
ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_user_id uuid REFERENCES auth.users(id);
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON users(auth_user_id);

-- Update secure_get_gp to work with anonymous auth
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
  -- Get authenticated user ID from JWT token (works for both regular and anonymous users)
  v_auth_user_id := auth.uid();

  IF v_auth_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get user_id from users table using auth_user_id
  SELECT id, gp_balance INTO v_user_id, v_balance
  FROM users
  WHERE auth_user_id = v_auth_user_id;

  IF v_user_id IS NULL THEN
    -- Fallback: try direct match (for users created before auth migration)
    SELECT id, gp_balance INTO v_user_id, v_balance
    FROM users
    WHERE id = v_auth_user_id;
  END IF;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  RETURN COALESCE(v_balance, 0);
END;
$$;

-- Update secure_update_gp to work with anonymous auth
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
  -- Get authenticated user ID from JWT token (works for both regular and anonymous users)
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
    -- Fallback: try direct match
    SELECT id INTO v_user_id
    FROM users
    WHERE id = v_auth_user_id;
  END IF;

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT 0::bigint, false, 'User not found';
    RETURN;
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

  -- Log transaction (if gp_transactions table exists)
  BEGIN
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
  EXCEPTION WHEN undefined_table THEN
    -- Table doesn't exist yet, skip logging
    NULL;
  END;

  RETURN QUERY SELECT v_new_balance, true, 'Balance updated';
END;
$$;

-- Grant permissions to both authenticated and anonymous users
GRANT EXECUTE ON FUNCTION secure_get_gp TO authenticated, anon;
GRANT EXECUTE ON FUNCTION secure_update_gp TO authenticated, anon;

-- Verification query
SELECT
  'Anonymous Auth SQL Migration Complete!' as status,
  '⚠️  REMEMBER: Enable Anonymous Sign-Ins in Supabase Dashboard!' as important_note,
  'Go to: Authentication > Providers > Anonymous Sign-Ins' as dashboard_location;
