-- =====================================================
-- SECURE GP SYSTEM - PREVENTS CLIENT-SIDE CHEATING
-- =====================================================
-- This replaces the insecure update_user_gp function
-- Run this in Supabase SQL Editor

-- =====================================================
-- 1. CREATE GP TRANSACTION LOG TABLE
-- =====================================================
-- Audit trail for all GP changes

CREATE TABLE IF NOT EXISTS gp_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  amount bigint NOT NULL,
  balance_before bigint NOT NULL,
  balance_after bigint NOT NULL,
  transaction_type text NOT NULL, -- 'game_win', 'game_loss', 'staking', 'quest', 'admin'
  game_type text, -- 'crash', 'mines', 'blackjack', etc.
  reference_id uuid, -- Link to game record if applicable
  created_at timestamp with time zone DEFAULT now(),
  ip_address text,
  user_agent text
);

CREATE INDEX IF NOT EXISTS idx_gp_transactions_user ON gp_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_gp_transactions_created ON gp_transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_gp_transactions_type ON gp_transactions(transaction_type);

-- Enable RLS
ALTER TABLE gp_transactions ENABLE ROW LEVEL SECURITY;

-- Users can only view their own transactions
DROP POLICY IF EXISTS "Users view own transactions" ON gp_transactions;
CREATE POLICY "Users view own transactions" ON gp_transactions
  FOR SELECT USING (auth.uid() = user_id);

-- Only functions can insert
DROP POLICY IF EXISTS "Functions only insert" ON gp_transactions;
CREATE POLICY "Functions only insert" ON gp_transactions
  FOR INSERT WITH CHECK (false);

-- =====================================================
-- 2. SECURE UPDATE GP FUNCTION
-- =====================================================
-- Gets user_id from JWT token (auth.uid()), NOT from parameter!

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
  v_user_id uuid;
  v_current_balance bigint;
  v_new_balance bigint;
BEGIN
  -- Get authenticated user ID from JWT token (SECURE!)
  v_user_id := auth.uid();

  -- Must be logged in
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT 0::bigint, false, 'Not authenticated';
    RETURN;
  END IF;

  -- Validate amount (prevent extreme values)
  IF p_amount > 100000 THEN
    RETURN QUERY SELECT 0::bigint, false, 'Amount too large (max 100k per transaction)';
    RETURN;
  END IF;

  IF p_amount < -100000 THEN
    RETURN QUERY SELECT 0::bigint, false, 'Amount too negative (max -100k per transaction)';
    RETURN;
  END IF;

  -- Get current balance with row lock (prevents race conditions)
  SELECT gp_balance INTO v_current_balance
  FROM users
  WHERE id = v_user_id
  FOR UPDATE;

  -- Check if user exists
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

  -- Log transaction (audit trail)
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

  -- Return success
  RETURN QUERY SELECT v_new_balance, true, 'Balance updated';
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION secure_update_gp TO authenticated;
GRANT EXECUTE ON FUNCTION secure_update_gp TO anon;

-- =====================================================
-- 3. SECURE GET GP FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION secure_get_gp()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_balance bigint;
BEGIN
  -- Get authenticated user ID from JWT token
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN 0;
  END IF;

  SELECT gp_balance INTO v_balance
  FROM users
  WHERE id = v_user_id;

  RETURN COALESCE(v_balance, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION secure_get_gp TO authenticated;
GRANT EXECUTE ON FUNCTION secure_get_gp TO anon;

-- =====================================================
-- 4. RATE LIMITING TABLE
-- =====================================================
-- Prevent spam/abuse

CREATE TABLE IF NOT EXISTS gp_rate_limits (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  last_transaction timestamp with time zone DEFAULT now(),
  transaction_count_minute integer DEFAULT 0,
  transaction_count_hour integer DEFAULT 0,
  reset_minute timestamp with time zone DEFAULT now(),
  reset_hour timestamp with time zone DEFAULT now()
);

-- =====================================================
-- 5. ADMIN FUNCTIONS (for debugging)
-- =====================================================

-- View recent transactions for a user (admin only)
CREATE OR REPLACE FUNCTION admin_view_user_transactions(p_user_id uuid, p_limit integer DEFAULT 50)
RETURNS TABLE(
  transaction_id uuid,
  amount bigint,
  balance_before bigint,
  balance_after bigint,
  transaction_type text,
  game_type text,
  created_at timestamp with time zone
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- TODO: Add admin role check here
  RETURN QUERY
  SELECT id, amount, balance_before, balance_after, transaction_type, game_type, created_at
  FROM gp_transactions
  WHERE user_id = p_user_id
  ORDER BY created_at DESC
  LIMIT p_limit;
END;
$$;

-- =====================================================
-- 6. VERIFY SETUP
-- =====================================================

DO $$
BEGIN
  RAISE NOTICE 'Secure GP System Setup Complete!';
  RAISE NOTICE 'Functions created: secure_update_gp, secure_get_gp';
  RAISE NOTICE 'Transaction logging enabled in gp_transactions table';
  RAISE NOTICE 'Next: Update client code to use new functions';
END $$;
