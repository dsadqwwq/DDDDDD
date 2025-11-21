-- ============================================
-- DEBUG WHY WALLET ISN'T BEING FOUND
-- ============================================

-- Test 1: Show the EXACT stored value with length
SELECT
  'Stored Value Debug' as test,
  wallet_address,
  LENGTH(wallet_address) as length,
  LENGTH(TRIM(wallet_address)) as trimmed_length,
  LOWER(wallet_address) as lowercase_version,
  display_name
FROM users
WHERE wallet_address LIKE '%d015e4c87f0b5d40868b91eb8b488a3ac56c7e99%';

-- Test 2: Compare what we're looking for vs what's stored
SELECT
  'Comparison Test' as test,
  '0xd015e4c87f0b5d40868b91eb8b488a3ac56c7e99' as looking_for,
  wallet_address as stored_value,
  LOWER('0xd015e4c87f0b5d40868b91eb8b488a3ac56c7e99') as looking_for_lower,
  LOWER(wallet_address) as stored_lower,
  LOWER(wallet_address) = LOWER('0xd015e4c87f0b5d40868b91eb8b488a3ac56c7e99') as matches
FROM users
WHERE wallet_address LIKE '%d015e4c87f0b5d40868b91eb8b488a3ac56c7e99%';

-- Test 3: Try the exact query the function uses
SELECT
  'Function Query Test' as test,
  *
FROM users u
WHERE LOWER(u.wallet_address) = LOWER('0xd015e4c87f0b5d40868b91eb8b488a3ac56c7e99');

-- Test 4: Check for whitespace issues
SELECT
  'Whitespace Check' as test,
  wallet_address,
  REPLACE(wallet_address, ' ', '[SPACE]') as with_spaces_visible,
  REPLACE(wallet_address, E'\n', '[NEWLINE]') as with_newlines_visible
FROM users
WHERE wallet_address LIKE '%d015e4c87f0b5d40868b91eb8b488a3ac56c7e99%';
