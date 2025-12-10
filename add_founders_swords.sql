-- Create inventory_items table if it doesn't exist
CREATE TABLE IF NOT EXISTS inventory_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  item_type VARCHAR(50) NOT NULL,
  item_name VARCHAR(100) NOT NULL,
  item_description TEXT,
  item_rarity VARCHAR(20), -- common, rare, epic, legendary
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, item_type, item_name)
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_inventory_items_user_id ON inventory_items(user_id);
CREATE INDEX IF NOT EXISTS idx_inventory_items_type ON inventory_items(item_type);

-- Add Founder's Sword to supporter wallets
-- These are early supporters who earned the sword via Twitter/X
INSERT INTO inventory_items (user_id, item_type, item_name, item_description, item_rarity, metadata)
SELECT
  u.id,
  'nft',
  'Founder''s Sword',
  'A legendary katana awarded to early supporters and warriors. Symbol of honor and dedication to Duel PVP.',
  'legendary',
  jsonb_build_object(
    'awarded_for', 'Early Supporter',
    'awarded_via', 'Twitter/X Community',
    'mint_eligible', true,
    'svg_icon', 'katana'
  )
FROM (VALUES
  ('0x760880Fe6622FFf5634ACF3631fd359F9B5DEE03'::text),
  ('0xb7d4d167ccc5c1cf9d981e8f3c4ce846b9dbd646'::text),
  ('0xc5cd34ea0783a87e9b83ba1defff76752820b8f4'::text),
  ('0x27ec37f465e1755036cc854aa96dd304f82213e6'::text),
  ('0xC722085ecC989d911297F59822705a18bE2Cdd74'::text),
  ('0xc657be72fb748d2f54c80bb1529e0720f47f16fc'::text),
  ('0xda9f428eb55341e6ca887bccc2e01583dbc7764f'::text),
  ('0x74b5d9F1b06f4C49dD4204FAdf7C7Fd7b844656a'::text),
  ('0x176746e6f3be14F7C213Dc78049568c698Ce73Ea'::text),
  ('0x556e429CD4Be8a9F1AB962b8748BA0Ffe84aaEe0'::text),
  ('0x26fb5a72c214c1b3cf79d92053e793fc3d1807ba'::text),
  ('0x5ef6a47fa3991669347ba40b400d3a8e036efeeb'::text),
  ('0xf456cfe4d6fc24c60e15821078e0e36ac612c24c'::text),
  ('0x0adc1da5fdd9d7a24100177dd1bbc120dae40949'::text),
  ('0xfd7fa10d3500c17d91785bad2f0f0133b2cc93a1'::text),
  ('0xEBCF1cE5eEc0A7AC3d34925f632DDcaEA02E0269'::text),
  ('0x4076B57369A6c1782819050fc90Dc9759E861C32'::text),
  ('0x0cdff14583404b02f4a490f45fcafd56a0247b0f'::text),
  ('0x6766b4cce2a681d498b0d64e7e42cb7220e036a9'::text),
  ('0x0148e86cfb50c200575c26849c60b7314833b966'::text),
  ('0xd677e6458c75F3A875Aa98822cb6543f4ECf1177'::text),
  ('0x214f69de1a177eecdee5ff71a91813a04e9d97ad'::text),
  ('0xB77729E9C00a508351BD81f01657eB2DbAC247eA'::text),
  ('0xcf25a23d533f9156eab5dfb6c2520901b475214c'::text),
  ('0xb71D05cF5CdF7a9B15B20b9aaB5E91332C271c96'::text),
  ('0x606575aab57bcdfba7e55e21303df8eaab5a4453'::text),
  ('0x08fA63fc093916DfE218B5fCD2a3aa385b10305D'::text),
  ('0x48be3E69303d5CB6915B22232A93cC6b5168f393'::text),
  ('0x988c417a4ce7b60bb73d404ea543877b70857306'::text),
  ('0xf880258ecca89636dd69ae265c794c91cdda97b5'::text),
  ('0xD0d23Ca613DDc1fdbCB24664e5e88ba2339Cc487'::text),
  ('0x555efca17991f7a26442e017c7b373f5381892f3'::text),
  ('0xD015E4C87f0B5D40868B91eb8b488A3Ac56C7e99'::text),
  ('0xc6caa53c32c1005313bd4925dde2550609a03903'::text),
  ('0xcc50515B36D09e488ae46687A898c9D4975064d1'::text),
  ('0x641891a7e548d6d6669e56f4252bf387941e9242'::text),
  ('0x8E2A4Fa4a3AdDB8B8f0969356Bc1f360d9282D67'::text),
  ('0xf02f891690A4F79f84D022026b0cB0f86DB1f11D'::text),
  ('0xfcc4ac9196033cd368fbcff5c94e3428127a9389'::text),
  ('0x969b9750d85e0000c56d2e80e9f06c0586e174c6'::text),
  ('0x7d8B20cE5B06B674549062F0936F31864f06072a'::text),
  ('0x29565de1cf6981af0ec8f88ec992dfc3d0980798'::text),
  ('0x4F4C3a3AB3423866849B986B60Eb53Df2E8602E4'::text),
  ('0xD6cBA759373d40dE28C3d59e5369b590213583BC'::text),
  ('0xcedf982Ab0b15ad963D3b31c9640a4DbECC7ED25'::text),
  ('0xFC4f3809e02b02B204F859d38D7AcaB737169eB4'::text),
  ('0x2c5e88bdd7f14015d8c5d109e7cd52ae5f7b0fc1'::text)
) AS wallet_addresses(wallet_address)
INNER JOIN users u ON LOWER(u.wallet_address) = LOWER(wallet_addresses.wallet_address)
ON CONFLICT (user_id, item_type, item_name) DO NOTHING;

-- Verify the inserts
SELECT
  u.wallet_address,
  u.display_name,
  ii.item_name,
  ii.item_rarity,
  ii.created_at
FROM inventory_items ii
JOIN users u ON u.id = ii.user_id
WHERE ii.item_name = 'Founder''s Sword'
ORDER BY ii.created_at DESC;
