-- ============================================
-- FIX FUNCTION OVERLOADING CONFLICT
-- ============================================
-- Remove all versions of update_user_gp and create only ONE

-- Drop all existing versions
DROP FUNCTION IF EXISTS update_user_gp(uuid, bigint);
DROP FUNCTION IF EXISTS update_user_gp(uuid, bigint, text);
DROP FUNCTION IF EXISTS update_user_gp(uuid, bigint, text, text);
DROP FUNCTION IF EXISTS update_user_gp(uuid, bigint, text, text, uuid);

-- Create single version with all parameters (defaults for optional ones)
CREATE OR REPLACE FUNCTION public.update_user_gp(
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

-- Verify only one version exists now
SELECT routine_name, string_agg(parameter_name, ', ' ORDER BY ordinal_position) as parameters
FROM information_schema.routines r
LEFT JOIN information_schema.parameters p ON r.specific_name = p.specific_name
WHERE routine_name = 'update_user_gp' AND routine_schema = 'public'
GROUP BY routine_name, r.specific_name;
