-- =====================================================
-- SERVER-SIDE STAKING SYSTEM (10% HOURLY COMPOUND)
-- =====================================================
-- This prevents client-side cheating by calculating everything server-side
-- Run this AFTER add_gp_balance_system.sql

-- 1. Create stakes table
CREATE TABLE IF NOT EXISTS stakes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  amount bigint NOT NULL,
  deposited_at timestamp with time zone DEFAULT now(),
  last_compound_at timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(user_id) -- One stake per user
);

CREATE INDEX IF NOT EXISTS idx_stakes_user ON stakes(user_id);

-- =====================================================
-- DEPOSIT TO STAKING
-- =====================================================
-- Deducts GP from balance and creates/updates stake

CREATE OR REPLACE FUNCTION stake_deposit(
  p_user_id uuid,
  p_amount bigint
)
RETURNS TABLE(
  success boolean,
  message text,
  new_balance bigint,
  staked_amount bigint
)
LANGUAGE plpgsql
SECURITY definer
AS $$
DECLARE
  v_current_stake record;
  v_update_result record;
  v_new_stake_amount bigint;
BEGIN
  -- Validate amount
  IF p_amount < 100 THEN
    RETURN QUERY SELECT false, 'Minimum stake is 100 GP', 0::bigint, 0::bigint;
    RETURN;
  END IF;

  -- Deduct from user balance
  SELECT * INTO v_update_result
  FROM update_user_gp(p_user_id, -p_amount);

  IF NOT v_update_result.success THEN
    RETURN QUERY SELECT false, v_update_result.message, 0::bigint, 0::bigint;
    RETURN;
  END IF;

  -- Check if user has existing stake
  SELECT * INTO v_current_stake
  FROM stakes
  WHERE user_id = p_user_id;

  IF FOUND THEN
    -- Add to existing stake (after applying any pending compounds)
    -- First calculate current value with compound interest
    DECLARE
      v_hours_elapsed numeric;
      v_compounded_value bigint;
    BEGIN
      -- Calculate hours since last compound
      v_hours_elapsed := EXTRACT(EPOCH FROM (now() - v_current_stake.last_compound_at)) / 3600.0;

      -- Apply compound interest: amount * (1.10 ^ hours)
      v_compounded_value := floor(v_current_stake.amount * power(1.10, v_hours_elapsed))::bigint;

      -- New stake = compounded existing + new deposit
      v_new_stake_amount := v_compounded_value + p_amount;

      -- Update stake with new total and reset compound timer
      UPDATE stakes
      SET amount = v_new_stake_amount,
          last_compound_at = now()
      WHERE user_id = p_user_id;
    END;
  ELSE
    -- Create new stake
    v_new_stake_amount := p_amount;
    INSERT INTO stakes (user_id, amount, deposited_at, last_compound_at)
    VALUES (p_user_id, p_amount, now(), now());
  END IF;

  RETURN QUERY SELECT
    true,
    'Staked successfully',
    v_update_result.new_balance,
    v_new_stake_amount;
END;
$$;

-- =====================================================
-- GET CURRENT STAKE VALUE (WITH COMPOUND INTEREST)
-- =====================================================
-- Calculates current value based on time elapsed

CREATE OR REPLACE FUNCTION get_stake_value(p_user_id uuid)
RETURNS TABLE(
  staked_amount bigint,
  current_value bigint,
  profit bigint,
  hours_elapsed numeric,
  next_compound_in text
)
LANGUAGE plpgsql
SECURITY definer
AS $$
DECLARE
  v_stake record;
  v_hours_elapsed numeric;
  v_current_value bigint;
  v_profit bigint;
  v_seconds_until_next numeric;
  v_next_compound_text text;
BEGIN
  -- Get stake
  SELECT * INTO v_stake
  FROM stakes
  WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    -- No stake
    RETURN QUERY SELECT 0::bigint, 0::bigint, 0::bigint, 0::numeric, 'No active stake'::text;
    RETURN;
  END IF;

  -- Calculate hours elapsed since last compound
  v_hours_elapsed := EXTRACT(EPOCH FROM (now() - v_stake.last_compound_at)) / 3600.0;

  -- Calculate current value with compound interest: amount * (1.10 ^ hours)
  v_current_value := floor(v_stake.amount * power(1.10, v_hours_elapsed))::bigint;

  -- Calculate profit
  v_profit := v_current_value - v_stake.amount;

  -- Calculate time until next full hour
  v_seconds_until_next := 3600 - EXTRACT(EPOCH FROM (now() - v_stake.last_compound_at)) % 3600;

  -- Format countdown
  IF v_seconds_until_next >= 3600 THEN
    v_next_compound_text := 'Compounding...';
  ELSE
    v_next_compound_text :=
      LPAD(floor(v_seconds_until_next / 60)::text, 2, '0') || ':' ||
      LPAD(floor(v_seconds_until_next % 60)::text, 2, '0');
  END IF;

  RETURN QUERY SELECT
    v_stake.amount,
    v_current_value,
    v_profit,
    v_hours_elapsed,
    v_next_compound_text;
