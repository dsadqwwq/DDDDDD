-- ============================================
-- DUEL PVP - COMPLETE SUPABASE SETUP FOR GAMES
-- ============================================
-- This script sets up all necessary tables, functions, and policies
-- for the gaming functionality to work properly.

-- ============================================
-- TABLES
-- ============================================

-- Users table (main user data)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_address TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  email TEXT UNIQUE,
  gc_balance INTEGER DEFAULT 0 CHECK (gc_balance >= 0),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_wallet ON users(wallet_address);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_gc_balance ON users(gc_balance DESC);

-- Invite codes table
CREATE TABLE IF NOT EXISTS codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  created_by UUID REFERENCES users(id) ON DELETE CASCADE,
  used_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  used_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_codes_code ON codes(code);
CREATE INDEX IF NOT EXISTS idx_codes_created_by ON codes(created_by);

-- Game scores table (for reaction game)
CREATE TABLE IF NOT EXISTS scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  time_ms INTEGER NOT NULL,
  game_type TEXT NOT NULL DEFAULT 'reaction',
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scores_user ON scores(user_id);
CREATE INDEX IF NOT EXISTS idx_scores_time ON scores(time_ms);
CREATE INDEX IF NOT EXISTS idx_scores_created ON scores(created_at DESC);

-- Transactions table (for tracking all GC movements)
CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL,
  transaction_type TEXT NOT NULL, -- 'game_win', 'game_loss', 'staking', 'farming', 'referral', etc.
  game_type TEXT, -- 'crash', 'mines', 'blackjack', 'reaction', etc.
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created ON transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(transaction_type);

-- Inventory items table (for NFTs, rewards, etc.)
-- This was already created in add_founders_swords.sql, but including for completeness
CREATE TABLE IF NOT EXISTS inventory_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  item_type VARCHAR(50) NOT NULL,
  item_name VARCHAR(100) NOT NULL,
  item_description TEXT,
  item_rarity VARCHAR(20), -- common, rare, epic, legendary
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, item_type, item_name)
);

CREATE INDEX IF NOT EXISTS idx_inventory_items_user_id ON inventory_items(user_id);
CREATE INDEX IF NOT EXISTS idx_inventory_items_type ON inventory_items(item_type);

-- ============================================
-- CORE RPC FUNCTIONS FOR GAMES
-- ============================================

