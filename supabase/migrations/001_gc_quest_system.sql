-- ============================================
-- GOLD COINS (GC) & QUEST SYSTEM MIGRATION
-- ============================================
-- This migration sets up:
-- 1. Invite codes with ABCD1234 format and reservation system
-- 2. Quest system with progress tracking
-- 3. NFT holder verification
-- 4. Secure server-side GC operations
-- ============================================

-- ============================================
-- STEP 1: CREATE USERS TABLE IF NOT EXISTS
-- ============================================

-- Create users table if it doesn't exist
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255),
  display_name VARCHAR(50) NOT NULL,
  wallet_address VARCHAR(255) UNIQUE NOT NULL,
  gc_balance BIGINT DEFAULT 0,
  auth_user_id UUID,
  level INT DEFAULT 1,
  total_wins INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index on wallet_address for fast lookups
CREATE INDEX IF NOT EXISTS idx_users_wallet_address ON users(wallet_address);
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON users(auth_user_id);

-- Rename gp_balance to gc_balance if it exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'gp_balance') THEN
    ALTER TABLE users RENAME COLUMN gp_balance TO gc_balance;
  END IF;
END $$;

-- ============================================
-- STEP 2: INVITE CODES TABLE
-- ============================================

-- Drop old codes table if exists and create new one
DROP TABLE IF EXISTS invite_codes CASCADE;

CREATE TABLE invite_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(8) UNIQUE NOT NULL, -- Format: ABCD1234
  created_by UUID REFERENCES users(id) ON DELETE SET NULL, -- NULL for starter codes
  used_by UUID REFERENCES users(id) ON DELETE SET NULL,
  reserved_by VARCHAR(255), -- Wallet address reserving the code
  reserved_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  used_at TIMESTAMPTZ
);

-- Index for fast lookups
CREATE INDEX idx_invite_codes_code ON invite_codes(code);
CREATE INDEX idx_invite_codes_created_by ON invite_codes(created_by);
CREATE INDEX idx_invite_codes_used_by ON invite_codes(used_by);

-- ============================================
-- STEP 3: QUEST TEMPLATES TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS quest_templates (
  id VARCHAR(50) PRIMARY KEY, -- e.g., 'first_steps', 'invite_3_friends'
  name VARCHAR(100) NOT NULL,
  description TEXT,
  gc_reward BIGINT NOT NULL,
  target_count INT DEFAULT 1, -- For progress-based quests
  quest_type VARCHAR(50) DEFAULT 'one_time', -- 'one_time', 'daily', 'repeatable'
  auto_claim BOOLEAN DEFAULT FALSE, -- Auto-claim when complete
  is_active BOOLEAN DEFAULT TRUE,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- STEP 4: USER QUESTS PROGRESS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS user_quests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  quest_id VARCHAR(50) NOT NULL REFERENCES quest_templates(id) ON DELETE CASCADE,
  progress INT DEFAULT 0,
  is_completed BOOLEAN DEFAULT FALSE,
  is_claimed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMPTZ,
  claimed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, quest_id)
);

-- Indexes
CREATE INDEX idx_user_quests_user_id ON user_quests(user_id);
CREATE INDEX idx_user_quests_quest_id ON user_quests(quest_id);

-- ============================================
-- STEP 5: GC TRANSACTIONS TABLE (AUDIT LOG)
-- ============================================

CREATE TABLE IF NOT EXISTS gc_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount BIGINT NOT NULL, -- Positive for credit, negative for debit
  balance_after BIGINT NOT NULL,
  transaction_type VARCHAR(50) NOT NULL, -- 'quest_reward', 'game_win', 'game_loss', 'signup_bonus', 'nft_bonus'
  reference_id VARCHAR(100), -- Quest ID, game ID, etc.
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for user history
CREATE INDEX idx_gc_transactions_user_id ON gc_transactions(user_id);
CREATE INDEX idx_gc_transactions_created_at ON gc_transactions(created_at DESC);

-- ============================================
-- STEP 6: INSERT DEFAULT QUEST TEMPLATES
-- ============================================

