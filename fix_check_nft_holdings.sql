-- ============================================
-- FIX check_nft_holdings FUNCTION
-- ============================================
-- Each NFT holder table uses different column names:
-- - fluffle_holders: HolderAddress
-- - bunnz_holders: HolderAddress
-- - megalio_holders: Address
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
  v_has_megalio BOOLEAN := FALSE;
BEGIN
  -- Check fluffle_holders table (uses HolderAddress column)
  SELECT EXISTS(
    SELECT 1 FROM fluffle_holders
    WHERE LOWER("HolderAddress") = LOWER(p_wallet_address)
  ) INTO v_has_fluffle;

  -- Check bunnz_holders table (uses HolderAddress column)
  SELECT EXISTS(
    SELECT 1 FROM bunnz_holders
    WHERE LOWER("HolderAddress") = LOWER(p_wallet_address)
  ) INTO v_has_bunnz;

  -- Check megalio_holders table (uses Address column)
  SELECT EXISTS(
    SELECT 1 FROM megalio_holders
    WHERE LOWER("Address") = LOWER(p_wallet_address)
  ) INTO v_has_megalio;

  RETURN json_build_object(
    'has_fluffle', v_has_fluffle,
    'has_bunnz', v_has_bunnz,
    'has_megalio', v_has_megalio
  );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION check_nft_holdings TO authenticated, anon;

-- Verify
SELECT 'check_nft_holdings function fixed for all NFT tables!' as status;