-- Function to get user's GC balance
CREATE OR REPLACE FUNCTION get_user_gc(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_balance INTEGER;
BEGIN
  SELECT gc_balance INTO v_balance
  FROM users
  WHERE id = p_user_id;

  RETURN COALESCE(v_balance, 0);
END;
$$;

-- Function to update user GC (secure, JWT-based)
CREATE OR REPLACE FUNCTION secure_update_gp(
  p_amount INTEGER,
  p_transaction_type TEXT,
  p_game_type TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_new_balance INTEGER;
  v_old_balance INTEGER;
BEGIN
  -- Get user ID from JWT
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Get current balance
  SELECT gc_balance INTO v_old_balance
  FROM users
  WHERE id = v_user_id;

  -- Check if user exists
  IF v_old_balance IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  -- Check for negative balance (prevent going below 0)
  IF (v_old_balance + p_amount) < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  -- Update balance
  UPDATE users
  SET gc_balance = gc_balance + p_amount,
      updated_at = NOW()
  WHERE id = v_user_id
  RETURNING gc_balance INTO v_new_balance;

  -- Record transaction
  INSERT INTO transactions (user_id, amount, transaction_type, game_type)
  VALUES (v_user_id, p_amount, p_transaction_type, p_game_type);

  RETURN jsonb_build_object(
    'success', true,
    'old_balance', v_old_balance,
    'new_balance', v_new_balance,
    'amount', p_amount
  );
END;
$$;

-- Fallback function for updating GC (without JWT, uses user_id directly)
CREATE OR REPLACE FUNCTION update_user_gp(
  p_user_id UUID,
  p_amount INTEGER,
  p_transaction_type TEXT,
  p_game_type TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_new_balance INTEGER;
  v_old_balance INTEGER;
BEGIN
  -- Get current balance
  SELECT gc_balance INTO v_old_balance
  FROM users
  WHERE id = p_user_id;

  -- Check if user exists
  IF v_old_balance IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  -- Check for negative balance
  IF (v_old_balance + p_amount) < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  -- Update balance
  UPDATE users
  SET gc_balance = gc_balance + p_amount,
      updated_at = NOW()
  WHERE id = p_user_id
  RETURNING gc_balance INTO v_new_balance;

  -- Record transaction
  INSERT INTO transactions (user_id, amount, transaction_type, game_type)
  VALUES (p_user_id, p_amount, p_transaction_type, p_game_type);

  RETURN jsonb_build_object(
    'success', true,
    'old_balance', v_old_balance,
    'new_balance', v_new_balance,
    'amount', p_amount
  );
END;
$$;

-- Function to get leaderboard
CREATE OR REPLACE FUNCTION get_leaderboard(p_limit INTEGER DEFAULT 100)
RETURNS TABLE (
  rank BIGINT,
  user_id UUID,
  display_name TEXT,
  wallet_address TEXT,
  gc_balance INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ROW_NUMBER() OVER (ORDER BY u.gc_balance DESC) as rank,
    u.id as user_id,
    u.display_name,
    u.wallet_address,
    u.gc_balance
  FROM users u
  ORDER BY u.gc_balance DESC
  LIMIT p_limit;
END;
$$;

-- Function to get user's rank
CREATE OR REPLACE FUNCTION get_user_rank(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rank BIGINT;
  v_gc_balance INTEGER;
BEGIN
  -- Get user's GC and rank
  SELECT
    (SELECT COUNT(*) + 1 FROM users WHERE gc_balance > u.gc_balance),
    u.gc_balance
  INTO v_rank, v_gc_balance
  FROM users u
  WHERE u.id = p_user_id;

  IF v_rank IS NULL THEN
    RETURN jsonb_build_object('rank', NULL, 'gc_balance', 0);
  END IF;

  RETURN jsonb_build_object('rank', v_rank, 'gc_balance', v_gc_balance);
END;
$$;

-- Function to get user's invite codes
CREATE OR REPLACE FUNCTION get_user_invite_codes(p_user_id UUID)
RETURNS TABLE (
  code TEXT,
  created_at TIMESTAMP,
  used_at TIMESTAMP
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT c.code, c.created_at, c.used_at
  FROM codes c
  WHERE c.created_by = p_user_id
    AND c.used_at IS NULL -- Only return unused codes
  ORDER BY c.created_at DESC;
END;
$$;

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_items ENABLE ROW LEVEL SECURITY;

-- Users table policies
CREATE POLICY "Users are viewable by everyone" ON users FOR SELECT USING (true);
CREATE POLICY "Users can update own record" ON users FOR UPDATE USING (auth.uid() = id);

-- Codes table policies
CREATE POLICY "Codes viewable by creator" ON codes FOR SELECT USING (created_by = auth.uid());
CREATE POLICY "Codes insertable by authenticated users" ON codes FOR INSERT WITH CHECK (auth.uid() = created_by);

-- Scores table policies
CREATE POLICY "Scores viewable by everyone" ON scores FOR SELECT USING (true);
CREATE POLICY "Scores insertable by authenticated users" ON scores FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Transactions table policies
CREATE POLICY "Transactions viewable by owner" ON transactions FOR SELECT USING (auth.uid() = user_id);

-- Inventory items policies
CREATE POLICY "Inventory viewable by owner" ON inventory_items FOR SELECT USING (auth.uid() = user_id);

-- ============================================
-- INITIAL DATA SETUP
-- ============================================

-- Grant execute permissions on RPC functions
GRANT EXECUTE ON FUNCTION get_user_gc TO authenticated, anon;
GRANT EXECUTE ON FUNCTION secure_update_gp TO authenticated, anon;
GRANT EXECUTE ON FUNCTION update_user_gp TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_leaderboard TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_user_rank TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_user_invite_codes TO authenticated, anon;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Run these to verify setup:
-- SELECT * FROM users LIMIT 5;
-- SELECT * FROM get_leaderboard(10);
-- SELECT get_user_gc('YOUR_USER_ID_HERE');
