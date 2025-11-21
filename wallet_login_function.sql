-- =====================================================
-- WALLET LOGIN FUNCTION (UPDATED FOR GC SYSTEM)
-- =====================================================
-- This function is from the 001_gc_quest_system migration
-- It returns JSON and uses gc_balance instead of gp_balance

CREATE OR REPLACE FUNCTION login_with_wallet(p_wallet_address VARCHAR)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user RECORD;
  v_nft_holdings JSON;
BEGIN
  -- Find user
  SELECT * INTO v_user
  FROM users u
  WHERE LOWER(u.wallet_address) = LOWER(p_wallet_address);

  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Wallet not registered');
  END IF;

  -- Check NFT holdings and update quests if needed
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

-- Grant execute permission to everyone (it's safe - only returns data for the wallet that was provided)
GRANT EXECUTE ON FUNCTION login_with_wallet TO authenticated, anon;

-- Verification
SELECT 'Wallet login function updated for GC system!' as status;
