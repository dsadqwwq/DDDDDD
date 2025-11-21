-- ============================================
-- TEST get_user_rank FUNCTION
-- ============================================

-- Test with your wallet
SELECT
  'Test get_user_rank' as test,
  *
FROM get_user_rank(
  (SELECT id FROM users WHERE LOWER(wallet_address) = LOWER('0x8eb8e0ffd835cf37cff5d55b768708dd1c8f9e70'))
);

-- Compare with manual calculation
SELECT
  'Manual Rank Check' as test,
  display_name,
  gc_balance,
  (SELECT COUNT(*) + 1 FROM users u2 WHERE u2.gc_balance > u1.gc_balance) as calculated_rank
FROM users u1
WHERE LOWER(wallet_address) = LOWER('0x8eb8e0ffd835cf37cff5d55b768708dd1c8f9e70');
