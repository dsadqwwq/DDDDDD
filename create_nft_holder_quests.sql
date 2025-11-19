-- NFT Holder Quest System
-- This creates a table to track NFT holders and a function to auto-complete quests

-- Create table to store NFT holders (whitelist)
CREATE TABLE IF NOT EXISTS nft_holders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_address TEXT NOT NULL,
  contract_name TEXT NOT NULL, -- 'bunnz' or 'fluffle'
  verified_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(wallet_address, contract_name)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_nft_holders_wallet ON nft_holders(wallet_address);

-- Enable RLS
ALTER TABLE nft_holders ENABLE ROW LEVEL SECURITY;

-- Allow read access
CREATE POLICY "Anyone can read nft_holders" ON nft_holders
  FOR SELECT USING (true);

-- Function to check NFT holder status and auto-complete quests
CREATE OR REPLACE FUNCTION check_nft_holder_quests(
  p_user_id UUID,
  p_wallet_address TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_contract TEXT;
  v_quest_id TEXT;
  v_today DATE := CURRENT_DATE;
BEGIN
  -- Check for each NFT contract the user might hold
  FOR v_contract, v_quest_id IN
    VALUES ('bunnz', 'bunnz_holder'), ('fluffle', 'fluffle_holder')
  LOOP
    -- Check if wallet is in the holders table for this contract
    IF EXISTS (
      SELECT 1 FROM nft_holders
      WHERE wallet_address = LOWER(p_wallet_address)
      AND contract_name = v_contract
    ) THEN
      -- User is a holder, mark quest as complete (progress = 1, target = 1)
      INSERT INTO quests (user_id, quest_id, progress, reset_date)
      VALUES (p_user_id, v_quest_id, 1, v_today)
      ON CONFLICT (user_id, quest_id, reset_date)
      DO UPDATE SET progress = GREATEST(quests.progress, 1);
    END IF;
  END LOOP;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION check_nft_holder_quests(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION check_nft_holder_quests(UUID, TEXT) TO anon;

-- Example: Add yourself as a BAD BUNNZ holder
-- Replace with your actual wallet address
-- INSERT INTO nft_holders (wallet_address, contract_name)
-- VALUES ('0xYourWalletAddress', 'bunnz');
