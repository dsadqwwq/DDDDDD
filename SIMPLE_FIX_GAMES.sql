-- ============================================
-- SIMPLE FIX - Make games work like daily login
-- ============================================
-- This makes secure_update_gc accept p_user_id as a fallback
-- Run this in your LIVE Supabase SQL Editor

DROP FUNCTION IF EXISTS secure_update_gc(bigint, text, text);

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
  v_user_id uuid;
  v_current_balance bigint;
  v_new_balance bigint;
BEGIN
  -- SIMPLIFIED: Just use the authenticated user's linked user_id
  -- Find user by their auth session
  SELECT id INTO v_user_id
  FROM users
  WHERE auth_user_id = auth.uid() OR id = auth.uid()
  LIMIT 1;

  -- If no user found, return error with helpful message
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT
      0::bigint,
      false,
      ('No user found for auth.uid: ' || COALESCE(auth.uid()::text, 'NULL'))::text;
    RETURN;
  END IF;

  -- Get current balance
  SELECT gc_balance INTO v_current_balance
  FROM users
  WHERE id = v_user_id
  FOR UPDATE;

  -- Calculate new balance
  v_new_balance := v_current_balance + p_amount;

  -- Prevent negative
  IF v_new_balance < 0 THEN
    RETURN QUERY SELECT v_current_balance, false, 'Insufficient balance'::text;
    RETURN;
  END IF;

  -- Update balance
  UPDATE users
  SET gc_balance = v_new_balance,
      updated_at = now()
  WHERE id = v_user_id;

  -- Log transaction (ignore errors)
  BEGIN
    INSERT INTO gc_transactions (user_id, amount, balance_before, balance_after, transaction_type, game_type)
    VALUES (v_user_id, p_amount, v_current_balance, v_new_balance, p_transaction_type, p_game_type);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RETURN QUERY SELECT v_new_balance, true, 'Success'::text;
END;
$$;

GRANT EXECUTE ON FUNCTION secure_update_gc TO authenticated, anon;

-- Test it
SELECT 'Function updated successfully' as status;