INSERT INTO quest_templates (id, name, description, gc_reward, target_count, quest_type, auto_claim, sort_order)
VALUES
  ('first_steps', 'First Steps', 'Welcome to the arena! Claim your signup bonus.', 500, 1, 'one_time', TRUE, 1),
  ('invite_3_friends', 'Recruit Warriors', 'Invite 3 friends to join the battle.', 500, 3, 'one_time', FALSE, 2),
  ('like_retweet', 'Like & Retweet', 'Like and retweet our post on X.', 500, 1, 'one_time', FALSE, 3),
  ('twitter_follow', 'Follow Us', 'Follow @Duelpvp on X.', 500, 1, 'one_time', FALSE, 4),
  ('post_wallet', 'Post Your EVM Wallet', 'Post your EVM wallet address under our tweet.', 1000, 1, 'one_time', FALSE, 5),
  ('fluffle_holder', 'FLUFFLE Holder', 'Hold a FLUFFLE NFT in your wallet.', 5000, 1, 'one_time', FALSE, 6),
  ('bunnz_holder', 'BAD BUNNZ Holder', 'Hold a BAD BUNNZ NFT in your wallet.', 850, 1, 'one_time', FALSE, 7)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  gc_reward = EXCLUDED.gc_reward,
  target_count = EXCLUDED.target_count,
  sort_order = EXCLUDED.sort_order;

-- ============================================
-- STEP 7: GENERATE INVITE CODE FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION generate_invite_code()
RETURNS VARCHAR(8)
LANGUAGE plpgsql
AS $$
DECLARE
  letters VARCHAR(26) := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  digits VARCHAR(10) := '0123456789';
  new_code VARCHAR(8);
  code_exists BOOLEAN;
BEGIN
  LOOP
    -- Generate format: ABCD1234
    new_code := '';
    -- 4 random letters
    FOR i IN 1..4 LOOP
      new_code := new_code || substr(letters, floor(random() * 26 + 1)::int, 1);
    END LOOP;
    -- 4 random digits
    FOR i IN 1..4 LOOP
      new_code := new_code || substr(digits, floor(random() * 10 + 1)::int, 1);
    END LOOP;

    -- Check if code already exists
    SELECT EXISTS(SELECT 1 FROM invite_codes WHERE code = new_code) INTO code_exists;

    IF NOT code_exists THEN
      RETURN new_code;
    END IF;
  END LOOP;
END;
$$;

-- ============================================
-- STEP 8: INSERT 10 STARTER CODES
-- ============================================

DO $$
BEGIN
  FOR i IN 1..10 LOOP
    INSERT INTO invite_codes (code, created_by)
    VALUES (generate_invite_code(), NULL);
  END LOOP;
END $$;

-- ============================================
-- STEP 9: VALIDATE INVITE CODE FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION validate_invite_code(p_code VARCHAR)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_code_record RECORD;
BEGIN
  -- Find the code
  SELECT * INTO v_code_record
  FROM invite_codes
  WHERE code = UPPER(p_code);

  -- Code doesn't exist
  IF NOT FOUND THEN
    RETURN json_build_object('valid', FALSE, 'error', 'Invalid invite code');
  END IF;

  -- Code already used
  IF v_code_record.used_by IS NOT NULL THEN
    RETURN json_build_object('valid', FALSE, 'error', 'Code already used');
  END IF;

  -- Code reserved by someone else and not expired
  IF v_code_record.reserved_by IS NOT NULL
     AND v_code_record.reserved_until > NOW() THEN
    RETURN json_build_object('valid', FALSE, 'error', 'Code temporarily unavailable');
  END IF;

  RETURN json_build_object('valid', TRUE, 'code', v_code_record.code);
END;
$$;

-- ============================================
-- STEP 10: RESERVE INVITE CODE FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION reserve_invite_code(p_code VARCHAR, p_wallet_address VARCHAR)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_code_record RECORD;
BEGIN
  -- Find and lock the code
  SELECT * INTO v_code_record
  FROM invite_codes
  WHERE code = UPPER(p_code)
  FOR UPDATE;

  -- Code doesn't exist
  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Invalid invite code');
  END IF;

  -- Code already used
  IF v_code_record.used_by IS NOT NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Code already used');
  END IF;

  -- Code reserved by someone else and not expired
  IF v_code_record.reserved_by IS NOT NULL
     AND v_code_record.reserved_by != LOWER(p_wallet_address)
     AND v_code_record.reserved_until > NOW() THEN
    RETURN json_build_object('success', FALSE, 'error', 'Code temporarily unavailable');
  END IF;

  -- Reserve the code for 5 minutes
  UPDATE invite_codes
  SET reserved_by = LOWER(p_wallet_address),
      reserved_until = NOW() + INTERVAL '5 minutes'
  WHERE id = v_code_record.id;

  RETURN json_build_object('success', TRUE, 'reserved_until', NOW() + INTERVAL '5 minutes');
