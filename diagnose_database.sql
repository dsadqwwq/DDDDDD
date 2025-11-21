-- ============================================
-- DIAGNOSTIC SCRIPT - CHECK DATABASE STATE
-- ============================================
-- Run this FIRST to see what's wrong
-- This makes NO changes to your database
-- ============================================

-- Check 1: Does wallet_address column exist?
SELECT
  'Column Check' as test,
  EXISTS(SELECT 1 FROM information_schema.columns
         WHERE table_name = 'users' AND column_name = 'wallet_address') as has_wallet_address,
  EXISTS(SELECT 1 FROM information_schema.columns
         WHERE table_name = 'users' AND column_name = 'gc_balance') as has_gc_balance,
  EXISTS(SELECT 1 FROM information_schema.columns
         WHERE table_name = 'users' AND column_name = 'gp_balance') as has_gp_balance;

-- Check 2: What functions exist?
SELECT
  'Function Check' as test,
  routine_name,
  data_type as return_type
FROM information_schema.routines r
WHERE routine_name IN ('login_with_wallet', 'get_user_rank')
ORDER BY routine_name;

-- Check 3: Do the required tables exist?
SELECT
  'Table Check' as test,
  EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'users') as has_users,
  EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'user_quests') as has_user_quests,
  EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'fluffle_holders') as has_fluffle_holders,
  EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'bunnz_holders') as has_bunnz_holders;
