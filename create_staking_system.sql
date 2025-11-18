-- =====================================================
-- SERVER-SIDE STAKING SYSTEM
-- =====================================================
-- Secure staking with continuous compound interest at 10% per hour
-- APY: Astronomical (compounding continuously at 10% hourly rate)

-- Create staking table
CREATE TABLE IF NOT EXISTS staking (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  auth_user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  principal bigint NOT NULL DEFAULT 0,
  last_compound_time timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE staking ENABLE ROW LEVEL SECURITY;

-- Users can only view their own staking
CREATE POLICY "Users can view own staking" ON staking
  FOR SELECT TO authenticated, anon
  USING (auth.uid() = auth_user_id);

-- No direct INSERT/UPDATE/DELETE - must use RPC functions
REVOKE ALL ON staking FROM authenticated, anon;
GRANT SELECT ON staking TO authenticated, anon;

-- =====================================================
-- DEPOSIT TO STAKING
-- =====================================================
CREATE OR REPLACE FUNCTION stake_deposit(
  p_amount bigint
)
RETURNS TABLE(
  success boolean,
  message text,
  new_principal bigint,
  current_value bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_user_id uuid;
  v_user_id uuid;
  v_user_balance bigint;
  v_existing_principal bigint;
  v_last_compound timestamptz;
  v_current_value bigint;
BEGIN
  -- Get authenticated user
  v_auth_user_id := auth.uid();
  IF v_auth_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated', 0::bigint, 0::bigint;
    RETURN;
  END IF;

  -- Get user ID
  SELECT id, gp_balance INTO v_user_id, v_user_balance
  FROM users
  WHERE auth_user_id = v_auth_user_id;

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'User not found', 0::bigint, 0::bigint;
    RETURN;
  END IF;

  -- Validate amount
  IF p_amount <= 0 THEN
    RETURN QUERY SELECT false, 'Amount must be positive', 0::bigint, 0::bigint;
    RETURN;
  END IF;

  IF p_amount > v_user_balance THEN
    RETURN QUERY SELECT false, 'Insufficient balance', 0::bigint, 0::bigint;
    RETURN;
  END IF;

  -- Deduct from user balance
  UPDATE users
  SET gp_balance = gp_balance - p_amount,
      updated_at = now()
  WHERE id = v_user_id;

  -- Log transaction
  INSERT INTO gp_transactions (user_id, amount, transaction_type, game_type)
  VALUES (v_user_id, -p_amount, 'stake_deposit', 'staking');

  -- Get existing stake and compound it first
  SELECT principal, last_compound_time
  INTO v_existing_principal, v_last_compound
  FROM staking
  WHERE user_id = v_user_id;

  IF FOUND THEN
    -- Calculate compound interest since last update
    v_current_value := calculate_compound_value(v_existing_principal, v_last_compound);

    -- Update existing stake
    UPDATE staking
    SET principal = v_current_value + p_amount,
        last_compound_time = now(),
        updated_at = now()
    WHERE user_id = v_user_id;

    RETURN QUERY SELECT true, 'Deposited successfully',
                        v_current_value + p_amount,
                        v_current_value + p_amount;
  ELSE
    -- Create new stake
    INSERT INTO staking (user_id, auth_user_id, principal, last_compound_time)
    VALUES (v_user_id, v_auth_user_id, p_amount, now());

    RETURN QUERY SELECT true, 'Deposited successfully', p_amount, p_amount;
  END IF;
END;
$$;

-- =====================================================
-- WITHDRAW FROM STAKING
-- =====================================================
CREATE OR REPLACE FUNCTION stake_withdraw()
RETURNS TABLE(
  success boolean,
  message text,
  amount_withdrawn bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_user_id uuid;
  v_user_id uuid;
  v_principal bigint;
  v_last_compound timestamptz;
  v_current_value bigint;
BEGIN
  -- Get authenticated user
  v_auth_user_id := auth.uid();
  IF v_auth_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated', 0::bigint;
    RETURN;
  END IF;

  -- Get user ID
  SELECT id INTO v_user_id
  FROM users
  WHERE auth_user_id = v_auth_user_id;

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'User not found', 0::bigint;
    RETURN;
  END IF;

  -- Get current stake
  SELECT principal, last_compound_time
  INTO v_principal, v_last_compound
  FROM staking
  WHERE user_id = v_user_id;

  IF NOT FOUND OR v_principal = 0 THEN
    RETURN QUERY SELECT false, 'No active stake', 0::bigint;
    RETURN;
  END IF;

  -- Calculate current value with compound interest
  v_current_value := calculate_compound_value(v_principal, v_last_compound);

  -- Add to user balance
  UPDATE users
  SET gp_balance = gp_balance + v_current_value,
      updated_at = now()
  WHERE id = v_user_id;

  -- Log transaction
  INSERT INTO gp_transactions (user_id, amount, transaction_type, game_type)
  VALUES (v_user_id, v_current_value, 'stake_withdraw', 'staking');

  -- Delete stake
  DELETE FROM staking WHERE user_id = v_user_id;

  RETURN QUERY SELECT true, 'Withdrawn successfully', v_current_value;
END;
$$;

-- =====================================================
-- GET CURRENT STAKING VALUE
-- =====================================================
CREATE OR REPLACE FUNCTION get_stake_value()
RETURNS TABLE(
  principal bigint,
  current_value bigint,
  profit bigint,
  apy numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_user_id uuid;
  v_user_id uuid;
  v_principal bigint;
  v_last_compound timestamptz;
  v_current_value bigint;
  v_apy numeric;
BEGIN
  -- Get authenticated user
  v_auth_user_id := auth.uid();
  IF v_auth_user_id IS NULL THEN
    RETURN QUERY SELECT 0::bigint, 0::bigint, 0::bigint, 0::numeric;
    RETURN;
  END IF;

  -- Get user ID
  SELECT id INTO v_user_id
  FROM users
  WHERE auth_user_id = v_auth_user_id;

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT 0::bigint, 0::bigint, 0::bigint, 0::numeric;
    RETURN;
  END IF;

  -- Get current stake
  SELECT s.principal, s.last_compound_time
  INTO v_principal, v_last_compound
  FROM staking s
  WHERE s.user_id = v_user_id;

  IF NOT FOUND OR v_principal = 0 THEN
    RETURN QUERY SELECT 0::bigint, 0::bigint, 0::bigint, 0::numeric;
    RETURN;
  END IF;

  -- Calculate current value
  v_current_value := calculate_compound_value(v_principal, v_last_compound);

  -- APY for 10% hourly compounded continuously = (1.10^8760 - 1) * 100
  -- This is an astronomical number, display as >1,000,000%
  v_apy := 99999999.99;

  RETURN QUERY SELECT
    v_principal,
    v_current_value,
    v_current_value - v_principal,
    v_apy;
END;
$$;

-- =====================================================
-- CALCULATE COMPOUND VALUE
-- =====================================================
-- Continuous compound interest at 10% per hour
-- Formula: A = P * (1.10)^(hours_elapsed)
CREATE OR REPLACE FUNCTION calculate_compound_value(
  p_principal bigint,
  p_last_compound_time timestamptz
)
RETURNS bigint
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_seconds_elapsed numeric;
  v_hours_elapsed numeric;
  v_growth_factor numeric;
  v_current_value numeric;
BEGIN
  -- Calculate time elapsed in seconds
  v_seconds_elapsed := EXTRACT(EPOCH FROM (now() - p_last_compound_time));

  -- Convert to hours (3600 seconds per hour)
  v_hours_elapsed := v_seconds_elapsed / 3600.0;

  -- Calculate growth factor: (1.10)^hours_elapsed
  -- Using: (1 + 0.10)^hours_elapsed
  v_growth_factor := power(1.10, v_hours_elapsed);

  -- Calculate current value
  v_current_value := p_principal * v_growth_factor;

  -- Return as bigint
  RETURN floor(v_current_value)::bigint;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION stake_deposit(bigint) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION stake_withdraw() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_stake_value() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION calculate_compound_value(bigint, timestamptz) TO authenticated, anon;
