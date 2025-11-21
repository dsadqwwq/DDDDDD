-- ============================================
-- CHECK LEADERBOARD AND RANKINGS
-- ============================================

-- Check 1: Show top 10 users by gc_balance
SELECT
  'Top 10 by GC Balance' as check,
  ROW_NUMBER() OVER (ORDER BY gc_balance DESC, created_at ASC) as rank,
  display_name,
  gc_balance,
  wallet_address,
  created_at
FROM users
ORDER BY gc_balance DESC, created_at ASC
LIMIT 10;

-- Check 2: Test get_user_rank function for your wallet
-- Replace with the actual wallet address that's showing rank #1
SELECT
  'Your Rank Test' as check,
  *
FROM get_user_rank(
  (SELECT id FROM users WHERE LOWER(wallet_address) = LOWER('0xd015e4c87f0b5d40868b91eb8b488a3ac56c7e99'))
);

-- Check 3: Show distribution of gc_balance values
SELECT
  'GC Balance Distribution' as check,
  gc_balance,
  COUNT(*) as user_count
FROM users
GROUP BY gc_balance
ORDER BY gc_balance DESC;

-- Check 4: Check if your wallet is actually in the users table
SELECT
  'Your User Record' as check,
  id,
  display_name,
  wallet_address,
  gc_balance,
  created_at
FROM users
WHERE LOWER(wallet_address) = LOWER('0xd015e4c87f0b5d40868b91eb8b488a3ac56c7e99');
