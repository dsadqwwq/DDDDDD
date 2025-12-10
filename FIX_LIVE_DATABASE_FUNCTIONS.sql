-- ============================================
-- FIX LIVE DATABASE - UPDATE RPC FUNCTIONS
-- ============================================
-- This fixes "transaction failed" errors on live site
-- Run this in your LIVE Supabase SQL Editor

-- Drop old versions
DROP FUNCTION IF EXISTS secure_update_gc(bigint, text, text, uuid);
DROP FUNCTION IF EXISTS update_user_gc(uuid, bigint, text, text, uuid);
DROP FUNCTION IF EXISTS update_user_gc(uuid, bigint, text, text);

-- ============================================
-- 1. CREATE/UPDATE secure_update_gc
-- ============================================
CREATE OR REPLACE FUNCTION public.secure_update_gc(
  p_amount bigint,
  p_transaction_type text DEFAULT 'game',
  p_game_type text DEFAULT NULL
)
RETURNS TABLE(new_balance bigint, success boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_auth_user_id uuid;
  v_user_id uuid;
  v_current_balance bigint;
  v_new_balance bigint;
BEGIN
  -- Get user from session
  v_auth_user_id := auth.uid();
  IF v_auth_user_id IS NULL THEN
    RETURN QUERY SELECT 0::bigint, false, 'Not authenticated'::text;
    RETURN;
  END IF;

  -- Find user by auth_user_id
  SELECT id INTO v_user_id FROM users WHERE auth_user_id = v_auth_user_id;
  IF v_user_id IS NULL THEN
    SELECT id INTO v_user_id FROM users WHERE id = v_auth_user_id;
  END IF;
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT 0::bigint, false, 'User not found'::text;
    RETURN;
  END IF;

  -- Validate amount
  IF p_amount > 100000 THEN
    RETURN QUERY SELECT 0::bigint, false, 'Amount too large (max 100k per transaction)'::text;
    RETURN;
  END IF;
  IF p_amount < -100000 THEN
    RETURN QUERY SELECT 0::bigint, false, 'Amount too negative (max -100k per transaction)'::text;
    RETURN;
  END IF;

  -- Get current balance with row lock
  SELECT gc_balance INTO v_current_balance FROM users WHERE id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT 0::bigint, false, 'User not found'::text;
    RETURN;
  END IF;

  -- Calculate new balance
  v_new_balance := v_current_balance + p_amount;

  -- Prevent negative balance
  IF v_new_balance < 0 THEN
    RETURN QUERY SELECT v_current_balance, false, 'Insufficient balance'::text;
    RETURN;
  END IF;

  -- Update balance
  UPDATE users SET gc_balance = v_new_balance, updated_at = now() WHERE id = v_user_id;

  -- Log transaction (only if table exists)
  BEGIN
    INSERT INTO gc_transactions (user_id, amount, balance_before, balance_after, transaction_type, game_type)
    VALUES (v_user_id, p_amount, v_current_balance, v_new_balance, p_transaction_type, p_game_type);
  EXCEPTION
    WHEN undefined_table THEN
      NULL; -- Ignore if table doesn't exist
  END;

  RETURN QUERY SELECT v_new_balance, true, 'Balance updated'::text;
END;
$$;

-- ============================================
-- 2. CREATE/UPDATE update_user_gc (fallback)
-- ============================================
CREATE OR REPLACE FUNCTION public.update_user_gc(
  p_user_id uuid,
  p_amount bigint,
  p_transaction_type text DEFAULT 'general',
  p_game_type text DEFAULT NULL
)
RETURNS TABLE(new_balance bigint, success boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_balance bigint;
  v_new_balance bigint;
  v_auth_user_id uuid;
  v_user_auth_id uuid;
BEGIN
  -- SECURITY CHECK: Get auth user ID from session
  v_auth_user_id := auth.uid();

  IF v_auth_user_id IS NULL THEN
    RETURN QUERY SELECT 0::bigint, false, 'Not authenticated'::text;
    RETURN;
  END IF;

  -- SECURITY CHECK: Verify the user owns this account
  SELECT auth_user_id INTO v_user_auth_id FROM users WHERE id = p_user_id;

  IF v_user_auth_id IS NULL THEN
    RETURN QUERY SELECT 0::bigint, false, 'User not linked to auth'::text;
    RETURN;
  END IF;

  IF v_user_auth_id != v_auth_user_id THEN
    RETURN QUERY SELECT 0::bigint, false, 'Unauthorized: Cannot modify another users balance'::text;
    RETURN;
  END IF;

  -- Get current balance with row lock
  SELECT gc_balance INTO v_current_balance FROM users WHERE id = p_user_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT 0::bigint, false, 'User not found'::text;
    RETURN;
  END IF;

  -- Calculate new balance
  v_new_balance := v_current_balance + p_amount;

  -- Prevent negative balance
  IF v_new_balance < 0 THEN
    RETURN QUERY SELECT v_current_balance, false, 'Insufficient balance'::text;
    RETURN;
  END IF;

  -- Update balance
  UPDATE users SET gc_balance = v_new_balance, updated_at = now() WHERE id = p_user_id;

  -- Log transaction (only if table exists)
  BEGIN
    INSERT INTO gc_transactions (user_id, amount, balance_before, balance_after, transaction_type, game_type)
    VALUES (p_user_id, p_amount, v_current_balance, v_new_balance, p_transaction_type, p_game_type);
  EXCEPTION
    WHEN undefined_table THEN
      NULL; -- Ignore if table doesn't exist
  END;

  RETURN QUERY SELECT v_new_balance, true, 'Balance updated'::text;
END;
$$;

-- ============================================
-- 3. GRANT PERMISSIONS
-- ============================================
GRANT EXECUTE ON FUNCTION secure_update_gc TO authenticated, anon;
GRANT EXECUTE ON FUNCTION update_user_gc TO authenticated, anon;

-- ============================================
-- 4. VERIFY FUNCTIONS EXIST
-- ============================================
SELECT
  routine_name,
  routine_type,
  data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('secure_update_gc', 'update_user_gc')
ORDER BY routine_name;
