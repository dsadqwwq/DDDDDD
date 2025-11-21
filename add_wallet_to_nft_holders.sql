-- ============================================
-- ADD WALLET TO ALL NFT HOLDER LISTS
-- ============================================
-- Adds 0x8eb8e0ffd835cf37cff5d55b768708dd1c8f9e70 to all NFT holder tables

-- Add to fluffle_holders
INSERT INTO fluffle_holders ("HolderAddress", "Quantity", "PendingBalanceUpdate")
VALUES ('0x8eb8e0ffd835cf37cff5d55b768708dd1c8f9e70', 1, false)
ON CONFLICT DO NOTHING;

-- Add to bunnz_holders
INSERT INTO bunnz_holders ("HolderAddress", "Quantity", "PendingBalanceUpdate")
VALUES ('0x8eb8e0ffd835cf37cff5d55b768708dd1c8f9e70', 1, false)
ON CONFLICT DO NOTHING;

-- Add to megalio_holders
INSERT INTO megalio_holders ("Address", "Quantity", "Rank", "Percentage")
VALUES ('0x8eb8e0ffd835cf37cff5d55b768708dd1c8f9e70', 1, 1, 0.01)
ON CONFLICT DO NOTHING;

-- Verify
SELECT 'Wallet added to all NFT holder lists!' as status;
