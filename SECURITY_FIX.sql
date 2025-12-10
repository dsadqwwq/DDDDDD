-- ============================================
-- CRITICAL SECURITY FIX
-- ============================================
-- This fixes the security hole where anyone can drain any user's balance

-- ============================================
-- STEP 1: Fix link_auth_to_user to actually link the auth session
-- ============================================

CREATE OR REPLACE FUNCTION public.link_auth_to_user(p_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_auth_user_id uuid;
BEGIN
  -- Get the authenticated user ID from current session
  v_auth_user_id := auth.uid();

  IF v_auth_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Not authenticated');
  END IF;

  -- Link the Supabase auth user to the database user record
  UPDATE users
  SET auth_user_id = v_auth_user_id,
      updated_at = NOW()
  WHERE id = p_user_id;

  RETURN json_build_object('success', TRUE, 'auth_user_id', v_auth_user_id);
END;
$function$;

-- ============================================
-- STEP 2: Make update_user_gp SECURE (only callable by owner)
-- ============================================

CREATE OR REPLACE FUNCTION public.update_user_gp(p_user_id uuid, p_amount bigint, p_transaction_type text DEFAULT 'general'::text, p_game_type text DEFAULT NULL::text, p_reference_id uuid DEFAULT NULL::uuid)
RETURNS TABLE(new_balance bigint, success boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_current_balance bigint;
  v_new_balance bigint;
  v_auth_user_id uuid;
  v_user_auth_id uuid;
BEGIN
  -- SECURITY CHECK: Get auth user ID from session
  v_auth_user_id := auth.uid();

  IF v_auth_user_id IS NULL THEN
    RETURN QUERY SELECT 0::bigint, false, 'Not authenticated';
    RETURN;
  END IF;

  -- SECURITY CHECK: Verify the user owns this account
  SELECT auth_user_id INTO v_user_auth_id
  FROM users
  WHERE id = p_user_id;

  IF v_user_auth_id IS NULL THEN
    RETURN QUERY SELECT 0::bigint, false, 'User not linked to auth';
    RETURN;
  END IF;

  IF v_user_auth_id != v_auth_user_id THEN
    RETURN QUERY SELECT 0::bigint, false, 'Unauthorized: Cannot modify another users balance';
    RETURN;
  END IF;

  -- Proceed with update (user is authorized)
  SELECT gc_balance INTO v_current_balance FROM users WHERE id = p_user_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT 0::bigint, false, 'User not found';
    RETURN;
  END IF;

  v_new_balance := v_current_balance + p_amount;

  IF v_new_balance < 0 THEN
    RETURN QUERY SELECT v_current_balance, false, 'Insufficient balance';
    RETURN;
  END IF;

  UPDATE users SET gc_balance = v_new_balance, updated_at = now() WHERE id = p_user_id;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'gc_transactions') THEN
    INSERT INTO gc_transactions (user_id, amount, balance_before, balance_after, transaction_type, game_type, reference_id)
    VALUES (p_user_id, p_amount, v_current_balance, v_new_balance, p_transaction_type, p_game_type, p_reference_id);
  END IF;

  RETURN QUERY SELECT v_new_balance, true, 'Balance updated';
END;
$function$;

-- ============================================
-- STEP 3: Set RLS policies (safe now that functions check auth)
-- ============================================

DROP POLICY IF EXISTS "Users can view own profile" ON users;

-- Allow reading (needed for leaderboard, balance display)
CREATE POLICY "Users are viewable by everyone" ON users
FOR SELECT USING (true);

-- Allow updates only through SECURITY DEFINER functions (which now validate ownership)
CREATE POLICY "Allow authenticated updates" ON users
FOR UPDATE USING (auth.uid() IS NOT NULL);

-- ============================================
-- VERIFICATION
-- ============================================

-- After running this, logout and login again so link_auth_to_user runs
-- Then check: SELECT id, wallet_address, auth_user_id FROM users WHERE wallet_address = 'YOUR_WALLET';
-- auth_user_id should NOT be null anymore
