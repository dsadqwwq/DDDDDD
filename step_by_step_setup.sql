-- =====================================================
-- STEP-BY-STEP SETUP - Run this section by section
-- =====================================================
-- Copy and paste each section ONE AT A TIME into Supabase SQL Editor
-- Check for errors after each step before proceeding

-- =====================================================
-- STEP 1: Verify column exists
-- =====================================================
-- Run this first to confirm the gp_balance column was created

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'gp_balance';

-- Expected: Should show one row with 'gp_balance' and 'bigint'
-- If empty, run this:
-- ALTER TABLE users ADD COLUMN IF NOT EXISTS gp_balance bigint DEFAULT 1000;

-- =====================================================
-- STEP 2: Create get_user_gp function (SIMPLE VERSION)
-- =====================================================
-- Run this next - just creates the GET function

CREATE OR REPLACE FUNCTION public.get_user_gp(p_user_id uuid)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance bigint;
BEGIN
  SELECT gp_balance INTO v_balance
  FROM public.users
  WHERE id = p_user_id;

  RETURN COALESCE(v_balance, 0);
END;
$$;

-- Grant permissions immediately
GRANT EXECUTE ON FUNCTION public.get_user_gp(uuid) TO anon, authenticated;

-- =====================================================
-- STEP 3: Verify function was created
-- =====================================================
-- Run this to confirm

SELECT routine_name, routine_schema
FROM information_schema.routines
WHERE routine_name = 'get_user_gp';

-- Expected: Should show one row with 'get_user_gp' and 'public'

-- =====================================================
-- STEP 4: Test the function
-- =====================================================
-- Run this to make sure it works

SELECT public.get_user_gp('00000000-0000-0000-0000-000000000001'::uuid) as test_balance;

