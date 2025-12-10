-- ============================================
-- RENAME FUNCTIONS: GP → GC
-- ============================================
-- Makes naming consistent with gc_balance column

-- ============================================
-- 1. DROP OLD GP FUNCTIONS
-- ============================================

DROP FUNCTION IF EXISTS update_user_gp(uuid, bigint);
DROP FUNCTION IF EXISTS update_user_gp(uuid, bigint, text);
DROP FUNCTION IF EXISTS update_user_gp(uuid, bigint, text, text);
DROP FUNCTION IF EXISTS update_user_gp(uuid, bigint, text, text, uuid);
DROP FUNCTION IF EXISTS secure_update_gp(bigint, text, text, uuid);

-- ============================================
-- 2. CREATE NEW GC FUNCTIONS
-- ============================================

-- Main function: update_user_gc (replaces update_user_gp)
CREATE OR REPLACE FUNCTION public.update_user_gc(
  p_user_id uuid,
  p_amount bigint,
  p_transaction_type text DEFAULT 'general',
  p_game_type text DEFAULT NULL,
  p_reference_id uuid DEFAULT NULL
)
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

  -- Get current balance
  SELECT gc_balance INTO v_current_balance FROM users WHERE id = p_user_id FOR UPDATE;

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
  UPDATE users SET gc_balance = v_new_balance, updated_at = now() WHERE id = p_user_id;

  -- Log transaction
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'gc_transactions') THEN
    INSERT INTO gc_transactions (user_id, amount, balance_before, balance_after, transaction_type, game_type, reference_id)
    VALUES (p_user_id, p_amount, v_current_balance, v_new_balance, p_transaction_type, p_game_type, p_reference_id);
  END IF;

  RETURN QUERY SELECT v_new_balance, true, 'Balance updated';
END;
$function$;

-- Secure JWT-based function: secure_update_gc (replaces secure_update_gp)
CREATE OR REPLACE FUNCTION public.secure_update_gc(
  p_amount bigint,
  p_transaction_type text DEFAULT 'game',
  p_game_type text DEFAULT NULL,
  p_reference_id uuid DEFAULT NULL
)
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
  -- Get user from session
  v_auth_user_id := auth.uid();
  IF v_auth_user_id IS NULL THEN
    RETURN QUERY SELECT 0::bigint, false, 'Not authenticated';
    RETURN;
  END IF;

  -- Find user by auth_user_id
  SELECT id INTO v_user_id FROM users WHERE auth_user_id = v_auth_user_id;
  IF v_user_id IS NULL THEN
    SELECT id INTO v_user_id FROM users WHERE id = v_auth_user_id;
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

  -- Get current balance
  SELECT gc_balance INTO v_current_balance FROM users WHERE id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT 0::bigint, false, 'User not found';
    RETURN;
  END IF;

  -- Calculate new balance
  v_new_balance := v_current_balance + p_amount;
  IF v_new_balance < 0 THEN
    RETURN QUERY SELECT v_current_balance, false, 'Insufficient balance';
    RETURN;
  END IF;

  -- Update balance
  UPDATE users SET gc_balance = v_new_balance, updated_at = now() WHERE id = v_user_id;

  -- Log transaction
  BEGIN
    INSERT INTO gc_transactions (user_id, amount, balance_before, balance_after, transaction_type, game_type, reference_id)
    VALUES (v_user_id, p_amount, v_current_balance, v_new_balance, p_transaction_type, p_game_type, p_reference_id);
  EXCEPTION WHEN undefined_table THEN
    NULL;
  END;

  RETURN QUERY SELECT v_new_balance, true, 'Balance updated';
END;
$function$;

-- ============================================
-- 3. GRANT PERMISSIONS
-- ============================================

GRANT EXECUTE ON FUNCTION update_user_gc TO authenticated, anon;
GRANT EXECUTE ON FUNCTION secure_update_gc TO authenticated, anon;

-- ============================================
-- VERIFICATION
-- ============================================

SELECT routine_name FROM information_schema.routines
WHERE routine_name IN ('update_user_gc', 'secure_update_gc', 'update_user_gp', 'secure_update_gp')
AND routine_schema = 'public';
