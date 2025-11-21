-- ============================================
-- CHECK WHAT'S IN THE USERS TABLE
-- ============================================
-- Run this to see what wallet addresses exist

-- Check 1: How many users exist?
SELECT
  'User Count' as check,
  COUNT(*) as total_users,
  COUNT(wallet_address) as users_with_wallet,
  COUNT(CASE WHEN wallet_address IS NOT NULL AND wallet_address != '' THEN 1 END) as users_with_valid_wallet
FROM users;

-- Check 2: Show sample wallet addresses (first 10)
SELECT
  'Sample Wallets' as check,
  id,
  display_name,
  wallet_address,
  gc_balance,
  created_at
FROM users
WHERE wallet_address IS NOT NULL
ORDER BY created_at DESC
LIMIT 10;

-- Check 3: Test the login function with a real wallet from your DB
-- Replace 'PASTE_WALLET_HERE' with an actual wallet address from Check 2
-- SELECT login_with_wallet('PASTE_WALLET_HERE');
