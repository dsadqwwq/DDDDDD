-- =====================================================
-- FIX RPC PERMISSIONS - Grant functions to anon role
-- =====================================================
-- Run this if you're getting 404 errors when calling RPC functions
-- This grants execute permissions to the anonymous role

-- Grant execute on all GP functions to anon and authenticated users
GRANT EXECUTE ON FUNCTION get_user_gp(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION update_user_gp(uuid, bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION mines_start_game(uuid, bigint, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION mines_click_tile(uuid, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION mines_cashout(uuid) TO anon, authenticated;

-- Also grant the old function if it exists
GRANT EXECUTE ON FUNCTION get_user_best_time(uuid) TO anon, authenticated;

-- Verify grants were applied
SELECT
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('get_user_gp', 'update_user_gp', 'mines_start_game', 'mines_click_tile', 'mines_cashout');

-- Test the function works
SELECT get_user_gp('00000000-0000-0000-0000-000000000001'::uuid);
