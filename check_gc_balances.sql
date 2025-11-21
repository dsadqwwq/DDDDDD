-- ============================================
-- CHECK GC BALANCES AND RANKINGS
-- ============================================

-- Check 1: What GC balances exist?
SELECT
  'GC Balance Distribution' as check,
  gc_balance,
  COUNT(*) as user_count
FROM users
GROUP BY gc_balance
ORDER BY gc_balance DESC
LIMIT 20;

-- Check 2: Top 10 users by GC
SELECT
  'Top 10 Users' as check,
  ROW_NUMBER() OVER (ORDER BY gc_balance DESC, created_at ASC) as rank,
  display_name,
  wallet_address,
  gc_balance
FROM users
ORDER BY gc_balance DESC, created_at ASC
LIMIT 10;

-- Check 3: Check your specific wallet
SELECT
  'Your Wallet' as check,
  display_name,
  wallet_address,
  gc_balance,
  (SELECT COUNT(*) + 1 FROM users u2 WHERE u2.gc_balance > u1.gc_balance) as rank
FROM users u1
WHERE LOWER(wallet_address) = LOWER('0x8eb8e0ffd835cf37cff5d55b768708dd1c8f9e70');
