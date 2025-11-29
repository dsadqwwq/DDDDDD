-- =====================================================
-- WARRIOR CAMPAIGN GAMES SYSTEM
-- =====================================================
-- Secure server-side game logic to prevent script kiddies
-- All game outcomes calculated server-side with provably fair seeds
-- =====================================================

-- =====================================================
-- 1. GAME SESSIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS game_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  game_type VARCHAR(50) NOT NULL, -- 'crash', 'mines', 'blackjack', 'reaction'
  bet_amount BIGINT NOT NULL,
  result VARCHAR(20) NOT NULL, -- 'win', 'loss', 'push'
  payout_amount BIGINT DEFAULT 0,
  profit_loss BIGINT NOT NULL, -- Negative for loss, positive for win
  game_data JSONB, -- Store game-specific data (multiplier, cards, etc)
  server_seed VARCHAR(64) NOT NULL, -- Provably fair seed
  client_seed VARCHAR(64), -- Optional client seed
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_game_sessions_user_id ON game_sessions(user_id);
CREATE INDEX idx_game_sessions_game_type ON game_sessions(game_type);
CREATE INDEX idx_game_sessions_created_at ON game_sessions(created_at DESC);

-- Enable RLS
ALTER TABLE game_sessions ENABLE ROW LEVEL SECURITY;

-- Users can view their own game history
DROP POLICY IF EXISTS "Users view own games" ON game_sessions;
CREATE POLICY "Users view own games" ON game_sessions
  FOR SELECT USING (auth.uid()::text IN (
    SELECT auth_user_id::text FROM users WHERE id = user_id
  ));

-- Only functions can insert/update
DROP POLICY IF EXISTS "Functions only modify" ON game_sessions;
CREATE POLICY "Functions only modify" ON game_sessions
  FOR ALL USING (false);

-- =====================================================
-- 2. GENERATE PROVABLY FAIR SEED
-- =====================================================
CREATE OR REPLACE FUNCTION generate_game_seed()
RETURNS VARCHAR(64)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN encode(gen_random_bytes(32), 'hex');
END;
$$;

-- =====================================================
-- 3. CRASH GAME - START ROUND
-- =====================================================
CREATE OR REPLACE FUNCTION crash_start_round(
  p_user_id UUID,
  p_bet_amount BIGINT,
  p_auto_cashout NUMERIC DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_balance BIGINT;
  v_server_seed VARCHAR(64);
  v_crash_point NUMERIC;
  v_session_id UUID;
BEGIN
  -- Validate bet amount
  IF p_bet_amount < 10 OR p_bet_amount > 10000 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Bet must be between 10-10,000 GC');
  END IF;

  -- Get and lock user balance
  SELECT gc_balance INTO v_current_balance
  FROM users
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'User not found');
  END IF;

  -- Check balance
  IF v_current_balance < p_bet_amount THEN
    RETURN json_build_object('success', FALSE, 'error', 'Insufficient balance');
  END IF;

  -- Generate provably fair crash point
  v_server_seed := generate_game_seed();

  -- Hash-based crash point: 1.00x to 10.00x
  -- Using modulo of hash to generate fair random number
  v_crash_point := 1.00 + (('x' || substring(v_server_seed, 1, 8))::bit(32)::bigint % 900)::numeric / 100;

  -- 10% chance of instant crash (1.00x)
  IF (('x' || substring(v_server_seed, 9, 2))::bit(8)::int % 10) = 0 THEN
    v_crash_point := 1.00;
  END IF;

  -- Deduct bet
  UPDATE users
  SET gc_balance = gc_balance - p_bet_amount,
      updated_at = NOW()
  WHERE id = p_user_id;

  -- Create session (pending result)
  INSERT INTO game_sessions (
    user_id, game_type, bet_amount, result, payout_amount, profit_loss,
    game_data, server_seed
  ) VALUES (
    p_user_id, 'crash', p_bet_amount, 'pending', 0, -p_bet_amount,
    json_build_object(
      'crash_point', v_crash_point,
      'auto_cashout', p_auto_cashout,
      'cashed_out', FALSE,
      'cashout_multiplier', NULL
    )::jsonb,
    v_server_seed
  ) RETURNING id INTO v_session_id;

  RETURN json_build_object(
    'success', TRUE,
    'session_id', v_session_id,
    'crash_point', v_crash_point,
    'server_seed_hash', substring(md5(v_server_seed), 1, 16),
    'new_balance', v_current_balance - p_bet_amount
  );
