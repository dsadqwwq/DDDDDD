-- ============================================
-- FIX WALLET LOGIN ERROR
-- ============================================
-- This script fixes the "wallet not found" error by:
-- 1. Ensuring gc_balance column exists
-- 2. Recreating the correct login_with_wallet function
-- 3. Fixing get_user_rank function
-- ============================================

-- STEP 1: Ensure gc_balance column exists (rename from gp_balance if needed)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'gp_balance') THEN
    ALTER TABLE users RENAME COLUMN gp_balance TO gc_balance;
    RAISE NOTICE 'Renamed gp_balance to gc_balance';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'gc_balance') THEN
    ALTER TABLE users ADD COLUMN gc_balance BIGINT DEFAULT 0;
    RAISE NOTICE 'Added gc_balance column';
  END IF;
END $$;

-- STEP 2: Drop old functions first (needed to change return types)
DROP FUNCTION IF EXISTS login_with_wallet(text);
DROP FUNCTION IF EXISTS login_with_wallet(varchar);
DROP FUNCTION IF EXISTS get_user_rank(uuid);

-- STEP 3: Recreate the correct login_with_wallet function
CREATE OR REPLACE FUNCTION login_with_wallet(p_wallet_address VARCHAR)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user RECORD;
  v_nft_holdings JSON;
BEGIN
  -- Find user with explicit table alias
  SELECT * INTO v_user
  FROM users u
  WHERE LOWER(u.wallet_address) = LOWER(p_wallet_address);

  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Wallet not registered');
  END IF;

  -- Check NFT holdings and update quests if needed
  -- Only if the check_nft_holdings function exists
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'check_nft_holdings') THEN
    v_nft_holdings := check_nft_holdings(p_wallet_address);

    -- Update FLUFFLE quest if holder
    IF (v_nft_holdings->>'has_fluffle')::boolean THEN
      UPDATE user_quests
      SET progress = 1,
          is_completed = TRUE,
          completed_at = COALESCE(completed_at, NOW()),
          updated_at = NOW()
      WHERE user_id = v_user.id AND quest_id = 'fluffle_holder' AND NOT is_completed;
    END IF;

    -- Update BUNNZ quest if holder
    IF (v_nft_holdings->>'has_bunnz')::boolean THEN
      UPDATE user_quests
      SET progress = 1,
          is_completed = TRUE,
          completed_at = COALESCE(completed_at, NOW()),
          updated_at = NOW()
      WHERE user_id = v_user.id AND quest_id = 'bunnz_holder' AND NOT is_completed;
    END IF;
  ELSE
    -- No NFT checking function, return default
    v_nft_holdings := json_build_object('has_fluffle', false, 'has_bunnz', false);
  END IF;

  RETURN json_build_object(
    'success', TRUE,
    'user_id', v_user.id,
    'display_name', v_user.display_name,
    'gc_balance', v_user.gc_balance,
    'has_fluffle', (v_nft_holdings->>'has_fluffle')::boolean,
    'has_bunnz', (v_nft_holdings->>'has_bunnz')::boolean
  );
END;
$$;

-- STEP 4: Fix get_user_rank function
CREATE OR REPLACE FUNCTION get_user_rank(p_user_id uuid)
RETURNS TABLE(rank bigint, user_gc_balance bigint)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH ranked_users AS (
    SELECT
      u.id,
      u.gc_balance,
      ROW_NUMBER() OVER (ORDER BY u.gc_balance DESC, u.created_at ASC) as user_rank
    FROM users u
  )
  SELECT
    r.user_rank::bigint,
    r.gc_balance::bigint
  FROM ranked_users r
  WHERE r.id = p_user_id;
END;
$$;

-- STEP 5: Grant permissions
GRANT EXECUTE ON FUNCTION login_with_wallet TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_user_rank(uuid) TO authenticated, anon;

-- Verification
SELECT
  'Fix applied successfully!' as status,
  EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'gc_balance') as has_gc_balance,
  EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'login_with_wallet') as has_login_function,
  EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_user_rank') as has_rank_function;
