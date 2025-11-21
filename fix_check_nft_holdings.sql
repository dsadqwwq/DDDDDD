-- ============================================
-- FIX check_nft_holdings FUNCTION
-- ============================================
-- The function was looking for 'wallet_address' column
-- but the actual column is 'HolderAddress' (capitalized)
-- ============================================

DROP FUNCTION IF EXISTS check_nft_holdings(varchar);

CREATE OR REPLACE FUNCTION check_nft_holdings(p_wallet_address VARCHAR)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_has_fluffle BOOLEAN := FALSE;
  v_has_bunnz BOOLEAN := FALSE;
BEGIN
  -- Check fluffle_holders table (use HolderAddress column)
  SELECT EXISTS(
    SELECT 1 FROM fluffle_holders
    WHERE LOWER("HolderAddress") = LOWER(p_wallet_address)
  ) INTO v_has_fluffle;

  -- Check bunnz_holders table (use HolderAddress column)
  SELECT EXISTS(
    SELECT 1 FROM bunnz_holders
    WHERE LOWER("HolderAddress") = LOWER(p_wallet_address)
  ) INTO v_has_bunnz;

  RETURN json_build_object(
    'has_fluffle', v_has_fluffle,
    'has_bunnz', v_has_bunnz
  );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION check_nft_holdings TO authenticated, anon;

-- Verify
SELECT 'check_nft_holdings function fixed!' as status;