END;
$$;

-- ============================================
-- STEP 11: CHECK NFT HOLDINGS FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION check_nft_holdings(p_wallet_address VARCHAR)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_has_fluffle BOOLEAN := FALSE;
  v_has_bunnz BOOLEAN := FALSE;
BEGIN
  -- Check fluffle_holders table
  SELECT EXISTS(
    SELECT 1 FROM fluffle_holders
    WHERE LOWER(wallet_address) = LOWER(p_wallet_address)
  ) INTO v_has_fluffle;

  -- Check bunnz_holders table
  SELECT EXISTS(
    SELECT 1 FROM bunnz_holders
    WHERE LOWER(wallet_address) = LOWER(p_wallet_address)
  ) INTO v_has_bunnz;

  RETURN json_build_object(
    'has_fluffle', v_has_fluffle,
    'has_bunnz', v_has_bunnz
  );
END;
$$;

-- ============================================
-- STEP 12: REGISTER USER WITH WALLET
-- ============================================

CREATE OR REPLACE FUNCTION register_user_with_wallet(
  p_wallet_address VARCHAR,
  p_display_name VARCHAR,
  p_email VARCHAR DEFAULT NULL,
  p_invite_code VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_code_record RECORD;
  v_inviter_id UUID;
  v_nft_holdings JSON;
  v_initial_gc BIGINT := 0;
  v_new_code VARCHAR(8);
BEGIN
  -- Check if wallet already registered
  IF EXISTS (SELECT 1 FROM users WHERE LOWER(wallet_address) = LOWER(p_wallet_address)) THEN
    RETURN json_build_object('success', FALSE, 'error', 'Wallet already registered');
  END IF;

  -- Check if display name taken
  IF EXISTS (SELECT 1 FROM users WHERE LOWER(display_name) = LOWER(p_display_name)) THEN
    RETURN json_build_object('success', FALSE, 'error', 'Display name already taken');
  END IF;

  -- Validate and get invite code
  IF p_invite_code IS NOT NULL THEN
    SELECT * INTO v_code_record
    FROM invite_codes
    WHERE code = UPPER(p_invite_code)
    FOR UPDATE;

    IF NOT FOUND THEN
      RETURN json_build_object('success', FALSE, 'error', 'Invalid invite code');
    END IF;

    IF v_code_record.used_by IS NOT NULL THEN
      RETURN json_build_object('success', FALSE, 'error', 'Code already used');
    END IF;

    -- Check reservation
    IF v_code_record.reserved_by IS NOT NULL
       AND v_code_record.reserved_by != LOWER(p_wallet_address)
       AND v_code_record.reserved_until > NOW() THEN
      RETURN json_build_object('success', FALSE, 'error', 'Code reserved by another user');
    END IF;

    v_inviter_id := v_code_record.created_by;
  END IF;

  -- Check NFT holdings
  v_nft_holdings := check_nft_holdings(p_wallet_address);

  -- Create user
  INSERT INTO users (wallet_address, display_name, email, gc_balance)
  VALUES (LOWER(p_wallet_address), p_display_name, p_email, v_initial_gc)
  RETURNING id INTO v_user_id;

  -- Mark invite code as used
  IF p_invite_code IS NOT NULL THEN
    UPDATE invite_codes
    SET used_by = v_user_id,
        used_at = NOW(),
        reserved_by = NULL,
        reserved_until = NULL
    WHERE id = v_code_record.id;

    -- Update inviter's quest progress
    IF v_inviter_id IS NOT NULL THEN
      INSERT INTO user_quests (user_id, quest_id, progress)
      VALUES (v_inviter_id, 'invite_3_friends', 1)
      ON CONFLICT (user_id, quest_id) DO UPDATE
      SET progress = user_quests.progress + 1,
          is_completed = (user_quests.progress + 1 >= 3),
          completed_at = CASE WHEN user_quests.progress + 1 >= 3 THEN NOW() ELSE NULL END,
          updated_at = NOW();
    END IF;
  END IF;

  -- Generate 3 invite codes for new user
  FOR i IN 1..3 LOOP
    v_new_code := generate_invite_code();
    INSERT INTO invite_codes (code, created_by)
    VALUES (v_new_code, v_user_id);
  END LOOP;

  -- Initialize quests for user
  INSERT INTO user_quests (user_id, quest_id, progress, is_completed, completed_at)
  SELECT v_user_id, qt.id,
         CASE
           WHEN qt.id = 'first_steps' THEN 1
           WHEN qt.id = 'fluffle_holder' AND (v_nft_holdings->>'has_fluffle')::boolean THEN 1
           WHEN qt.id = 'bunnz_holder' AND (v_nft_holdings->>'has_bunnz')::boolean THEN 1
           WHEN qt.id = 'megalio_holder' AND (v_nft_holdings->>'has_megalio')::boolean THEN 1
           ELSE 0
         END,
         CASE
           WHEN qt.id = 'first_steps' THEN TRUE
           WHEN qt.id = 'fluffle_holder' AND (v_nft_holdings->>'has_fluffle')::boolean THEN TRUE
           WHEN qt.id = 'bunnz_holder' AND (v_nft_holdings->>'has_bunnz')::boolean THEN TRUE
           WHEN qt.id = 'megalio_holder' AND (v_nft_holdings->>'has_megalio')::boolean THEN TRUE
           ELSE FALSE
         END,
         CASE
           WHEN qt.id = 'first_steps' THEN NOW()
           WHEN qt.id = 'fluffle_holder' AND (v_nft_holdings->>'has_fluffle')::boolean THEN NOW()
           WHEN qt.id = 'bunnz_holder' AND (v_nft_holdings->>'has_bunnz')::boolean THEN NOW()
           WHEN qt.id = 'megalio_holder' AND (v_nft_holdings->>'has_megalio')::boolean THEN NOW()
           ELSE NULL
         END
  FROM quest_templates qt
  WHERE qt.is_active = TRUE;

  -- First Steps quest is auto-completed but NOT auto-claimed
  -- User must click "Claim" to receive the 500 GC reward

  -- Return success with user info
  RETURN json_build_object(
    'success', TRUE,
    'user_id', v_user_id,
    'has_fluffle', (v_nft_holdings->>'has_fluffle')::boolean,
    'has_bunnz', (v_nft_holdings->>'has_bunnz')::boolean,
    'has_megalio', (v_nft_holdings->>'has_megalio')::boolean
  );
END;
$$;

-- ============================================
-- STEP 13: CLAIM QUEST REWARD FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION claim_quest_reward(p_user_id UUID, p_quest_id VARCHAR)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_quest RECORD;
  v_user_quest RECORD;
  v_new_balance BIGINT;
BEGIN
  -- Get quest template
  SELECT * INTO v_quest
  FROM quest_templates
  WHERE id = p_quest_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Quest not found');
  END IF;

  -- Get user's quest progress
  SELECT * INTO v_user_quest
  FROM user_quests
  WHERE user_id = p_user_id AND quest_id = p_quest_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Quest not started');
  END IF;

  -- Check if already claimed
  IF v_user_quest.is_claimed THEN
    RETURN json_build_object('success', FALSE, 'error', 'Quest already claimed');
  END IF;

  -- Check if completed
  IF NOT v_user_quest.is_completed THEN
    RETURN json_build_object('success', FALSE, 'error', 'Quest not completed');
  END IF;

  -- Update user's GC balance
  UPDATE users
  SET gc_balance = gc_balance + v_quest.gc_reward,
      updated_at = NOW()
  WHERE id = p_user_id
  RETURNING gc_balance INTO v_new_balance;

  -- Mark quest as claimed
  UPDATE user_quests
  SET is_claimed = TRUE,
      claimed_at = NOW(),
      updated_at = NOW()
  WHERE user_id = p_user_id AND quest_id = p_quest_id;

  -- Log transaction
  INSERT INTO gc_transactions (user_id, amount, balance_after, transaction_type, reference_id, description)
  VALUES (p_user_id, v_quest.gc_reward, v_new_balance, 'quest_reward', p_quest_id, 'Quest reward: ' || v_quest.name);

  RETURN json_build_object(
    'success', TRUE,
    'reward', v_quest.gc_reward,
    'new_balance', v_new_balance
  );
END;
$$;

-- ============================================
-- STEP 13B: COMPLETE MANUAL QUEST FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION complete_manual_quest(p_user_id UUID, p_quest_id VARCHAR)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_quest RECORD;
  v_user_quest RECORD;
  v_new_balance BIGINT;
BEGIN
  -- Get quest template
  SELECT * INTO v_quest
  FROM quest_templates
  WHERE id = p_quest_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Quest not found');
  END IF;

  -- Get or create user's quest progress
  INSERT INTO user_quests (user_id, quest_id, progress, is_completed, is_claimed)
  VALUES (p_user_id, p_quest_id, 0, FALSE, FALSE)
  ON CONFLICT (user_id, quest_id) DO NOTHING;

  SELECT * INTO v_user_quest
  FROM user_quests
  WHERE user_id = p_user_id AND quest_id = p_quest_id
  FOR UPDATE;

  -- Check if already claimed
  IF v_user_quest.is_claimed THEN
    RETURN json_build_object('success', FALSE, 'error', 'Quest already completed');
  END IF;

  -- Mark quest as completed and claimed
  UPDATE user_quests
  SET progress = v_quest.target_count,
      is_completed = TRUE,
      is_claimed = TRUE,
      completed_at = NOW(),
      claimed_at = NOW(),
      updated_at = NOW()
  WHERE user_id = p_user_id AND quest_id = p_quest_id;

  -- Update user's GC balance
  UPDATE users
  SET gc_balance = gc_balance + v_quest.gc_reward,
      updated_at = NOW()
  WHERE id = p_user_id
  RETURNING gc_balance INTO v_new_balance;

  -- Log transaction
  INSERT INTO gc_transactions (user_id, amount, balance_after, transaction_type, reference_id, description)
  VALUES (p_user_id, v_quest.gc_reward, v_new_balance, 'quest_reward', p_quest_id, 'Quest reward: ' || v_quest.name);

  RETURN json_build_object(
    'success', TRUE,
    'reward', v_quest.gc_reward,
    'new_balance', v_new_balance
  );
END;
$$;

-- ============================================
-- STEP 14: GET USER QUESTS FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION get_user_quests(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT json_agg(
      json_build_object(
        'id', qt.id,
        'name', qt.name,
        'description', qt.description,
        'gc_reward', qt.gc_reward,
        'target_count', qt.target_count,
        'progress', COALESCE(uq.progress, 0),
        'is_completed', COALESCE(uq.is_completed, FALSE),
        'is_claimed', COALESCE(uq.is_claimed, FALSE)
      ) ORDER BY qt.sort_order
    )
    FROM quest_templates qt
    LEFT JOIN user_quests uq ON uq.quest_id = qt.id AND uq.user_id = p_user_id
    WHERE qt.is_active = TRUE
  );
END;
$$;

-- ============================================
-- STEP 15: GET USER INVITE CODES FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION get_user_invite_codes(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT json_agg(
      json_build_object(
        'code', code,
        'created_at', created_at,
        'is_used', used_by IS NOT NULL
      ) ORDER BY created_at DESC
    )
    FROM invite_codes
    WHERE created_by = p_user_id
      AND used_by IS NULL -- Only return unused codes
  );
END;
$$;

-- ============================================
-- STEP 16: GET LEADERBOARD FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION get_leaderboard(p_limit INT DEFAULT 100)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT json_agg(
      json_build_object(
        'rank', row_number,
        'display_name', display_name,
        'wallet_address', wallet_address,
        'gc_balance', gc_balance
      )
    )
    FROM (
      SELECT
        ROW_NUMBER() OVER (ORDER BY gc_balance DESC) as row_number,
        display_name,
        wallet_address,
        gc_balance
      FROM users
      WHERE gc_balance > 0
      ORDER BY gc_balance DESC
      LIMIT p_limit
    ) ranked
  );
