-- ============================================
-- GAMES SYSTEM MIGRATION (Mines, Blackjack, Crash)
-- ============================================
-- This migration adds server-authoritative games to prevent cheating
-- All game logic runs server-side with secure validation
-- ============================================

-- ============================================
-- BACKWARD COMPATIBILITY: secure_update_gp alias
-- ============================================
-- Frontend currently calls secure_update_gp but DB has secure_update_gc
-- Create alias for backward compatibility

CREATE OR REPLACE FUNCTION secure_update_gp(
  p_amount BIGINT,
  p_transaction_type VARCHAR DEFAULT 'game',
  p_game_type VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_result JSON;
BEGIN
  -- Get authenticated user from JWT
  v_user_id := (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1);

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Not authenticated');
  END IF;

  -- Call the real secure_update_gc function
  v_result := secure_update_gc(
    v_user_id,
    p_amount,
    p_transaction_type,
    p_game_type::VARCHAR,
    NULL
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION secure_update_gp TO authenticated, anon;

-- ============================================
-- STEP 1: MINES GAME TABLES
-- ============================================

CREATE TABLE IF NOT EXISTS mines_games (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  bet_amount BIGINT NOT NULL CHECK (bet_amount >= 10 AND bet_amount <= 10000),
  mines_count INTEGER NOT NULL CHECK (mines_count >= 1 AND mines_count <= 24),
  mine_positions INTEGER[] NOT NULL, -- Hidden from client until game ends
  revealed_tiles INTEGER[] DEFAULT '{}',
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'won', 'lost', 'cashed_out')),
  payout BIGINT DEFAULT 0,
  multiplier NUMERIC(10,2) DEFAULT 1.00,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ
);

CREATE INDEX idx_mines_games_user_id ON mines_games(user_id);
CREATE INDEX idx_mines_games_status ON mines_games(status);
CREATE INDEX idx_mines_games_created_at ON mines_games(created_at DESC);

-- Enable RLS
ALTER TABLE mines_games ENABLE ROW LEVEL SECURITY;

-- Users can view their own games only
CREATE POLICY "Users view own mines games" ON mines_games
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

-- No direct inserts/updates (functions only)
CREATE POLICY "No direct mines manipulation" ON mines_games
  FOR ALL USING (false);

-- ============================================
-- STEP 2: MINES GAME FUNCTIONS
-- ============================================

