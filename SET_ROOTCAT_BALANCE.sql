-- ============================================
-- SET ROOTCAT's GC BALANCE TO 50,000
-- ============================================
-- Run this in Supabase SQL Editor

-- First, check ROOTCAT's current balance
SELECT
  id,
  display_name,
  gc_balance,
  wallet_address
FROM users
WHERE LOWER(display_name) = 'rootcat';

-- Update ROOTCAT's balance to 50,000
UPDATE users
SET gc_balance = 50000,
    updated_at = NOW()
WHERE LOWER(display_name) = 'rootcat';

-- Verify the update
SELECT
  id,
  display_name,
  gc_balance as new_balance,
  wallet_address,
  updated_at
FROM users
WHERE LOWER(display_name) = 'rootcat';

-- Optional: Add transaction log entry
INSERT INTO gc_transactions (user_id, amount, balance_before, balance_after, transaction_type, description)
SELECT
  id,
  50000 - gc_balance as amount,
  gc_balance as balance_before,
  50000 as balance_after,
  'admin_adjustment',
  'Balance reset by admin from 1B to 50K'
FROM users
WHERE LOWER(display_name) = 'rootcat';