END;
$$;

-- ============================================
-- STEP 17: GET USER RANK FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION get_user_rank(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rank BIGINT;
  v_user RECORD;
BEGIN
  SELECT * INTO v_user FROM users WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN json_build_object('rank', NULL);
  END IF;

  SELECT COUNT(*) + 1 INTO v_rank
  FROM users
  WHERE gc_balance > v_user.gc_balance;

  RETURN json_build_object(
    'rank', v_rank,
    'display_name', v_user.display_name,
    'gc_balance', v_user.gc_balance
  );
END;
$$;

-- ============================================
-- STEP 18: SECURE UPDATE GC FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION secure_update_gc(
  p_user_id UUID,
  p_amount BIGINT,
  p_transaction_type VARCHAR,
  p_reference_id VARCHAR DEFAULT NULL,
  p_description TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_new_balance BIGINT;
  v_current_balance BIGINT;
BEGIN
  -- Get current balance with lock
  SELECT gc_balance INTO v_current_balance
  FROM users
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'User not found');
  END IF;

  -- Prevent negative balance
  IF v_current_balance + p_amount < 0 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Insufficient balance');
  END IF;

  -- Update balance
  UPDATE users
  SET gc_balance = gc_balance + p_amount,
      updated_at = NOW()
  WHERE id = p_user_id
  RETURNING gc_balance INTO v_new_balance;

  -- Log transaction
  INSERT INTO gc_transactions (user_id, amount, balance_after, transaction_type, reference_id, description)
  VALUES (p_user_id, p_amount, v_new_balance, p_transaction_type, p_reference_id, p_description);

  RETURN json_build_object(
    'success', TRUE,
    'new_balance', v_new_balance
  );
END;
$$;

-- ============================================
-- STEP 19: ROW LEVEL SECURITY POLICIES
-- ============================================

-- Enable RLS on tables
ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_quests ENABLE ROW LEVEL SECURITY;
ALTER TABLE gc_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quest_templates ENABLE ROW LEVEL SECURITY;

-- Quest templates are readable by all
CREATE POLICY "Quest templates are viewable by all" ON quest_templates
  FOR SELECT USING (TRUE);

-- Users can view their own quests
CREATE POLICY "Users can view own quests" ON user_quests
  FOR SELECT USING (auth.uid()::text IN (
    SELECT auth_user_id::text FROM users WHERE id = user_id
  ));

-- Users can view their own transactions
CREATE POLICY "Users can view own transactions" ON gc_transactions
  FOR SELECT USING (auth.uid()::text IN (
    SELECT auth_user_id::text FROM users WHERE id = user_id
  ));

-- Users can view their own invite codes
CREATE POLICY "Users can view own codes" ON invite_codes
  FOR SELECT USING (
    created_by IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
    OR used_by IS NULL -- Can view unused codes for validation
  );

-- ============================================
-- STEP 20: LOGIN WITH WALLET FUNCTION (UPDATED)
-- ============================================

CREATE OR REPLACE FUNCTION login_with_wallet(p_wallet_address VARCHAR)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user RECORD;
  v_nft_holdings JSON;
BEGIN
  -- Find user
  SELECT * INTO v_user
  FROM users
  WHERE LOWER(wallet_address) = LOWER(p_wallet_address);

  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Wallet not registered');
  END IF;

  -- Check NFT holdings and update quests if needed
  v_nft_holdings := check_nft_holdings(p_wallet_address);

  -- Update FLUFFLE quest if holder
  IF (v_nft_holdings->>'has_fluffle')::boolean THEN
    UPDATE user_quests
    SET progress = 1,
        is_completed = TRUE,
        completed_at = COALESCE(completed_at, NOW()),
        updated_at = NOW()
    WHERE user_id = v_user.id AND quest_id = 'fluffle_holder' AND NOT is_completed;
  END IF;

  -- Update BUNNZ quest if holder
  IF (v_nft_holdings->>'has_bunnz')::boolean THEN
    UPDATE user_quests
    SET progress = 1,
        is_completed = TRUE,
        completed_at = COALESCE(completed_at, NOW()),
        updated_at = NOW()
    WHERE user_id = v_user.id AND quest_id = 'bunnz_holder' AND NOT is_completed;
  END IF;

  -- Update MEGALIO quest if holder
  IF (v_nft_holdings->>'has_megalio')::boolean THEN
    UPDATE user_quests
    SET progress = 1,
        is_completed = TRUE,
        completed_at = COALESCE(completed_at, NOW()),
        updated_at = NOW()
    WHERE user_id = v_user.id AND quest_id = 'megalio_holder' AND NOT is_completed;
  END IF;

  RETURN json_build_object(
    'success', TRUE,
    'user_id', v_user.id,
    'display_name', v_user.display_name,
    'gc_balance', v_user.gc_balance,
    'has_fluffle', (v_nft_holdings->>'has_fluffle')::boolean,
    'has_bunnz', (v_nft_holdings->>'has_bunnz')::boolean,
    'has_megalio', (v_nft_holdings->>'has_megalio')::boolean
  );
END;
$$;

-- ============================================
-- COMPLETE!
-- ============================================
-- Run this entire script in Supabase SQL Editor
-- After running, you'll have:
-- 1. Updated users table with gc_balance
-- 2. invite_codes table with ABCD1234 format
-- 3. Quest system with 4 quests
-- 4. 10 starter invite codes
-- 5. All secure RPC functions
-- ============================================