-- Start a new mines game
CREATE OR REPLACE FUNCTION mines_start_game(
  p_bet_amount BIGINT,
  p_mines_count INTEGER
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_game_id UUID;
  v_mine_positions INTEGER[];
  v_update_result JSON;
  v_random_pos INTEGER;
  i INTEGER;
BEGIN
  -- Get authenticated user
  v_user_id := (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1);

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Not authenticated');
  END IF;

  -- Validate inputs
  IF p_bet_amount < 10 OR p_bet_amount > 10000 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Bet must be between 10 and 10,000 GC');
  END IF;

  IF p_mines_count < 1 OR p_mines_count > 24 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Mines must be between 1 and 24');
  END IF;

  -- Deduct bet amount
  v_update_result := secure_update_gc(
    v_user_id,
    -p_bet_amount,
    'game_loss',
    'mines',
    'Mines bet placed'
  );

  IF NOT (v_update_result->>'success')::boolean THEN
    RETURN v_update_result;
  END IF;

  -- Generate random mine positions (server-side, hidden from client)
  v_mine_positions := ARRAY[]::INTEGER[];
  FOR i IN 1..p_mines_count LOOP
    LOOP
      v_random_pos := floor(random() * 25)::INTEGER;
      IF NOT (v_random_pos = ANY(v_mine_positions)) THEN
        v_mine_positions := array_append(v_mine_positions, v_random_pos);
        EXIT;
      END IF;
    END LOOP;
  END LOOP;

  -- Create game record
  INSERT INTO mines_games (user_id, bet_amount, mines_count, mine_positions, status)
  VALUES (v_user_id, p_bet_amount, p_mines_count, v_mine_positions, 'active')
  RETURNING id INTO v_game_id;

  RETURN json_build_object(
    'success', TRUE,
    'game_id', v_game_id,
    'new_balance', (v_update_result->>'new_balance')::BIGINT
  );
END;
$$;

GRANT EXECUTE ON FUNCTION mines_start_game TO authenticated, anon;

-- Click a tile in mines game
CREATE OR REPLACE FUNCTION mines_click_tile(
  p_game_id UUID,
  p_tile_index INTEGER
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_game RECORD;
  v_is_mine BOOLEAN;
  v_multiplier NUMERIC;
  v_revealed_count INTEGER;
  v_safe_tiles INTEGER;
  v_growth_rate NUMERIC;
BEGIN
  -- Get authenticated user
  v_user_id := (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1);

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Not authenticated');
  END IF;

  -- Get game and lock it
  SELECT * INTO v_game
  FROM mines_games
  WHERE id = p_game_id AND user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Game not found');
  END IF;

  IF v_game.status != 'active' THEN
    RETURN json_build_object('success', FALSE, 'error', 'Game already ended');
  END IF;

  -- Check if tile already revealed
  IF p_tile_index = ANY(v_game.revealed_tiles) THEN
    RETURN json_build_object('success', FALSE, 'error', 'Tile already revealed');
  END IF;

  -- Check if it's a mine
  v_is_mine := p_tile_index = ANY(v_game.mine_positions);

  IF v_is_mine THEN
    -- Hit a mine! Game over, reveal all mines
    UPDATE mines_games
    SET status = 'lost',
        ended_at = NOW()
    WHERE id = p_game_id;

    RETURN json_build_object(
      'success', TRUE,
      'result', 'mine',
      'mine_positions', v_game.mine_positions,
      'game_over', TRUE
    );
  ELSE
    -- Safe tile! Update revealed tiles
    UPDATE mines_games
    SET revealed_tiles = array_append(revealed_tiles, p_tile_index)
    WHERE id = p_game_id;

    v_revealed_count := array_length(v_game.revealed_tiles, 1) + 1;
    v_safe_tiles := 25 - v_game.mines_count;

    -- Calculate multiplier (matches frontend formula)
    v_growth_rate := 1.0 + (v_game.mines_count::NUMERIC / 25.0);
    v_multiplier := 1.0 + (v_revealed_count::NUMERIC * 0.2 * v_growth_rate);

    -- Update multiplier in game
    UPDATE mines_games
    SET multiplier = v_multiplier
    WHERE id = p_game_id;

    -- Check if all safe tiles revealed (perfect game)
    IF v_revealed_count >= v_safe_tiles THEN
      -- Auto cashout with perfect multiplier
      RETURN mines_cashout(p_game_id);
    END IF;

    RETURN json_build_object(
      'success', TRUE,
      'result', 'safe',
      'revealed_count', v_revealed_count,
      'multiplier', v_multiplier,
      'game_over', FALSE
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION mines_click_tile TO authenticated, anon;

-- Cash out from mines game
CREATE OR REPLACE FUNCTION mines_cashout(p_game_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_game RECORD;
  v_payout BIGINT;
  v_update_result JSON;
BEGIN
  -- Get authenticated user
  v_user_id := (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1);

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Not authenticated');
  END IF;

  -- Get game and lock it
  SELECT * INTO v_game
  FROM mines_games
  WHERE id = p_game_id AND user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Game not found');
  END IF;

  IF v_game.status != 'active' THEN
    RETURN json_build_object('success', FALSE, 'error', 'Game already ended');
  END IF;

  -- Must have revealed at least one tile
  IF array_length(v_game.revealed_tiles, 1) IS NULL OR array_length(v_game.revealed_tiles, 1) = 0 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Must reveal at least one tile');
  END IF;

  -- Calculate payout
  v_payout := floor(v_game.bet_amount * v_game.multiplier)::BIGINT;

  -- Add winnings
  v_update_result := secure_update_gc(
    v_user_id,
    v_payout,
    'game_win',
    'mines',
    'Mines cashout at ' || v_game.multiplier::TEXT || 'x'
  );

  -- Update game status
  UPDATE mines_games
  SET status = 'cashed_out',
      payout = v_payout,
      ended_at = NOW()
  WHERE id = p_game_id;

  RETURN json_build_object(
    'success', TRUE,
    'result', 'cashout',
    'payout', v_payout,
    'multiplier', v_game.multiplier,
    'mine_positions', v_game.mine_positions,
    'new_balance', (v_update_result->>'new_balance')::BIGINT,
    'game_over', TRUE
  );
END;
$$;

GRANT EXECUTE ON FUNCTION mines_cashout TO authenticated, anon;

-- ============================================
-- STEP 3: BLACKJACK GAME TABLES
-- ============================================

CREATE TABLE IF NOT EXISTS blackjack_games (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  bet_amount BIGINT NOT NULL CHECK (bet_amount >= 10 AND bet_amount <= 10000),
  deck JSONB NOT NULL, -- Remaining cards in deck
  player_hand JSONB DEFAULT '[]',
  dealer_hand JSONB DEFAULT '[]',
  dealer_hidden_card JSONB, -- Hidden until stand
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'player_win', 'dealer_win', 'push', 'blackjack', 'player_bust', 'dealer_bust')),
  payout BIGINT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ
);

CREATE INDEX idx_blackjack_games_user_id ON blackjack_games(user_id);
CREATE INDEX idx_blackjack_games_status ON blackjack_games(status);
CREATE INDEX idx_blackjack_games_created_at ON blackjack_games(created_at DESC);

-- Enable RLS
ALTER TABLE blackjack_games ENABLE ROW LEVEL SECURITY;

-- Users can view their own games
CREATE POLICY "Users view own blackjack games" ON blackjack_games
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

-- No direct manipulation
CREATE POLICY "No direct blackjack manipulation" ON blackjack_games
  FOR ALL USING (false);

-- ============================================
-- STEP 4: BLACKJACK GAME FUNCTIONS
-- ============================================

-- Helper: Create and shuffle deck
CREATE OR REPLACE FUNCTION create_blackjack_deck()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_deck JSONB := '[]';
  v_suits TEXT[] := ARRAY['♠', '♥', '♦', '♣'];
  v_ranks TEXT[] := ARRAY['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
  v_suit TEXT;
  v_rank TEXT;
  v_shuffled JSONB := '[]';
  v_card JSONB;
  v_random_index INTEGER;
  v_temp_deck JSONB;
BEGIN
  -- Create deck
  FOREACH v_suit IN ARRAY v_suits LOOP
    FOREACH v_rank IN ARRAY v_ranks LOOP
      v_deck := v_deck || jsonb_build_object('rank', v_rank, 'suit', v_suit);
    END LOOP;
  END LOOP;

  -- Fisher-Yates shuffle
  v_temp_deck := v_deck;
  FOR i IN 0..51 LOOP
    v_random_index := floor(random() * (52 - i))::INTEGER;
    v_shuffled := v_shuffled || (v_temp_deck->v_random_index);
    v_temp_deck := (
      SELECT jsonb_agg(elem)
      FROM jsonb_array_elements(v_temp_deck) WITH ORDINALITY AS t(elem, idx)
      WHERE idx - 1 != v_random_index
    );
  END LOOP;

  RETURN v_shuffled;
END;
$$;

-- Helper: Calculate hand value
CREATE OR REPLACE FUNCTION calculate_blackjack_hand_value(p_hand JSONB)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_value INTEGER := 0;
  v_aces INTEGER := 0;
  v_card JSONB;
  v_rank TEXT;
BEGIN
  FOR v_card IN SELECT * FROM jsonb_array_elements(p_hand) LOOP
    v_rank := v_card->>'rank';

    IF v_rank IN ('J', 'Q', 'K') THEN
      v_value := v_value + 10;
    ELSIF v_rank = 'A' THEN
      v_value := v_value + 11;
      v_aces := v_aces + 1;
    ELSE
      v_value := v_value + v_rank::INTEGER;
    END IF;
  END LOOP;

  -- Adjust for aces
  WHILE v_value > 21 AND v_aces > 0 LOOP
    v_value := v_value - 10;
    v_aces := v_aces - 1;
  END LOOP;

  RETURN v_value;
END;
$$;

-- Start blackjack game
CREATE OR REPLACE FUNCTION blackjack_deal(p_bet_amount BIGINT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_game_id UUID;
  v_deck JSONB;
  v_player_hand JSONB := '[]';
  v_dealer_hand JSONB := '[]';
  v_dealer_hidden JSONB;
  v_update_result JSON;
  v_player_value INTEGER;
  v_dealer_value INTEGER;
BEGIN
  -- Get authenticated user
  v_user_id := (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1);

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Not authenticated');
  END IF;

  -- Validate bet
  IF p_bet_amount < 10 OR p_bet_amount > 10000 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Bet must be between 10 and 10,000 GC');
  END IF;

  -- Deduct bet
  v_update_result := secure_update_gc(
    v_user_id,
    -p_bet_amount,
    'game_loss',
    'blackjack',
    'Blackjack bet placed'
  );

  IF NOT (v_update_result->>'success')::boolean THEN
    RETURN v_update_result;
  END IF;

  -- Create and shuffle deck
  v_deck := create_blackjack_deck();

  -- Deal initial cards: Player, Dealer, Player, Dealer(hidden)
  v_player_hand := v_player_hand || (v_deck->0);
  v_dealer_hand := v_dealer_hand || (v_deck->1);
  v_player_hand := v_player_hand || (v_deck->2);
  v_dealer_hidden := v_deck->3;

  -- Remove dealt cards from deck
  v_deck := (
    SELECT jsonb_agg(elem)
    FROM jsonb_array_elements(v_deck) WITH ORDINALITY AS t(elem, idx)
    WHERE idx > 4
  );

  -- Create game
  INSERT INTO blackjack_games (
    user_id, bet_amount, deck, player_hand, dealer_hand, dealer_hidden_card, status
  ) VALUES (
    v_user_id, p_bet_amount, v_deck, v_player_hand, v_dealer_hand, v_dealer_hidden, 'active'
  ) RETURNING id INTO v_game_id;

  -- Check for natural blackjack
  v_player_value := calculate_blackjack_hand_value(v_player_hand);
  v_dealer_value := calculate_blackjack_hand_value(v_dealer_hand || v_dealer_hidden);

  IF v_player_value = 21 AND jsonb_array_length(v_player_hand) = 2 THEN
    IF v_dealer_value = 21 THEN
      -- Push
      RETURN blackjack_end_game(v_game_id, 'push');
    ELSE
      -- Player blackjack wins 3:2
      RETURN blackjack_end_game(v_game_id, 'blackjack');
    END IF;
  END IF;

  RETURN json_build_object(
    'success', TRUE,
    'game_id', v_game_id,
    'player_hand', v_player_hand,
    'dealer_hand', v_dealer_hand,
    'player_value', v_player_value,
    'dealer_value', calculate_blackjack_hand_value(v_dealer_hand),
    'new_balance', (v_update_result->>'new_balance')::BIGINT
  );
END;
$$;

GRANT EXECUTE ON FUNCTION blackjack_deal TO authenticated, anon;

-- Hit (draw card)
CREATE OR REPLACE FUNCTION blackjack_hit(p_game_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_game RECORD;
  v_new_card JSONB;
  v_player_value INTEGER;
BEGIN
  v_user_id := (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1);

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_game
  FROM blackjack_games
  WHERE id = p_game_id AND user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND OR v_game.status != 'active' THEN
    RETURN json_build_object('success', FALSE, 'error', 'Invalid game');
  END IF;

  -- Draw card from deck
  v_new_card := v_game.deck->0;

  -- Update game
  UPDATE blackjack_games
  SET player_hand = player_hand || v_new_card,
      deck = (
        SELECT jsonb_agg(elem)
        FROM jsonb_array_elements(deck) WITH ORDINALITY AS t(elem, idx)
        WHERE idx > 1
      )
  WHERE id = p_game_id;

  v_player_value := calculate_blackjack_hand_value(v_game.player_hand || v_new_card);

  -- Check for bust
  IF v_player_value > 21 THEN
    RETURN blackjack_end_game(p_game_id, 'player_bust');
  END IF;

  RETURN json_build_object(
    'success', TRUE,
    'new_card', v_new_card,
    'player_hand', v_game.player_hand || v_new_card,
    'player_value', v_player_value
  );
END;
$$;

GRANT EXECUTE ON FUNCTION blackjack_hit TO authenticated, anon;

-- Stand (dealer plays)
CREATE OR REPLACE FUNCTION blackjack_stand(p_game_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_game RECORD;
  v_dealer_hand JSONB;
  v_deck JSONB;
  v_player_value INTEGER;
  v_dealer_value INTEGER;
  v_new_card JSONB;
  v_result VARCHAR;
BEGIN
  v_user_id := (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1);

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_game
  FROM blackjack_games
  WHERE id = p_game_id AND user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND OR v_game.status != 'active' THEN
    RETURN json_build_object('success', FALSE, 'error', 'Invalid game');
  END IF;

  -- Reveal dealer's hidden card
  v_dealer_hand := v_game.dealer_hand || v_game.dealer_hidden_card;
  v_deck := v_game.deck;
  v_player_value := calculate_blackjack_hand_value(v_game.player_hand);

  -- Dealer hits until 17 or higher
  v_dealer_value := calculate_blackjack_hand_value(v_dealer_hand);
  WHILE v_dealer_value < 17 AND jsonb_array_length(v_deck) > 0 LOOP
    v_new_card := v_deck->0;
    v_dealer_hand := v_dealer_hand || v_new_card;
    v_deck := (
      SELECT jsonb_agg(elem)
      FROM jsonb_array_elements(v_deck) WITH ORDINALITY AS t(elem, idx)
      WHERE idx > 1
    );
    v_dealer_value := calculate_blackjack_hand_value(v_dealer_hand);
  END LOOP;

  -- Determine winner
  IF v_dealer_value > 21 THEN
    v_result := 'dealer_bust';
  ELSIF v_player_value > v_dealer_value THEN
    v_result := 'player_win';
  ELSIF v_player_value < v_dealer_value THEN
    v_result := 'dealer_win';
  ELSE
    v_result := 'push';
  END IF;

  -- Update dealer hand in game
  UPDATE blackjack_games
  SET dealer_hand = v_dealer_hand,
      dealer_hidden_card = NULL,
      deck = v_deck
  WHERE id = p_game_id;

  RETURN blackjack_end_game(p_game_id, v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION blackjack_stand TO authenticated, anon;

-- End game and calculate payout
CREATE OR REPLACE FUNCTION blackjack_end_game(
  p_game_id UUID,
  p_result VARCHAR
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_game RECORD;
  v_payout BIGINT := 0;
  v_update_result JSON;
  v_player_value INTEGER;
  v_dealer_value INTEGER;
BEGIN
  v_user_id := (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1);

  SELECT * INTO v_game FROM blackjack_games WHERE id = p_game_id FOR UPDATE;

  -- Calculate payout
  CASE p_result
    WHEN 'blackjack' THEN
      v_payout := floor(v_game.bet_amount * 2.5)::BIGINT; -- 3:2 payout + original bet
    WHEN 'player_win', 'dealer_bust' THEN
      v_payout := v_game.bet_amount * 2; -- 1:1 payout + original bet
    WHEN 'push' THEN
      v_payout := v_game.bet_amount; -- Return bet
    ELSE
      v_payout := 0; -- Player lost
  END CASE;

  -- Add winnings if any
  IF v_payout > 0 THEN
    v_update_result := secure_update_gc(
      v_user_id,
      v_payout,
      'game_win',
      'blackjack',
      'Blackjack ' || p_result
    );
  END IF;

  -- Update game
  UPDATE blackjack_games
  SET status = p_result,
      payout = v_payout,
      ended_at = NOW()
  WHERE id = p_game_id;

  v_player_value := calculate_blackjack_hand_value(v_game.player_hand);
  v_dealer_value := calculate_blackjack_hand_value(
    CASE
      WHEN v_game.dealer_hidden_card IS NOT NULL THEN v_game.dealer_hand || v_game.dealer_hidden_card
      ELSE v_game.dealer_hand
    END
  );

  RETURN json_build_object(
    'success', TRUE,
    'result', p_result,
    'payout', v_payout,
    'player_value', v_player_value,
    'dealer_value', v_dealer_value,
    'player_hand', v_game.player_hand,
    'dealer_hand', CASE
      WHEN v_game.dealer_hidden_card IS NOT NULL THEN v_game.dealer_hand || v_game.dealer_hidden_card
      ELSE v_game.dealer_hand
    END,
    'new_balance', CASE WHEN v_payout > 0 THEN (v_update_result->>'new_balance')::BIGINT ELSE NULL END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION blackjack_end_game TO authenticated, anon;

-- ============================================
-- STEP 5: CRASH GAME TABLES
-- ============================================

CREATE TABLE IF NOT EXISTS crash_games (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  bet_amount BIGINT NOT NULL CHECK (bet_amount >= 10 AND bet_amount <= 10000),
  crash_point NUMERIC(10,2) NOT NULL, -- When the game crashed
  cashout_multiplier NUMERIC(10,2), -- NULL if didn't cash out
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'cashed_out', 'crashed')),
  payout BIGINT DEFAULT 0,
  seed VARCHAR(64), -- For provably fair
  created_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ
);

CREATE INDEX idx_crash_games_user_id ON crash_games(user_id);
CREATE INDEX idx_crash_games_status ON crash_games(status);
CREATE INDEX idx_crash_games_created_at ON crash_games(created_at DESC);

-- Enable RLS
ALTER TABLE crash_games ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users view own crash games" ON crash_games
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

CREATE POLICY "No direct crash manipulation" ON crash_games
  FOR ALL USING (false);

-- ============================================
-- STEP 6: CRASH GAME FUNCTIONS
-- ============================================

-- Generate provably fair crash point
CREATE OR REPLACE FUNCTION generate_crash_point()
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
  v_random NUMERIC;
  v_crash NUMERIC;
BEGIN
  -- Use exponential distribution for crash point
  v_random := random();

  -- Prevent crash at exactly 1.00
  IF v_random < 0.01 THEN
    v_random := 0.01;
  END IF;

  -- Formula: -ln(random) / ln(0.99) gives exponential distribution
  -- Average crash point ~= 2.0x
  v_crash := 0.99 / (1.0 - v_random);

  -- Clamp between 1.00 and 100.00
  v_crash := GREATEST(1.00, LEAST(100.00, v_crash));

  RETURN ROUND(v_crash, 2);
END;
$$;

-- Start crash game (place bet)
CREATE OR REPLACE FUNCTION crash_start_game(
  p_bet_amount BIGINT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_game_id UUID;
  v_crash_point NUMERIC;
  v_update_result JSON;
  v_seed VARCHAR(64);
BEGIN
  v_user_id := (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1);

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Not authenticated');
  END IF;

  IF p_bet_amount < 10 OR p_bet_amount > 10000 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Bet must be between 10 and 10,000 GC');
  END IF;

  -- Deduct bet
  v_update_result := secure_update_gc(
    v_user_id,
    -p_bet_amount,
    'game_loss',
    'crash',
    'Crash bet placed'
  );

  IF NOT (v_update_result->>'success')::boolean THEN
    RETURN v_update_result;
  END IF;

  -- Generate crash point
  v_crash_point := generate_crash_point();
  v_seed := md5(random()::TEXT || clock_timestamp()::TEXT);

  -- Create game
  INSERT INTO crash_games (user_id, bet_amount, crash_point, seed, status)
  VALUES (v_user_id, p_bet_amount, v_crash_point, v_seed, 'active')
  RETURNING id INTO v_game_id;

  RETURN json_build_object(
    'success', TRUE,
    'game_id', v_game_id,
    'crash_point', v_crash_point,
    'seed', v_seed,
    'new_balance', (v_update_result->>'new_balance')::BIGINT
  );
END;
$$;

GRANT EXECUTE ON FUNCTION crash_start_game TO authenticated, anon;

-- Cash out from crash game
CREATE OR REPLACE FUNCTION crash_cashout(
  p_game_id UUID,
  p_multiplier NUMERIC
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_game RECORD;
  v_payout BIGINT;
  v_update_result JSON;
BEGIN
  v_user_id := (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1);

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_game
  FROM crash_games
  WHERE id = p_game_id AND user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Game not found');
  END IF;

  IF v_game.status != 'active' THEN
    RETURN json_build_object('success', FALSE, 'error', 'Game already ended');
  END IF;

  -- Validate multiplier (must be less than crash point)
  IF p_multiplier > v_game.crash_point THEN
    -- Too late, already crashed
    UPDATE crash_games
    SET status = 'crashed',
        ended_at = NOW()
    WHERE id = p_game_id;

    RETURN json_build_object(
      'success', FALSE,
      'error', 'Too late! Game crashed at ' || v_game.crash_point::TEXT || 'x'
    );
  END IF;

  -- Calculate payout
  v_payout := floor(v_game.bet_amount * p_multiplier)::BIGINT;

  -- Add winnings
  v_update_result := secure_update_gc(
    v_user_id,
    v_payout,
    'game_win',
    'crash',
    'Crash cashout at ' || p_multiplier::TEXT || 'x'
  );

  -- Update game
  UPDATE crash_games
  SET status = 'cashed_out',
      cashout_multiplier = p_multiplier,
      payout = v_payout,
      ended_at = NOW()
  WHERE id = p_game_id;

  RETURN json_build_object(
    'success', TRUE,
    'payout', v_payout,
    'multiplier', p_multiplier,
    'crash_point', v_game.crash_point,
    'new_balance', (v_update_result->>'new_balance')::BIGINT
  );
END;
$$;

GRANT EXECUTE ON FUNCTION crash_cashout TO authenticated, anon;

-- ============================================
-- VERIFICATION
-- ============================================

DO $$
BEGIN
  RAISE NOTICE '✅ Games system migration complete!';
  RAISE NOTICE 'Tables created: mines_games, blackjack_games, crash_games';
  RAISE NOTICE 'Functions created: mines_start_game, mines_click_tile, mines_cashout';
  RAISE NOTICE 'Functions created: blackjack_deal, blackjack_hit, blackjack_stand';
  RAISE NOTICE 'Functions created: crash_start_game, crash_cashout';
  RAISE NOTICE 'Backward compatibility: secure_update_gp alias added';
END $$;
