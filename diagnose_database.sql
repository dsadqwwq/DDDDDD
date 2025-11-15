-- DIAGNOSTIC SCRIPT: Check what's wrong with your database setup
-- Run this in Supabase SQL Editor to see what's missing

-- 1. Check if required tables exist
SELECT
  CASE WHEN EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'users')
    THEN '✅ users table exists'
    ELSE '❌ users table MISSING'
  END as users_table,
  CASE WHEN EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'codes')
    THEN '✅ codes table exists'
    ELSE '❌ codes table MISSING'
  END as codes_table,
  CASE WHEN EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'scores')
    THEN '✅ scores table exists'
    ELSE '❌ scores table MISSING'
  END as scores_table,
  CASE WHEN EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'quests')
    THEN '✅ quests table exists'
    ELSE '❌ quests table MISSING'
  END as quests_table;

-- 2. Check users table structure
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'users'
ORDER BY ordinal_position;

-- 3. Check codes table structure
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'codes'
ORDER BY ordinal_position;

-- 4. Check if RPC functions exist
SELECT
  routine_name,
  CASE WHEN routine_name = 'create_user_codes' THEN '✅ REQUIRED FOR REGISTRATION' ELSE '⚠️ Optional' END as importance
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'create_user_codes',
    'get_leaderboard',
    'get_user_best_time',
    'update_quest_progress',
    'claim_quest_reward'
  )
ORDER BY routine_name;

-- 5. Check if there are any available codes
SELECT COUNT(*) as available_codes
FROM codes
WHERE used_by IS NULL;

-- If you get errors running any of the above queries,
-- that tells you what's missing!