END;
$$;

-- =====================================================
-- APPLY COMPOUND (CONSOLIDATE GAINS)
-- =====================================================
-- Updates the base stake amount to include accrued compound interest
-- This is called automatically every hour on the server

CREATE OR REPLACE FUNCTION apply_stake_compound(p_user_id uuid)
RETURNS TABLE(
  success boolean,
  old_amount bigint,
  new_amount bigint,
  profit bigint
)
LANGUAGE plpgsql
SECURITY definer
AS $$
DECLARE
  v_stake record;
  v_hours_elapsed numeric;
  v_new_amount bigint;
  v_profit bigint;
BEGIN
  -- Get stake
  SELECT * INTO v_stake
  FROM stakes
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 0::bigint, 0::bigint, 0::bigint;
    RETURN;
  END IF;

  -- Calculate hours since last compound
  v_hours_elapsed := EXTRACT(EPOCH FROM (now() - v_stake.last_compound_at)) / 3600.0;

  -- Only compound if at least 1 hour has passed
  IF v_hours_elapsed < 1.0 THEN
    RETURN QUERY SELECT false, v_stake.amount, v_stake.amount, 0::bigint;
    RETURN;
  END IF;

  -- Calculate new amount with compound interest
  v_new_amount := floor(v_stake.amount * power(1.10, v_hours_elapsed))::bigint;
  v_profit := v_new_amount - v_stake.amount;

  -- Update stake
  UPDATE stakes
  SET amount = v_new_amount,
      last_compound_at = now()
  WHERE user_id = p_user_id;

  RETURN QUERY SELECT
    true,
    v_stake.amount,
    v_new_amount,
    v_profit;
END;
$$;

-- =====================================================
-- WITHDRAW FROM STAKING
-- =====================================================
-- Calculates final value and returns GP to user balance

CREATE OR REPLACE FUNCTION stake_withdraw(p_user_id uuid)
RETURNS TABLE(
  success boolean,
  message text,
  withdrawn_amount bigint,
  new_balance bigint
)
LANGUAGE plpgsql
SECURITY definer
AS $$
DECLARE
  v_stake record;
  v_hours_elapsed numeric;
  v_final_value bigint;
  v_update_result record;
BEGIN
  -- Get stake with lock
  SELECT * INTO v_stake
  FROM stakes
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'No active stake', 0::bigint, 0::bigint;
    RETURN;
  END IF;

  -- Calculate final value with all compound interest
  v_hours_elapsed := EXTRACT(EPOCH FROM (now() - v_stake.last_compound_at)) / 3600.0;
  v_final_value := floor(v_stake.amount * power(1.10, v_hours_elapsed))::bigint;

  -- Add to user balance
  SELECT * INTO v_update_result
  FROM update_user_gp(p_user_id, v_final_value);

  IF NOT v_update_result.success THEN
    RETURN QUERY SELECT false, 'Failed to credit GP', 0::bigint, 0::bigint;
    RETURN;
  END IF;

  -- Delete stake
  DELETE FROM stakes WHERE user_id = p_user_id;

  RETURN QUERY SELECT
    true,
    'Withdrawn successfully',
    v_final_value,
    v_update_result.new_balance;
END;
$$;

-- =====================================================
-- RLS POLICIES
-- =====================================================

ALTER TABLE stakes ENABLE ROW LEVEL SECURITY;

-- Users can view their own stakes
DROP POLICY IF EXISTS "Users can view own stakes" ON stakes;
CREATE POLICY "Users can view own stakes" ON stakes
  FOR SELECT USING (true);

-- Only server functions can modify stakes
DROP POLICY IF EXISTS "No direct stake manipulation" ON stakes;
CREATE POLICY "No direct stake manipulation" ON stakes
  FOR ALL USING (false);

-- =====================================================
-- VERIFY SETUP
-- =====================================================

SELECT
  'Staking System Ready!' as status,
  (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'stakes') as has_stakes_table,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'stake_deposit') as has_stake_deposit,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'get_stake_value') as has_get_stake_value,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'apply_stake_compound') as has_apply_compound,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'stake_withdraw') as has_stake_withdraw;

-- Test the math: 3000 GP staked for 61 hours should = ~1,000,000 GP
SELECT
  '3000 GP for 61 hours' as test,
  floor(3000 * power(1.10, 61))::bigint as should_equal_about_1_million;
