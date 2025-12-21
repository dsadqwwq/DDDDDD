-- Export top 70 wallet addresses ordered by GC balance
-- Copy and paste this into your Supabase SQL Editor

SELECT
  wallet_address,
  display_name,
  gc_balance,
  created_at
FROM users
WHERE wallet_address IS NOT NULL
ORDER BY gc_balance DESC
LIMIT 70;

-- Alternative: Just wallet addresses as a simple list
-- SELECT wallet_address
-- FROM users
-- WHERE wallet_address IS NOT NULL
-- ORDER BY gc_balance DESC
-- LIMIT 70;

-- Alternative: Export as comma-separated values for easy copying
-- SELECT STRING_AGG(wallet_address, ', ') as wallet_list
-- FROM (
--   SELECT wallet_address
--   FROM users
--   WHERE wallet_address IS NOT NULL
--   ORDER BY gc_balance DESC
--   LIMIT 70
-- ) AS top_wallets;
