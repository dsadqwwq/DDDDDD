-- ============================================
-- REMOVE ALL ZEZIMA USERS (ALL VARIATIONS)
-- ============================================
-- This script finds and removes all users with display_name containing ZEZIMA
-- (including ZEZIMA49, ZEZIMA1, ZEZIMA2, etc.)

-- Step 1: Check how many ZEZIMA users exist
SELECT
  'ZEZIMA Users Count' as check_type,
  COUNT(*) as total_zezima_users
FROM users
WHERE display_name ILIKE '%ZEZIMA%';

-- Step 2: Show the ZEZIMA users that will be deleted
SELECT
  'Users to be deleted' as info,
  id,
  display_name,
  wallet_address,
  email,
  gc_balance,
  created_at
FROM users
WHERE display_name ILIKE '%ZEZIMA%'
ORDER BY created_at DESC;

-- Step 3: Delete related data first (to avoid foreign key issues)

-- Delete user quests
DELETE FROM user_quests
WHERE user_id IN (
  SELECT id FROM users WHERE display_name ILIKE '%ZEZIMA%'
);

-- Delete user NFT holdings
DELETE FROM user_nft_holdings
WHERE user_id IN (
  SELECT id FROM users WHERE display_name ILIKE '%ZEZIMA%'
);

-- Delete staking records if they exist
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_staking') THEN
    DELETE FROM user_staking
    WHERE user_id IN (
      SELECT id FROM users WHERE display_name ILIKE '%ZEZIMA%'
    );
  END IF;
END $$;

-- Delete referral earnings
DELETE FROM referral_earnings
WHERE user_id IN (
  SELECT id FROM users WHERE display_name ILIKE '%ZEZIMA%'
) OR referrer_id IN (
  SELECT id FROM users WHERE display_name ILIKE '%ZEZIMA%'
);

-- Step 4: Delete the ZEZIMA users themselves
DELETE FROM users
WHERE display_name ILIKE '%ZEZIMA%';

-- Step 5: Verify deletion
SELECT
  'Verification: Remaining ZEZIMA users' as check_type,
  COUNT(*) as remaining_zezima_users
FROM users
WHERE display_name ILIKE '%ZEZIMA%';

-- Step 6: Show total user count after cleanup
SELECT
  'Total Users After Cleanup' as check_type,
  COUNT(*) as total_users
FROM users;