-- Expected: Should return 5000 (the test user's balance)

-- =====================================================
-- STEP 5: Create update_user_gp function
-- =====================================================
-- Only run this AFTER steps 1-4 work!

CREATE OR REPLACE FUNCTION public.update_user_gp(
  p_user_id uuid,
  p_amount bigint
)
RETURNS TABLE(new_balance bigint, success boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_balance bigint;
  v_new_balance bigint;
BEGIN
  -- Get current balance with row lock
  SELECT gp_balance INTO v_current_balance
  FROM public.users
  WHERE id = p_user_id
  FOR UPDATE;

  -- Check if user exists
  IF NOT FOUND THEN
    RETURN QUERY SELECT 0::bigint, false, 'User not found';
    RETURN;
  END IF;

  -- Calculate new balance
  v_new_balance := v_current_balance + p_amount;

  -- Prevent negative balance
  IF v_new_balance < 0 THEN
    RETURN QUERY SELECT v_current_balance, false, 'Insufficient balance';
    RETURN;
  END IF;

  -- Update balance
  UPDATE public.users
  SET gp_balance = v_new_balance,
      updated_at = now()
  WHERE id = p_user_id;

  -- Return success
  RETURN QUERY SELECT v_new_balance, true, 'Balance updated';
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.update_user_gp(uuid, bigint) TO anon, authenticated;

-- =====================================================
-- STEP 6: Test update function
-- =====================================================

SELECT * FROM public.update_user_gp('00000000-0000-0000-0000-000000000001'::uuid, 100);

-- Expected: new_balance = 5100, success = true

-- =====================================================
-- STEP 7: Create mines_games table
-- =====================================================

CREATE TABLE IF NOT EXISTS public.mines_games (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  bet_amount bigint NOT NULL,
  mines_count integer NOT NULL,
  mine_positions integer[] NOT NULL,
  revealed_tiles integer[] DEFAULT '{}',
  status text DEFAULT 'active',
  payout bigint DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  ended_at timestamp with time zone
);

CREATE INDEX IF NOT EXISTS idx_mines_games_user ON public.mines_games(user_id);
CREATE INDEX IF NOT EXISTS idx_mines_games_status ON public.mines_games(status);

-- Enable RLS
ALTER TABLE public.mines_games ENABLE ROW LEVEL SECURITY;

-- Create policies
DROP POLICY IF EXISTS "Users can view own games" ON public.mines_games;
CREATE POLICY "Users can view own games" ON public.mines_games
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "No direct manipulation" ON public.mines_games;
CREATE POLICY "No direct manipulation" ON public.mines_games
  FOR ALL USING (false);

-- =====================================================
-- STEP 8: Create mines_start_game function
-- =====================================================

CREATE OR REPLACE FUNCTION public.mines_start_game(
  p_user_id uuid,
  p_bet_amount bigint,
  p_mines_count integer
)
RETURNS TABLE(game_id uuid, success boolean, message text, new_balance bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_game_id uuid;
  v_mine_positions integer[];
  v_update_result record;
  i integer;
  random_pos integer;
BEGIN
  -- Validate inputs
  IF p_bet_amount < 10 THEN
    RETURN QUERY SELECT null::uuid, false, 'Minimum bet is 10 GP', 0::bigint;
    RETURN;
  END IF;

  IF p_bet_amount > 10000 THEN
    RETURN QUERY SELECT null::uuid, false, 'Maximum bet is 10,000 GP', 0::bigint;
    RETURN;
  END IF;

  IF p_mines_count < 1 OR p_mines_count > 24 THEN
    RETURN QUERY SELECT null::uuid, false, 'Mines must be between 1 and 24', 0::bigint;
    RETURN;
  END IF;

  -- Deduct bet amount
  SELECT * INTO v_update_result
  FROM public.update_user_gp(p_user_id, -p_bet_amount);

  IF NOT v_update_result.success THEN
    RETURN QUERY SELECT null::uuid, false, v_update_result.message, 0::bigint;
    RETURN;
  END IF;

  -- Generate random mine positions
  v_mine_positions := ARRAY[]::integer[];
  FOR i IN 1..p_mines_count LOOP
    LOOP
      random_pos := floor(random() * 25)::integer;
      IF NOT (random_pos = ANY(v_mine_positions)) THEN
        v_mine_positions := array_append(v_mine_positions, random_pos);
        EXIT;
      END IF;
    END LOOP;
  END LOOP;

  -- Create game record
  INSERT INTO public.mines_games (user_id, bet_amount, mines_count, mine_positions, status)
  VALUES (p_user_id, p_bet_amount, p_mines_count, v_mine_positions, 'active')
  RETURNING id INTO v_game_id;

  RETURN QUERY SELECT v_game_id, true, 'Game started', v_update_result.new_balance;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.mines_start_game(uuid, bigint, integer) TO anon, authenticated;

-- =====================================================
-- STEP 9: Create mines_click_tile function
-- =====================================================

CREATE OR REPLACE FUNCTION public.mines_click_tile(
  p_game_id uuid,
  p_tile_index integer
)
RETURNS TABLE(
  result text,
  mine_positions integer[],
  multiplier numeric,
  new_balance bigint,
  game_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_game record;
  v_is_mine boolean;
  v_multiplier numeric;
  v_tiles_revealed integer;
  v_safe_tiles integer;
BEGIN
  -- Get game
  SELECT * INTO v_game
  FROM public.mines_games
  WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status != 'active' THEN
    RETURN QUERY SELECT 'invalid_game'::text, null::integer[], 0::numeric, 0::bigint, 'invalid'::text;
    RETURN;
  END IF;

  -- Check if already revealed
  IF p_tile_index = ANY(v_game.revealed_tiles) THEN
    RETURN QUERY SELECT 'already_revealed'::text, null::integer[], 0::numeric, 0::bigint, v_game.status;
    RETURN;
  END IF;

  -- Check if it's a mine
  v_is_mine := p_tile_index = ANY(v_game.mine_positions);

  IF v_is_mine THEN
    -- Hit a mine! Game over
    UPDATE public.mines_games
    SET status = 'lost',
        ended_at = now()
    WHERE id = p_game_id;

    RETURN QUERY SELECT
      'mine'::text,
      v_game.mine_positions,
      0::numeric,
      (SELECT gp_balance FROM public.users WHERE id = v_game.user_id),
      'lost'::text;
    RETURN;
  ELSE
    -- Safe tile!
    UPDATE public.mines_games
    SET revealed_tiles = array_append(revealed_tiles, p_tile_index)
    WHERE id = p_game_id;

    v_tiles_revealed := array_length(v_game.revealed_tiles, 1) + 1;
    v_safe_tiles := 25 - v_game.mines_count;
    v_multiplier := 1.0 + (v_tiles_revealed::numeric / v_safe_tiles::numeric) * 2.0;

    RETURN QUERY SELECT
      'safe'::text,
      null::integer[],
      v_multiplier,
      (SELECT gp_balance FROM public.users WHERE id = v_game.user_id),
      'active'::text;
    RETURN;
  END IF;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.mines_click_tile(uuid, integer) TO anon, authenticated;

-- =====================================================
-- STEP 10: Create mines_cashout function
-- =====================================================

CREATE OR REPLACE FUNCTION public.mines_cashout(p_game_id uuid)
RETURNS TABLE(
  success boolean,
  payout bigint,
  new_balance bigint,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_game record;
  v_multiplier numeric;
  v_payout bigint;
  v_update_result record;
BEGIN
  -- Get game
  SELECT * INTO v_game
  FROM public.mines_games
  WHERE id = p_game_id;

  IF NOT FOUND OR v_game.status != 'active' THEN
    RETURN QUERY SELECT false, 0::bigint, 0::bigint, 'Invalid game or already ended';
    RETURN;
  END IF;

  -- Must have revealed at least one tile
  IF array_length(v_game.revealed_tiles, 1) IS NULL THEN
    RETURN QUERY SELECT false, 0::bigint, 0::bigint, 'Must reveal at least one tile before cashing out';
    RETURN;
  END IF;

  -- Calculate payout
  v_multiplier := 1.0 + (array_length(v_game.revealed_tiles, 1)::numeric / (25 - v_game.mines_count)::numeric) * 2.0;
  v_payout := floor(v_game.bet_amount * v_multiplier)::bigint;

  -- Add winnings
  SELECT * INTO v_update_result
  FROM public.update_user_gp(v_game.user_id, v_payout);

  -- Update game status
  UPDATE public.mines_games
  SET status = 'cashed_out',
      payout = v_payout,
      ended_at = now()
  WHERE id = p_game_id;

  RETURN QUERY SELECT true, v_payout, v_update_result.new_balance, 'Cashed out successfully';
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.mines_cashout(uuid) TO anon, authenticated;

-- =====================================================
-- FINAL VERIFICATION
-- =====================================================

SELECT 'Setup Complete!' as status,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'get_user_gp') as has_get_gp,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'update_user_gp') as has_update_gp,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'mines_start_game') as has_mines_start,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'mines_click_tile') as has_mines_click,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'mines_cashout') as has_mines_cashout;

-- All counts should be 1. If any are 0, go back and run that step again.
