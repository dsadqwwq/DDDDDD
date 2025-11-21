-- ============================================
-- CHECK NFT HOLDER TABLE STRUCTURE
-- ============================================

-- Check what columns exist in fluffle_holders
SELECT
  'fluffle_holders columns' as table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'fluffle_holders'
ORDER BY ordinal_position;

-- Check what columns exist in bunnz_holders
SELECT
  'bunnz_holders columns' as table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'bunnz_holders'
ORDER BY ordinal_position;

-- Show sample data from fluffle_holders
SELECT 'fluffle_holders sample' as info, * FROM fluffle_holders LIMIT 3;

-- Show sample data from bunnz_holders
SELECT 'bunnz_holders sample' as info, * FROM bunnz_holders LIMIT 3;
