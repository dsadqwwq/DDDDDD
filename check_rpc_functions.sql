-- Check if all required RPC functions exist
SELECT
  routine_name,
  routine_type,
  data_type as return_type
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

-- If the above returns empty, the functions don't exist!
-- You need to run the full supabase_migration.sql
