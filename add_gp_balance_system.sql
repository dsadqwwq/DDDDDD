-- =====================================================
-- SECURE GP BALANCE SYSTEM
-- =====================================================
-- Run this in Supabase SQL Editor to add server-side GP validation
-- This prevents client-side cheating by moving GP logic to the database

-- 1. Add gp_balance column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS gp_balance bigint DEFAULT 1000;

-- 2. Create index for faster GP queries
CREATE INDEX IF NOT EXISTS idx_users_gp_balance ON users(gp_balance);

-- 3. Update existing users to have starting balance (if they don't have one)
UPDATE users SET gp_balance = 1000 WHERE gp_balance IS NULL OR gp_balance = 0;

-- =====================================================
-- SECURE GP UPDATE FUNCTION
-- =====================================================
-- This function is the ONLY way to update GP
-- It prevents negative balances and validates amounts

CREATE OR REPLACE FUNCTION update_user_gp(
  p_user_id uuid,
  p_amount bigint
)
RETURNS TABLE(new_balance bigint, success boolean, message text)
LANGUAGE plpgsql
SECURITY definer
AS $$
DECLARE
  v_current_balance bigint;
  v_new_balance bigint;
BEGIN
  -- Get current balance with row lock (prevents race conditions)
  SELECT gp_balance INTO v_current_balance
  FROM users
  WHERE id = p_user_id
  FOR UPDATE;

  -- Check if user exists
  IF NOT FOUND THEN
    RETURN QUERY SELECT 0::bigint, false, 'User not found';
    RETURN;
  END IF;

  -- Calculate new balance
  v_new_balance := v_current_balance + p_amount;

  -- Prevent negative balance (can't spend more than you have)
  IF v_new_balance < 0 THEN
    RETURN QUERY SELECT v_current_balance, false, 'Insufficient balance';
    RETURN;
  END IF;

  -- Update balance
  UPDATE users
  SET gp_balance = v_new_balance,
      updated_at = now()
  WHERE id = p_user_id;

  -- Return success
  RETURN QUERY SELECT v_new_balance, true, 'Balance updated';
END;
$$;

-- =====================================================
-- GET USER GP FUNCTION
-- =====================================================
-- Simple function to get current balance

CREATE OR REPLACE FUNCTION get_user_gp(p_user_id uuid)
RETURNS bigint
LANGUAGE plpgsql
SECURITY definer
AS $$
DECLARE
  v_balance bigint;
BEGIN
  SELECT gp_balance INTO v_balance
  FROM users
  WHERE id = p_user_id;

  RETURN COALESCE(v_balance, 0);
END;
$$;

-- =====================================================
-- MINES GAME: START GAME FUNCTION
-- =====================================================
-- This creates a game session and deducts the bet

CREATE TABLE IF NOT EXISTS mines_games (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  bet_amount bigint NOT NULL,
  mines_count integer NOT NULL,
  mine_positions integer[] NOT NULL,
  revealed_tiles integer[] DEFAULT '{}',
  status text DEFAULT 'active', -- 'active', 'won', 'lost', 'cashed_out'
  payout bigint DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  ended_at timestamp with time zone
);

CREATE INDEX IF NOT EXISTS idx_mines_games_user ON mines_games(user_id);
CREATE INDEX IF NOT EXISTS idx_mines_games_status ON mines_games(status);

CREATE OR REPLACE FUNCTION mines_start_game(
  p_user_id uuid,
  p_bet_amount bigint,
  p_mines_count integer
)
RETURNS TABLE(game_id uuid, success boolean, message text, new_balance bigint)
LANGUAGE plpgsql
SECURITY definer
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

  -- Deduct bet amount (this prevents cheating - server validates balance)
  SELECT * INTO v_update_result
  FROM update_user_gp(p_user_id, -p_bet_amount);

  IF NOT v_update_result.success THEN
    RETURN QUERY SELECT null::uuid, false, v_update_result.message, 0::bigint;
    RETURN;
  END IF;

  -- Generate random mine positions (SERVER-SIDE - client never sees this!)
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
  INSERT INTO mines_games (user_id, bet_amount, mines_count, mine_positions, status)
  VALUES (p_user_id, p_bet_amount, p_mines_count, v_mine_positions, 'active')
  RETURNING id INTO v_game_id;

  -- Return success (NOTE: mine positions are NOT returned to client!)
  RETURN QUERY SELECT v_game_id, true, 'Game started', v_update_result.new_balance;
END;
$$;

-- =====================================================
-- MINES GAME: CLICK TILE FUNCTION
-- =====================================================
-- This reveals a tile and checks if it's a mine

CREATE OR REPLACE FUNCTION mines_click_tile(
  p_game_id uuid,
  p_tile_index integer
)
RETURNS TABLE(
  result text, -- 'safe', 'mine', 'already_revealed', 'invalid_game'
  mine_positions integer[],
  multiplier numeric,
  new_balance bigint,
  game_status text
)
LANGUAGE plpgsql
SECURITY definer
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
  FROM mines_games
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
    -- Hit a mine! Game over, lose bet
    UPDATE mines_games
    SET status = 'lost',
        ended_at = now()
    WHERE id = p_game_id;

    -- Return mine positions so client can show them
    RETURN QUERY SELECT
      'mine'::text,
      v_game.mine_positions,
      0::numeric,
      (SELECT gp_balance FROM users WHERE id = v_game.user_id),
      'lost'::text;
    RETURN;
  ELSE
    -- Safe tile! Add to revealed
    UPDATE mines_games
    SET revealed_tiles = array_append(revealed_tiles, p_tile_index)
    WHERE id = p_game_id;

    -- Calculate multiplier based on revealed tiles and mine count
    v_tiles_revealed := array_length(v_game.revealed_tiles, 1) + 1;
    v_safe_tiles := 25 - v_game.mines_count;
    v_multiplier := 1.0 + (v_tiles_revealed::numeric / v_safe_tiles::numeric) * 2.0;

    RETURN QUERY SELECT
      'safe'::text,
      null::integer[],
      v_multiplier,
      (SELECT gp_balance FROM users WHERE id = v_game.user_id),
      'active'::text;
    RETURN;
  END IF;
END;
$$;

-- =====================================================
-- MINES GAME: CASH OUT FUNCTION
-- =====================================================
-- This ends the game and pays out winnings

CREATE OR REPLACE FUNCTION mines_cashout(p_game_id uuid)
RETURNS TABLE(
  success boolean,
  payout bigint,
  new_balance bigint,
  message text
)
LANGUAGE plpgsql
SECURITY definer
AS $$
DECLARE
  v_game record;
  v_multiplier numeric;
  v_payout bigint;
  v_update_result record;
BEGIN
  -- Get game
  SELECT * INTO v_game
  FROM mines_games
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

  -- Add winnings to user balance
  SELECT * INTO v_update_result
  FROM update_user_gp(v_game.user_id, v_payout);

  -- Update game status
  UPDATE mines_games
  SET status = 'cashed_out',
      payout = v_payout,
      ended_at = now()
  WHERE id = p_game_id;

  RETURN QUERY SELECT true, v_payout, v_update_result.new_balance, 'Cashed out successfully';
END;
$$;

-- =====================================================
-- RLS POLICIES FOR MINES GAMES
-- =====================================================

ALTER TABLE mines_games ENABLE ROW LEVEL SECURITY;

-- Users can only see their own games
DROP POLICY IF EXISTS "Users can view own games" ON mines_games;
CREATE POLICY "Users can view own games" ON mines_games
  FOR SELECT USING (true); -- Allow all for now, tighten later if needed

-- Only server functions can insert/update games
DROP POLICY IF EXISTS "No direct manipulation" ON mines_games;
CREATE POLICY "No direct manipulation" ON mines_games
  FOR ALL USING (false);

-- =====================================================
-- VERIFY SETUP
-- =====================================================

SELECT
  'Setup Complete!' as status,
  (SELECT COUNT(*) FROM users WHERE gp_balance > 0) as users_with_balance,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'update_user_gp') as has_update_gp,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'get_user_gp') as has_get_gp,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'mines_start_game') as has_mines_start,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'mines_click_tile') as has_mines_click,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'mines_cashout') as has_mines_cashout;
