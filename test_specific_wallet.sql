-- ============================================
-- TEST SPECIFIC WALLET LOGIN
-- ============================================

-- Test 1: Check if this exact wallet exists
SELECT
  'Exact Match Test' as test,
  COUNT(*) as found
FROM users
WHERE wallet_address = '0xd015e4c87f0b5d40868b91eb8b488a3ac56c7e99';

-- Test 2: Check with LOWER() (case insensitive)
SELECT
  'Case Insensitive Test' as test,
  COUNT(*) as found
FROM users
WHERE LOWER(wallet_address) = LOWER('0xd015e4c87f0b5d40868b91eb8b488a3ac56c7e99');

-- Test 3: Check what wallets ARE in the database
SELECT
  'All Wallets in DB' as test,
  wallet_address,
  display_name,
  gc_balance
FROM users
WHERE wallet_address IS NOT NULL
ORDER BY created_at DESC
LIMIT 20;

-- Test 4: Try to login with this wallet
SELECT login_with_wallet('0xd015e4c87f0b5d40868b91eb8b488a3ac56c7e99') as login_result;