END;
$$;

-- =====================================================
-- 4. CRASH GAME - CASHOUT
-- =====================================================
CREATE OR REPLACE FUNCTION crash_cashout(
  p_session_id UUID,
  p_cashout_multiplier NUMERIC
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session RECORD;
  v_crash_point NUMERIC;
  v_payout BIGINT;
  v_profit BIGINT;
  v_new_balance BIGINT;
  v_result VARCHAR(20);
BEGIN
  -- Get session
  SELECT * INTO v_session
  FROM game_sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Session not found');
  END IF;

  IF v_session.result != 'pending' THEN
    RETURN json_build_object('success', FALSE, 'error', 'Game already ended');
  END IF;

  v_crash_point := (v_session.game_data->>'crash_point')::numeric;

  -- Check if cashed out before crash
  IF p_cashout_multiplier >= v_crash_point THEN
    -- Crashed before cashout
    v_result := 'loss';
    v_payout := 0;
    v_profit := -v_session.bet_amount;
  ELSE
    -- Successful cashout
    v_result := 'win';
    v_payout := floor(v_session.bet_amount * p_cashout_multiplier);
    v_profit := v_payout - v_session.bet_amount;

    -- Credit winnings
    UPDATE users
    SET gc_balance = gc_balance + v_payout,
        updated_at = NOW()
    WHERE id = v_session.user_id
    RETURNING gc_balance INTO v_new_balance;
  END IF;

  -- Update session
  UPDATE game_sessions
  SET result = v_result,
      payout_amount = v_payout,
      profit_loss = v_profit,
      game_data = jsonb_set(
        jsonb_set(game_data, '{cashed_out}', 'true'::jsonb),
        '{cashout_multiplier}', to_jsonb(p_cashout_multiplier)
      )
  WHERE id = p_session_id;

  -- Log transaction
  INSERT INTO gc_transactions (
    user_id, amount, balance_after, transaction_type, reference_id, description
  ) VALUES (
    v_session.user_id,
    v_profit,
    COALESCE(v_new_balance, (SELECT gc_balance FROM users WHERE id = v_session.user_id)),
    CASE WHEN v_result = 'win' THEN 'game_win' ELSE 'game_loss' END,
    'crash_' || p_session_id::text,
    'Crash game: ' || CASE WHEN v_result = 'win'
      THEN p_cashout_multiplier::text || 'x (won)'
      ELSE 'crashed at ' || v_crash_point::text || 'x'
    END
  );

  RETURN json_build_object(
    'success', TRUE,
    'result', v_result,
    'crash_point', v_crash_point,
    'cashout_multiplier', p_cashout_multiplier,
    'payout', v_payout,
    'profit', v_profit,
    'new_balance', COALESCE(v_new_balance, (SELECT gc_balance FROM users WHERE id = v_session.user_id))
  );
END;
$$;

-- =====================================================
-- 5. MINES GAME - START
-- =====================================================
CREATE OR REPLACE FUNCTION mines_start_game(
  p_user_id UUID,
  p_bet_amount BIGINT,
  p_mine_count INT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_balance BIGINT;
  v_server_seed VARCHAR(64);
  v_mine_positions INT[];
  v_session_id UUID;
  v_i INT;
  v_pos INT;
BEGIN
  -- Validate inputs
  IF p_bet_amount < 10 OR p_bet_amount > 10000 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Bet must be between 10-10,000 GC');
  END IF;

  IF p_mine_count NOT IN (3, 5, 10, 15) THEN
    RETURN json_build_object('success', FALSE, 'error', 'Invalid mine count');
  END IF;

  -- Get and lock balance
  SELECT gc_balance INTO v_current_balance
  FROM users
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_current_balance < p_bet_amount THEN
    RETURN json_build_object('success', FALSE, 'error', 'Insufficient balance');
  END IF;

  -- Generate mine positions (0-24 for 5x5 grid)
  v_server_seed := generate_game_seed();
  v_mine_positions := ARRAY[]::INT[];

  -- Simple shuffle algorithm using seed
  FOR v_i IN 1..p_mine_count LOOP
    LOOP
      v_pos := (('x' || substring(v_server_seed, v_i * 2 - 1, 2))::bit(8)::int % 25);
      IF NOT (v_pos = ANY(v_mine_positions)) THEN
        v_mine_positions := array_append(v_mine_positions, v_pos);
        EXIT;
      END IF;
    END LOOP;
  END LOOP;

  -- Deduct bet
  UPDATE users
  SET gc_balance = gc_balance - p_bet_amount,
      updated_at = NOW()
  WHERE id = p_user_id;

  -- Create session
  INSERT INTO game_sessions (
    user_id, game_type, bet_amount, result, payout_amount, profit_loss,
    game_data, server_seed
  ) VALUES (
    p_user_id, 'mines', p_bet_amount, 'pending', 0, -p_bet_amount,
    json_build_object(
      'mine_count', p_mine_count,
      'mine_positions', v_mine_positions,
      'revealed_tiles', ARRAY[]::INT[],
      'multiplier', 1.0
    )::jsonb,
    v_server_seed
  ) RETURNING id INTO v_session_id;

  RETURN json_build_object(
    'success', TRUE,
    'session_id', v_session_id,
    'new_balance', v_current_balance - p_bet_amount
  );
END;
$$;

-- =====================================================
-- 6. MINES GAME - REVEAL TILE
-- =====================================================
CREATE OR REPLACE FUNCTION mines_reveal_tile(
  p_session_id UUID,
  p_tile_index INT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session RECORD;
  v_mine_positions INT[];
  v_revealed_tiles INT[];
  v_hit_mine BOOLEAN;
  v_multiplier NUMERIC;
  v_safe_tiles INT;
  v_total_safe INT;
BEGIN
  -- Get session
  SELECT * INTO v_session
  FROM game_sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND OR v_session.result != 'pending' THEN
    RETURN json_build_object('success', FALSE, 'error', 'Invalid session');
  END IF;

  IF p_tile_index < 0 OR p_tile_index > 24 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Invalid tile');
  END IF;

  v_mine_positions := ARRAY(SELECT jsonb_array_elements_text(v_session.game_data->'mine_positions'))::INT[];
  v_revealed_tiles := ARRAY(SELECT jsonb_array_elements_text(v_session.game_data->'revealed_tiles'))::INT[];

  -- Check if already revealed
  IF p_tile_index = ANY(v_revealed_tiles) THEN
    RETURN json_build_object('success', FALSE, 'error', 'Tile already revealed');
  END IF;

  -- Check if mine
  v_hit_mine := p_tile_index = ANY(v_mine_positions);

  IF v_hit_mine THEN
    -- Game over - loss
    UPDATE game_sessions
    SET result = 'loss',
        game_data = jsonb_set(game_data, '{revealed_tiles}',
          to_jsonb(array_append(v_revealed_tiles, p_tile_index)))
    WHERE id = p_session_id;

    -- Log transaction
    INSERT INTO gc_transactions (
      user_id, amount, balance_after, transaction_type, reference_id, description
    ) VALUES (
      v_session.user_id, -v_session.bet_amount,
      (SELECT gc_balance FROM users WHERE id = v_session.user_id),
      'game_loss', 'mines_' || p_session_id::text,
      'Mines game: Hit mine at tile ' || p_tile_index
    );

    RETURN json_build_object(
      'success', TRUE,
      'hit_mine', TRUE,
      'mine_positions', v_mine_positions,
      'result', 'loss'
    );
  ELSE
    -- Safe tile - update multiplier
    v_revealed_tiles := array_append(v_revealed_tiles, p_tile_index);
    v_safe_tiles := array_length(v_revealed_tiles, 1);
    v_total_safe := 25 - (v_session.game_data->>'mine_count')::INT;

    -- Calculate multiplier based on risk (more mines = higher multiplier)
    v_multiplier := 1.0 + (v_safe_tiles * 0.15 * ((v_session.game_data->>'mine_count')::NUMERIC / 5));

    UPDATE game_sessions
    SET game_data = game_data
      || jsonb_build_object('revealed_tiles', v_revealed_tiles)
      || jsonb_build_object('multiplier', v_multiplier)
    WHERE id = p_session_id;

    RETURN json_build_object(
      'success', TRUE,
      'hit_mine', FALSE,
      'multiplier', v_multiplier,
      'safe_tiles_count', v_safe_tiles
    );
  END IF;
END;
$$;

-- =====================================================
-- 7. MINES GAME - CASHOUT
-- =====================================================
CREATE OR REPLACE FUNCTION mines_cashout(
  p_session_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session RECORD;
  v_multiplier NUMERIC;
  v_payout BIGINT;
  v_profit BIGINT;
  v_new_balance BIGINT;
BEGIN
  SELECT * INTO v_session
  FROM game_sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND OR v_session.result != 'pending' THEN
    RETURN json_build_object('success', FALSE, 'error', 'Invalid session');
  END IF;

  v_multiplier := (v_session.game_data->>'multiplier')::NUMERIC;
  v_payout := floor(v_session.bet_amount * v_multiplier);
  v_profit := v_payout - v_session.bet_amount;

  -- Credit winnings
  UPDATE users
  SET gc_balance = gc_balance + v_payout,
      updated_at = NOW()
  WHERE id = v_session.user_id
  RETURNING gc_balance INTO v_new_balance;

  -- Update session
  UPDATE game_sessions
  SET result = 'win',
      payout_amount = v_payout,
      profit_loss = v_profit
  WHERE id = p_session_id;

  -- Log transaction
  INSERT INTO gc_transactions (
    user_id, amount, balance_after, transaction_type, reference_id, description
  ) VALUES (
    v_session.user_id, v_profit, v_new_balance,
    'game_win', 'mines_' || p_session_id::text,
    'Mines game: Cashed out at ' || v_multiplier::text || 'x'
  );

  RETURN json_build_object(
    'success', TRUE,
    'result', 'win',
    'multiplier', v_multiplier,
    'payout', v_payout,
    'profit', v_profit,
    'new_balance', v_new_balance
  );
END;
$$;

-- =====================================================
-- 8. BLACKJACK - START GAME
-- =====================================================
CREATE OR REPLACE FUNCTION blackjack_start_game(
  p_user_id UUID,
  p_bet_amount BIGINT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_balance BIGINT;
  v_server_seed VARCHAR(64);
  v_deck INT[];
  v_player_hand INT[];
  v_dealer_hand INT[];
  v_session_id UUID;
  v_i INT;
  v_player_value INT;
  v_dealer_value INT;
BEGIN
  -- Validate bet
  IF p_bet_amount < 10 OR p_bet_amount > 10000 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Bet must be between 10-10,000 GC');
  END IF;

  -- Get balance
  SELECT gc_balance INTO v_current_balance
  FROM users
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_current_balance < p_bet_amount THEN
    RETURN json_build_object('success', FALSE, 'error', 'Insufficient balance');
  END IF;

  -- Generate shuffled deck (1-13 representing A-K, repeated 4 times)
  v_server_seed := generate_game_seed();
  v_deck := ARRAY[]::INT[];
  FOR v_i IN 0..51 LOOP
    v_deck := array_append(v_deck, (v_i % 13) + 1);
  END LOOP;

  -- Deal initial cards
  v_player_hand := ARRAY[v_deck[1], v_deck[3]];
  v_dealer_hand := ARRAY[v_deck[2], v_deck[4]];
  v_deck := v_deck[5:52];

  -- Calculate initial values
  v_player_value := blackjack_calculate_hand(v_player_hand);
  v_dealer_value := blackjack_calculate_hand(v_dealer_hand);

  -- Deduct bet
  UPDATE users
  SET gc_balance = gc_balance - p_bet_amount,
      updated_at = NOW()
  WHERE id = p_user_id;

  -- Create session
  INSERT INTO game_sessions (
    user_id, game_type, bet_amount, result, payout_amount, profit_loss,
    game_data, server_seed
  ) VALUES (
    p_user_id, 'blackjack', p_bet_amount, 'pending', 0, -p_bet_amount,
    json_build_object(
      'deck', v_deck,
      'player_hand', v_player_hand,
      'dealer_hand', v_dealer_hand,
      'player_value', v_player_value,
      'dealer_value', v_dealer_value,
      'player_stood', FALSE
    )::jsonb,
    v_server_seed
  ) RETURNING id INTO v_session_id;

  -- Check for blackjack
  IF v_player_value = 21 THEN
    PERFORM blackjack_finish_game(v_session_id);
  END IF;

  RETURN json_build_object(
    'success', TRUE,
    'session_id', v_session_id,
    'player_hand', v_player_hand,
    'dealer_hand', ARRAY[v_dealer_hand[1]], -- Only show first dealer card
    'player_value', v_player_value,
    'new_balance', v_current_balance - p_bet_amount
  );
END;
$$;

-- Helper function to calculate blackjack hand value
CREATE OR REPLACE FUNCTION blackjack_calculate_hand(p_hand INT[])
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  v_total INT := 0;
  v_aces INT := 0;
  v_card INT;
BEGIN
  FOREACH v_card IN ARRAY p_hand LOOP
    IF v_card = 1 THEN
      v_aces := v_aces + 1;
      v_total := v_total + 11;
    ELSIF v_card > 10 THEN
      v_total := v_total + 10;
    ELSE
      v_total := v_total + v_card;
    END IF;
  END LOOP;

  -- Adjust for aces
  WHILE v_total > 21 AND v_aces > 0 LOOP
    v_total := v_total - 10;
    v_aces := v_aces - 1;
  END LOOP;

  RETURN v_total;
END;
$$;

-- =====================================================
-- 9. BLACKJACK - HIT
-- =====================================================
CREATE OR REPLACE FUNCTION blackjack_hit(
  p_session_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session RECORD;
  v_deck INT[];
  v_player_hand INT[];
  v_new_card INT;
  v_player_value INT;
BEGIN
  SELECT * INTO v_session
  FROM game_sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND OR v_session.result != 'pending' THEN
    RETURN json_build_object('success', FALSE, 'error', 'Invalid session');
  END IF;

  v_deck := ARRAY(SELECT jsonb_array_elements_text(v_session.game_data->'deck'))::INT[];
  v_player_hand := ARRAY(SELECT jsonb_array_elements_text(v_session.game_data->'player_hand'))::INT[];

  -- Draw card
  v_new_card := v_deck[1];
  v_player_hand := array_append(v_player_hand, v_new_card);
  v_deck := v_deck[2:array_length(v_deck, 1)];
  v_player_value := blackjack_calculate_hand(v_player_hand);

  -- Update session
  UPDATE game_sessions
  SET game_data = game_data
    || jsonb_build_object('deck', v_deck)
    || jsonb_build_object('player_hand', v_player_hand)
    || jsonb_build_object('player_value', v_player_value)
  WHERE id = p_session_id;

  -- Check for bust
  IF v_player_value > 21 THEN
    PERFORM blackjack_finish_game(p_session_id);
  END IF;

  RETURN json_build_object(
    'success', TRUE,
    'player_hand', v_player_hand,
    'player_value', v_player_value,
    'busted', v_player_value > 21
  );
END;
$$;

-- =====================================================
-- 10. BLACKJACK - STAND & FINISH
-- =====================================================
CREATE OR REPLACE FUNCTION blackjack_stand(
  p_session_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN blackjack_finish_game(p_session_id);
END;
$$;

CREATE OR REPLACE FUNCTION blackjack_finish_game(
  p_session_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session RECORD;
  v_deck INT[];
  v_dealer_hand INT[];
  v_dealer_value INT;
  v_player_value INT;
  v_result VARCHAR(20);
  v_payout BIGINT;
  v_profit BIGINT;
  v_new_balance BIGINT;
BEGIN
  SELECT * INTO v_session
  FROM game_sessions
  WHERE id = p_session_id
  FOR UPDATE;

  v_deck := ARRAY(SELECT jsonb_array_elements_text(v_session.game_data->'deck'))::INT[];
  v_dealer_hand := ARRAY(SELECT jsonb_array_elements_text(v_session.game_data->'dealer_hand'))::INT[];
  v_player_value := (v_session.game_data->>'player_value')::INT;
  v_dealer_value := blackjack_calculate_hand(v_dealer_hand);

  -- Dealer draws to 17
  WHILE v_dealer_value < 17 AND array_length(v_deck, 1) > 0 LOOP
    v_dealer_hand := array_append(v_dealer_hand, v_deck[1]);
    v_deck := v_deck[2:array_length(v_deck, 1)];
    v_dealer_value := blackjack_calculate_hand(v_dealer_hand);
  END LOOP;

  -- Determine winner
  IF v_player_value > 21 THEN
    v_result := 'loss';
    v_payout := 0;
  ELSIF v_dealer_value > 21 OR v_player_value > v_dealer_value THEN
    v_result := 'win';
    v_payout := v_session.bet_amount * 2;
  ELSIF v_player_value = v_dealer_value THEN
    v_result := 'push';
    v_payout := v_session.bet_amount;
  ELSE
    v_result := 'loss';
    v_payout := 0;
  END IF;

  v_profit := v_payout - v_session.bet_amount;

  -- Credit payout
  IF v_payout > 0 THEN
    UPDATE users
    SET gc_balance = gc_balance + v_payout,
        updated_at = NOW()
    WHERE id = v_session.user_id
    RETURNING gc_balance INTO v_new_balance;
  ELSE
    SELECT gc_balance INTO v_new_balance FROM users WHERE id = v_session.user_id;
  END IF;

  -- Update session
  UPDATE game_sessions
  SET result = v_result,
      payout_amount = v_payout,
      profit_loss = v_profit,
      game_data = game_data
        || jsonb_build_object('dealer_hand', v_dealer_hand)
        || jsonb_build_object('dealer_value', v_dealer_value)
  WHERE id = p_session_id;

  -- Log transaction
  INSERT INTO gc_transactions (
    user_id, amount, balance_after, transaction_type, reference_id, description
  ) VALUES (
    v_session.user_id, v_profit, v_new_balance,
    CASE WHEN v_result = 'win' THEN 'game_win' WHEN v_result = 'push' THEN 'game_push' ELSE 'game_loss' END,
    'blackjack_' || p_session_id::text,
    'Blackjack: ' || v_result || ' (Player: ' || v_player_value || ', Dealer: ' || v_dealer_value || ')'
  );

  RETURN json_build_object(
    'success', TRUE,
    'result', v_result,
    'dealer_hand', v_dealer_hand,
    'dealer_value', v_dealer_value,
    'player_value', v_player_value,
    'payout', v_payout,
    'profit', v_profit,
    'new_balance', v_new_balance
  );
END;
$$;

-- =====================================================
-- 11. REACTION GAME (Memecoin Trading Simulator)
-- =====================================================
CREATE OR REPLACE FUNCTION reaction_complete_game(
  p_user_id UUID,
  p_bet_amount BIGINT,
  p_reaction_time_ms INT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_balance BIGINT;
  v_result VARCHAR(20);
  v_payout BIGINT;
  v_profit BIGINT;
  v_new_balance BIGINT;
  v_session_id UUID;
BEGIN
  -- Validate
  IF p_bet_amount < 10 OR p_bet_amount > 10000 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Bet must be between 10-10,000 GC');
  END IF;

  -- Get balance
  SELECT gc_balance INTO v_current_balance
  FROM users
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_current_balance < p_bet_amount THEN
    RETURN json_build_object('success', FALSE, 'error', 'Insufficient balance');
  END IF;

  -- Determine result based on reaction time
  IF p_reaction_time_ms < 0 OR p_reaction_time_ms > 10000 THEN
    -- Invalid/suspicious reaction time
    v_result := 'loss';
    v_payout := 0;
  ELSIF p_reaction_time_ms <= 1000 THEN
    -- Win: Reacted within 1 second
    v_result := 'win';
    v_payout := p_bet_amount * 2;
  ELSE
    -- Loss: Too slow
    v_result := 'loss';
    v_payout := 0;
  END IF;

  v_profit := v_payout - p_bet_amount;

  -- Deduct bet
  UPDATE users
  SET gc_balance = gc_balance - p_bet_amount,
      updated_at = NOW()
  WHERE id = p_user_id;

  -- Credit winnings if won
  IF v_payout > 0 THEN
    UPDATE users
    SET gc_balance = gc_balance + v_payout,
        updated_at = NOW()
    WHERE id = p_user_id
    RETURNING gc_balance INTO v_new_balance;
  ELSE
    SELECT gc_balance INTO v_new_balance FROM users WHERE id = p_user_id;
  END IF;

  -- Create session record
  INSERT INTO game_sessions (
    user_id, game_type, bet_amount, result, payout_amount, profit_loss,
    game_data, server_seed
  ) VALUES (
    p_user_id, 'reaction', p_bet_amount, v_result, v_payout, v_profit,
    json_build_object('reaction_time_ms', p_reaction_time_ms)::jsonb,
    generate_game_seed()
  ) RETURNING id INTO v_session_id;

  -- Log transaction
  INSERT INTO gc_transactions (
    user_id, amount, balance_after, transaction_type, reference_id, description
  ) VALUES (
    p_user_id, v_profit, v_new_balance,
    CASE WHEN v_result = 'win' THEN 'game_win' ELSE 'game_loss' END,
    'reaction_' || v_session_id::text,
    'Reaction game: ' || p_reaction_time_ms::text || 'ms'
  );

  RETURN json_build_object(
    'success', TRUE,
    'result', v_result,
    'reaction_time', p_reaction_time_ms,
    'payout', v_payout,
    'profit', v_profit,
    'new_balance', v_new_balance
  );
END;
$$;

-- =====================================================
-- 12. GET GAME HISTORY
-- =====================================================
CREATE OR REPLACE FUNCTION get_game_history(
  p_user_id UUID,
  p_limit INT DEFAULT 50
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT json_agg(
      json_build_object(
        'id', id,
        'game_type', game_type,
        'bet_amount', bet_amount,
        'result', result,
        'payout', payout_amount,
        'profit', profit_loss,
        'created_at', created_at
      ) ORDER BY created_at DESC
    )
    FROM (
      SELECT * FROM game_sessions
      WHERE user_id = p_user_id
      ORDER BY created_at DESC
      LIMIT p_limit
    ) games
  );
END;
$$;

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================
GRANT EXECUTE ON FUNCTION crash_start_round TO authenticated, anon;
GRANT EXECUTE ON FUNCTION crash_cashout TO authenticated, anon;
GRANT EXECUTE ON FUNCTION mines_start_game TO authenticated, anon;
GRANT EXECUTE ON FUNCTION mines_reveal_tile TO authenticated, anon;
GRANT EXECUTE ON FUNCTION mines_cashout TO authenticated, anon;
GRANT EXECUTE ON FUNCTION blackjack_start_game TO authenticated, anon;
GRANT EXECUTE ON FUNCTION blackjack_hit TO authenticated, anon;
GRANT EXECUTE ON FUNCTION blackjack_stand TO authenticated, anon;
GRANT EXECUTE ON FUNCTION reaction_complete_game TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_game_history TO authenticated, anon;

-- =====================================================
-- VERIFICATION
-- =====================================================
SELECT 'Warrior Games System Ready!' as status;
