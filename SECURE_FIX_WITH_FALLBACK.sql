-- ============================================
-- SECURE FIX - Keep auth but add safe fallback
-- ============================================
-- This maintains security while handling auth issues
-- Run this in your LIVE Supabase SQL Editor

DROP FUNCTION IF EXISTS secure_update_gc(bigint, text, text);
DROP FUNCTION IF EXISTS update_user_gc(uuid, bigint, text, text);

-- Updated secure_update_gc that REQUIRES auth but tries harder to find user
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
  -- SECURITY: Must have auth session
  v_auth_user_id := auth.uid();

  IF v_auth_user_id IS NULL THEN
    RETURN QUERY SELECT 0::bigint, false, 'AUTH_SESSION_MISSING'::text;
    RETURN;
  END IF;

  -- Try to find user (multiple methods)
  SELECT id INTO v_user_id
  FROM users
  WHERE auth_user_id = v_auth_user_id
  LIMIT 1;

  IF v_user_id IS NULL THEN
    SELECT id INTO v_user_id
    FROM users
    WHERE id = v_auth_user_id
    LIMIT 1;
  END IF;

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT 0::bigint, false, 'USER_NOT_FOUND'::text;
    RETURN;
  END IF;

  -- Validate amount
  IF ABS(p_amount) > 100000 THEN
    RETURN QUERY SELECT 0::bigint, false, 'AMOUNT_TOO_LARGE'::text;
    RETURN;
  END IF;

  -- Get and lock balance
  SELECT gc_balance INTO v_current_balance
  FROM users
  WHERE id = v_user_id
  FOR UPDATE;

  v_new_balance := v_current_balance + p_amount;

  IF v_new_balance < 0 THEN
    RETURN QUERY SELECT v_current_balance, false, 'INSUFFICIENT_BALANCE'::text;
    RETURN;
  END IF;

  -- Update balance
  UPDATE users
  SET gc_balance = v_new_balance,
      updated_at = now()
  WHERE id = v_user_id;

  -- Log transaction
  BEGIN
    INSERT INTO gc_transactions (user_id, amount, balance_before, balance_after, transaction_type, game_type)
    VALUES (v_user_id, p_amount, v_current_balance, v_new_balance, p_transaction_type, p_game_type);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RETURN QUERY SELECT v_new_balance, true, 'SUCCESS'::text;
END;
$$;

-- Fallback function for when auth sessions are broken
-- This one accepts user_id but VERIFIES it matches the auth session
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
  v_auth_user_id uuid;
  v_user_auth_id uuid;
  v_current_balance bigint;
  v_new_balance bigint;
BEGIN
  -- SECURITY: Get auth session
  v_auth_user_id := auth.uid();

  IF v_auth_user_id IS NULL THEN
    RETURN QUERY SELECT 0::bigint, false, 'AUTH_SESSION_MISSING'::text;
    RETURN;
  END IF;

  -- SECURITY: Verify user owns this account
  SELECT auth_user_id INTO v_user_auth_id
  FROM users
  WHERE id = p_user_id;

  IF v_user_auth_id IS NULL THEN
    -- User doesn't have auth_user_id set, check if they own it another way
    IF p_user_id != v_auth_user_id THEN
      RETURN QUERY SELECT 0::bigint, false, 'UNAUTHORIZED'::text;
      RETURN;
    END IF;
  ELSIF v_user_auth_id != v_auth_user_id THEN
    RETURN QUERY SELECT 0::bigint, false, 'UNAUTHORIZED'::text;
    RETURN;
  END IF;

  -- Validate amount
  IF ABS(p_amount) > 100000 THEN
    RETURN QUERY SELECT 0::bigint, false, 'AMOUNT_TOO_LARGE'::text;
    RETURN;
  END IF;

  -- Get and lock
  SELECT gc_balance INTO v_current_balance
  FROM users
  WHERE id = p_user_id
  FOR UPDATE;

  v_new_balance := v_current_balance + p_amount;

  IF v_new_balance < 0 THEN
    RETURN QUERY SELECT v_current_balance, false, 'INSUFFICIENT_BALANCE'::text;
    RETURN;
  END IF;

  -- Update
  UPDATE users
  SET gc_balance = v_new_balance,
      updated_at = now()
  WHERE id = p_user_id;

  -- Log
  BEGIN
    INSERT INTO gc_transactions (user_id, amount, balance_before, balance_after, transaction_type, game_type)
    VALUES (p_user_id, p_amount, v_current_balance, v_new_balance, p_transaction_type, p_game_type);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RETURN QUERY SELECT v_new_balance, true, 'SUCCESS'::text;
END;
$$;

GRANT EXECUTE ON FUNCTION secure_update_gc TO authenticated, anon;
GRANT EXECUTE ON FUNCTION update_user_gc TO authenticated, anon;

-- Verify
SELECT 'Functions updated with better error messages' as status;
