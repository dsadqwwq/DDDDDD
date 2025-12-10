-- ============================================
-- FIX FOR GAME FUNCTIONS - gp_balance → gc_balance
-- ============================================
-- This fixes the column name mismatch between your functions (using gp_balance)
-- and your actual table (which has gc_balance)

-- ============================================
-- FIX: secure_update_gp
-- ============================================
-- Changes: gp_balance → gc_balance everywhere

CREATE OR REPLACE FUNCTION public.secure_update_gp(p_amount bigint, p_transaction_type text DEFAULT 'game'::text, p_game_type text DEFAULT NULL::text, p_reference_id uuid DEFAULT NULL::uuid)
RETURNS TABLE(new_balance bigint, success boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
  -- FIXED: gp_balance → gc_balance
  SELECT gc_balance INTO v_current_balance
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
  -- FIXED: gp_balance → gc_balance
  UPDATE users
  SET gc_balance = v_new_balance,
      updated_at = now()
  WHERE id = v_user_id;

  -- Log transaction (if gc_transactions table exists)
  BEGIN
    INSERT INTO gc_transactions (
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
$function$;

-- ============================================
-- FIX: update_user_gp (3 parameter version)
-- ============================================

CREATE OR REPLACE FUNCTION public.update_user_gp(p_user_id uuid, p_amount bigint, p_transaction_type text DEFAULT 'general'::text, p_game_type text DEFAULT NULL::text, p_reference_id uuid DEFAULT NULL::uuid)
RETURNS TABLE(new_balance bigint, success boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_current_balance bigint;
  v_new_balance bigint;
BEGIN
  -- Get current balance with row lock (prevents race conditions)
  -- FIXED: gp_balance → gc_balance
  SELECT gc_balance INTO v_current_balance
  FROM users
  WHERE id = p_user_id
  FOR UPDATE;

  -- Check if user exists
  IF NOT FOUND THEN
    RETURN QUERY SELECT 0::bigint, false, 'User not found';
    RETURN;
  END IF;

  -- Calculate new balance
  v_new_balance := v_current_balance + p_amount;

  -- Prevent negative balance (can't spend more than you have)
  IF v_new_balance < 0 THEN
    RETURN QUERY SELECT v_current_balance, false, 'Insufficient balance';
    RETURN;
  END IF;

  -- Update balance
  -- FIXED: gp_balance → gc_balance
  UPDATE users
  SET gc_balance = v_new_balance,
      updated_at = now()
  WHERE id = p_user_id;

  -- Log transaction if gc_transactions table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'gc_transactions') THEN
    INSERT INTO gc_transactions (
      user_id,
      amount,
      balance_before,
      balance_after,
      transaction_type,
      game_type,
      reference_id
    ) VALUES (
      p_user_id,
      p_amount,
      v_current_balance,
      v_new_balance,
      p_transaction_type,
      p_game_type,
      p_reference_id
    );
  END IF;

  -- Return success
  RETURN QUERY SELECT v_new_balance, true, 'Balance updated';
END;
$function$;

-- ============================================
-- FIX: update_user_gp (2 parameter version)
-- ============================================

CREATE OR REPLACE FUNCTION public.update_user_gp(p_user_id uuid, p_amount bigint)
RETURNS TABLE(new_balance bigint, success boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_current_balance bigint;
  v_new_balance bigint;
BEGIN
  -- FIXED: gp_balance → gc_balance
  SELECT gc_balance INTO v_current_balance
  FROM users
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT 0::bigint, false, 'User not found';
    RETURN;
  END IF;

  v_new_balance := v_current_balance + p_amount;

  IF v_new_balance < 0 THEN
    RETURN QUERY SELECT v_current_balance, false, 'Insufficient balance';
    RETURN;
  END IF;

  -- FIXED: gp_balance → gc_balance
  UPDATE users
  SET gc_balance = v_new_balance,
      updated_at = now()
  WHERE id = p_user_id;

  RETURN QUERY SELECT v_new_balance, true, 'Balance updated';
END;
$function$;

-- ============================================
-- CREATE MISSING TABLE: mines_games
-- ============================================
-- This table is required for the Mines game to work

CREATE TABLE IF NOT EXISTS mines_games (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  bet_amount BIGINT NOT NULL,
  mines_count INTEGER NOT NULL,
  mine_positions INTEGER[] NOT NULL,
  revealed_tiles INTEGER[] DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'active', -- 'active', 'cashed_out', 'lost'
  payout BIGINT DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  ended_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_mines_games_user_id ON mines_games(user_id);
CREATE INDEX IF NOT EXISTS idx_mines_games_status ON mines_games(status);

-- ============================================
-- VERIFICATION
-- ============================================

-- Test the fixed functions (don't run these, just examples):
-- SELECT * FROM secure_update_gp(100, 'test', 'crash');
-- SELECT * FROM update_user_gp('user-id-here', 50, 'test');

-- Verify mines_games table exists:
-- SELECT * FROM mines_games LIMIT 1;
