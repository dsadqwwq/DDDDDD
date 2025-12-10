-- ============================================
-- DAILY LOGIN QUEST + REFERRAL FIXES + NFT SECURITY
-- ============================================

-- ============================================
-- PART 1: ADD DAILY LOGIN QUEST TEMPLATE
-- ============================================

-- Add daily login quest (if not exists)
INSERT INTO quest_templates (id, name, description, gc_reward, target_count, sort_order, is_active)
VALUES (
  'daily_login',
  'Daily Login',
  'Log in once per day to claim your reward',
  500,
  1,
  1,
  true
)
ON CONFLICT (id) DO UPDATE
SET gc_reward = 500,
    description = 'Log in once per day to claim your reward',
    is_active = true;

-- ============================================
-- PART 2: DAILY LOGIN CLAIM FUNCTION
-- ============================================
-- Resets at midnight UTC (change timezone if needed)

CREATE OR REPLACE FUNCTION public.claim_daily_login(p_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_last_claim_date DATE;
  v_today_date DATE;
  v_new_balance BIGINT;
  v_auth_user_id UUID;
  v_user_auth_id UUID;
BEGIN
  -- SECURITY: Verify user owns this account
  v_auth_user_id := auth.uid();
  IF v_auth_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Not authenticated');
  END IF;

  SELECT auth_user_id INTO v_user_auth_id FROM users WHERE id = p_user_id;
  IF v_user_auth_id != v_auth_user_id THEN
    RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  -- Get today's date in UTC (change to your timezone if needed, e.g., 'America/New_York')
  v_today_date := CURRENT_DATE AT TIME ZONE 'UTC';

  -- Get last claim date from user_quests
  SELECT DATE(claimed_at AT TIME ZONE 'UTC') INTO v_last_claim_date
  FROM user_quests
  WHERE user_id = p_user_id
    AND quest_id = 'daily_login'
    AND is_claimed = TRUE
  ORDER BY claimed_at DESC
  LIMIT 1;

  -- Check if already claimed today
  IF v_last_claim_date = v_today_date THEN
    RETURN json_build_object('success', FALSE, 'error', 'Already claimed today');
  END IF;

  -- Update quest progress and mark as claimed
  INSERT INTO user_quests (user_id, quest_id, progress, is_completed, completed_at, is_claimed, claimed_at)
  VALUES (p_user_id, 'daily_login', 1, TRUE, NOW(), TRUE, NOW())
  ON CONFLICT (user_id, quest_id) DO UPDATE
  SET progress = 1,
      is_completed = TRUE,
      completed_at = NOW(),
      is_claimed = TRUE,
      claimed_at = NOW(),
      updated_at = NOW();

  -- Give reward
  UPDATE users
  SET gc_balance = gc_balance + 500,
      updated_at = NOW()
  WHERE id = p_user_id
  RETURNING gc_balance INTO v_new_balance;

  -- Log transaction
  INSERT INTO gc_transactions (user_id, amount, balance_after, transaction_type, reference_id, description)
  VALUES (p_user_id, 500, v_new_balance, 'quest_reward', 'daily_login', 'Daily login reward');

  RETURN json_build_object('success', TRUE, 'reward', 500, 'new_balance', v_new_balance);
END;
$function$;

GRANT EXECUTE ON FUNCTION claim_daily_login TO authenticated, anon;

-- ============================================
-- PART 3: TRACK TOTAL QUESTS COMPLETED (for referral requirement)
-- ============================================

-- Add column to track total quests completed by user
ALTER TABLE users
ADD COLUMN IF NOT EXISTS total_quests_completed INTEGER DEFAULT 0;

-- Function to increment quest count and check for referral reward
CREATE OR REPLACE FUNCTION public.increment_quest_count_and_check_referral(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_quest_count INTEGER;
  v_referrer_id UUID;
  v_already_rewarded BOOLEAN;
BEGIN
  -- Increment total quests completed
  UPDATE users
  SET total_quests_completed = total_quests_completed + 1
  WHERE id = p_user_id
  RETURNING total_quests_completed INTO v_quest_count;

  -- If user just completed their 5th quest, give referrer their reward
  IF v_quest_count = 5 THEN
    -- Find who referred this user (from gc_transactions)
    SELECT user_id, (metadata->>'referral_rewarded')::boolean INTO v_referrer_id, v_already_rewarded
    FROM gc_transactions
    WHERE reference_id::text = p_user_id::text
      AND transaction_type = 'referral_pending'
    LIMIT 1;

    -- If referrer exists and hasn't been rewarded yet
    IF v_referrer_id IS NOT NULL AND (v_already_rewarded IS NULL OR v_already_rewarded = FALSE) THEN
      -- Give referrer 500 GC
      UPDATE users
      SET gc_balance = gc_balance + 500,
          updated_at = NOW()
      WHERE id = v_referrer_id;

      -- Log the reward
      INSERT INTO gc_transactions (
        user_id,
        amount,
        balance_after,
        transaction_type,
        reference_id,
        description
      ) VALUES (
        v_referrer_id,
        500,
        (SELECT gc_balance FROM users WHERE id = v_referrer_id),
        'referral_reward',
        p_user_id,
        'Referral completed 5 quests'
      );

      -- Mark original transaction as rewarded
      UPDATE gc_transactions
      SET metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{referral_rewarded}', 'true')
      WHERE reference_id::text = p_user_id::text
        AND transaction_type = 'referral_pending';
    END IF;
  END IF;
END;
$function$;

-- Update claim_quest_reward to increment count
CREATE OR REPLACE FUNCTION public.claim_quest_reward(p_user_id uuid, p_quest_id character varying)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_quest RECORD;
  v_user_quest RECORD;
  v_new_balance BIGINT;
  v_auth_user_id UUID;
  v_user_auth_id UUID;
BEGIN
  -- SECURITY: Verify user owns this account
  v_auth_user_id := auth.uid();
  IF v_auth_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Not authenticated');
  END IF;

  SELECT auth_user_id INTO v_user_auth_id FROM users WHERE id = p_user_id;
  IF v_user_auth_id != v_auth_user_id THEN
    RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  -- Get quest template
  SELECT * INTO v_quest FROM quest_templates WHERE id = p_quest_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Quest not found');
  END IF;

  -- Get user's quest progress
  SELECT * INTO v_user_quest FROM user_quests
  WHERE user_id = p_user_id AND quest_id = p_quest_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Quest not started');
  END IF;

  IF v_user_quest.is_claimed THEN
    RETURN json_build_object('success', FALSE, 'error', 'Quest already claimed');
  END IF;

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

  -- Increment quest count and check for referral reward (skip for daily_login)
  IF p_quest_id != 'daily_login' THEN
    PERFORM increment_quest_count_and_check_referral(p_user_id);
  END IF;

  RETURN json_build_object('success', TRUE, 'reward', v_quest.gc_reward, 'new_balance', v_new_balance);
END;
$function$;

-- ============================================
-- PART 4: UPDATE REGISTRATION - PENDING REFERRAL REWARD
-- ============================================

CREATE OR REPLACE FUNCTION public.register_user_with_wallet(
  p_wallet_address character varying,
  p_display_name character varying,
  p_email character varying DEFAULT NULL::character varying,
  p_invite_code character varying DEFAULT NULL::character varying
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_user_id UUID;
  v_inviter_id UUID;
  v_nft_holdings JSON;
  v_initial_gc BIGINT := 0;
BEGIN
  -- Check if wallet already registered
  IF EXISTS (SELECT 1 FROM users WHERE LOWER(wallet_address) = LOWER(p_wallet_address)) THEN
    RETURN json_build_object('success', FALSE, 'error', 'Wallet already registered');
  END IF;

  -- Check if display name taken
  IF EXISTS (SELECT 1 FROM users WHERE LOWER(display_name) = LOWER(p_display_name)) THEN
    RETURN json_build_object('success', FALSE, 'error', 'Display name already taken');
  END IF;

  -- Validate invite code (must match existing username)
  IF p_invite_code IS NOT NULL THEN
    SELECT id INTO v_inviter_id
    FROM users
    WHERE LOWER(display_name) = LOWER(p_invite_code);

    IF v_inviter_id IS NULL THEN
      RETURN json_build_object('success', FALSE, 'error', 'Invalid invite code (username not found)');
    END IF;

    IF LOWER(p_invite_code) = LOWER(p_display_name) THEN
      RETURN json_build_object('success', FALSE, 'error', 'Cannot use your own username as invite code');
    END IF;
  END IF;

  -- SECURITY: Check NFT holdings ONLY for the wallet they're registering with
  v_nft_holdings := check_nft_holdings(p_wallet_address);

  -- Create user with 0 GC
  INSERT INTO users (wallet_address, display_name, email, gc_balance, total_quests_completed)
  VALUES (LOWER(p_wallet_address), p_display_name, p_email, v_initial_gc, 0)
  RETURNING id INTO v_user_id;

  -- Create PENDING referral reward (will be given after 5 quests)
  IF v_inviter_id IS NOT NULL THEN
    INSERT INTO gc_transactions (
      user_id,
      amount,
      balance_after,
      transaction_type,
      reference_id,
      description,
      metadata
    ) VALUES (
      v_inviter_id,
      0, -- No reward yet
      (SELECT gc_balance FROM users WHERE id = v_inviter_id),
      'referral_pending',
      v_user_id,
      'Pending: ' || p_display_name || ' must complete 5 quests',
      jsonb_build_object('referral_rewarded', false, 'referred_user', v_user_id)
    );
  END IF;

  -- Initialize quests for user
  INSERT INTO user_quests (user_id, quest_id, progress, is_completed, completed_at)
  SELECT v_user_id, qt.id,
         CASE
           WHEN qt.id = 'first_steps' THEN 1
           WHEN qt.id = 'daily_login' THEN 1
           WHEN qt.id = 'fluffle_holder' AND (v_nft_holdings->>'has_fluffle')::boolean THEN 1
           WHEN qt.id = 'bunnz_holder' AND (v_nft_holdings->>'has_bunnz')::boolean THEN 1
           ELSE 0
         END,
         CASE
           WHEN qt.id = 'first_steps' THEN TRUE
           WHEN qt.id = 'daily_login' THEN TRUE
           WHEN qt.id = 'fluffle_holder' AND (v_nft_holdings->>'has_fluffle')::boolean THEN TRUE
           WHEN qt.id = 'bunnz_holder' AND (v_nft_holdings->>'has_bunnz')::boolean THEN TRUE
           ELSE FALSE
         END,
         CASE
           WHEN qt.id = 'first_steps' THEN NOW()
           WHEN qt.id = 'daily_login' THEN NOW()
           WHEN qt.id = 'fluffle_holder' AND (v_nft_holdings->>'has_fluffle')::boolean THEN NOW()
           WHEN qt.id = 'bunnz_holder' AND (v_nft_holdings->>'has_bunnz')::boolean THEN NOW()
           ELSE NULL
         END
  FROM quest_templates qt
  WHERE qt.is_active = TRUE;

  RETURN json_build_object(
    'success', TRUE,
    'user_id', v_user_id,
    'has_fluffle', (v_nft_holdings->>'has_fluffle')::boolean,
    'has_bunnz', (v_nft_holdings->>'has_bunnz')::boolean
  );
END;
$function$;

-- ============================================
-- PART 5: SECURE NFT HOLDER CHECKS (login)
-- ============================================

CREATE OR REPLACE FUNCTION public.login_with_wallet(p_wallet_address character varying)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_user RECORD;
  v_nft_holdings JSON;
BEGIN
  SELECT * INTO v_user FROM users u WHERE LOWER(u.wallet_address) = LOWER(p_wallet_address);

  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Wallet not registered');
  END IF;

  -- SECURITY: Only check NFT holdings for THEIR wallet
  v_nft_holdings := check_nft_holdings(p_wallet_address);

  -- Update NFT holder quests if they now hold NFTs
  IF (v_nft_holdings->>'has_fluffle')::boolean THEN
    UPDATE user_quests SET progress = 1, is_completed = TRUE, completed_at = COALESCE(completed_at, NOW()), updated_at = NOW()
    WHERE user_id = v_user.id AND quest_id = 'fluffle_holder' AND NOT is_completed;
  END IF;

  IF (v_nft_holdings->>'has_bunnz')::boolean THEN
    UPDATE user_quests SET progress = 1, is_completed = TRUE, completed_at = COALESCE(completed_at, NOW()), updated_at = NOW()
    WHERE user_id = v_user.id AND quest_id = 'bunnz_holder' AND NOT is_completed;
  END IF;

  IF (v_nft_holdings->>'has_megalio')::boolean THEN
    UPDATE user_quests SET progress = 1, is_completed = TRUE, completed_at = COALESCE(completed_at, NOW()), updated_at = NOW()
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
$function$;

-- ============================================
-- VERIFICATION
-- ============================================

-- Check that daily_login quest exists
SELECT * FROM quest_templates WHERE id = 'daily_login';

-- Check that total_quests_completed column was added
SELECT column_name FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'total_quests_completed';
