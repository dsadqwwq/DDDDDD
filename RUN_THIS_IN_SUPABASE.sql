-- ============================================
-- STEP 1: ADD MISSING COLUMNS
-- ============================================

ALTER TABLE gc_transactions
ADD COLUMN IF NOT EXISTS balance_before BIGINT,
ADD COLUMN IF NOT EXISTS game_type TEXT,
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

ALTER TABLE users
ADD COLUMN IF NOT EXISTS total_quests_completed INTEGER DEFAULT 0;

-- ============================================
-- STEP 2: ADD DAILY LOGIN QUEST
-- ============================================

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
-- STEP 3: DAILY LOGIN CLAIM FUNCTION
-- ============================================

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
  v_auth_user_id := auth.uid();
  IF v_auth_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Not authenticated');
  END IF;

  SELECT auth_user_id INTO v_user_auth_id FROM users WHERE id = p_user_id;
  IF v_user_auth_id != v_auth_user_id THEN
    RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  v_today_date := CURRENT_DATE AT TIME ZONE 'UTC';

  SELECT DATE(claimed_at AT TIME ZONE 'UTC') INTO v_last_claim_date
  FROM user_quests
  WHERE user_id = p_user_id AND quest_id = 'daily_login' AND is_claimed = TRUE
  ORDER BY claimed_at DESC LIMIT 1;

  IF v_last_claim_date = v_today_date THEN
    RETURN json_build_object('success', FALSE, 'error', 'Already claimed today');
  END IF;

  INSERT INTO user_quests (user_id, quest_id, progress, is_completed, completed_at, is_claimed, claimed_at)
  VALUES (p_user_id, 'daily_login', 1, TRUE, NOW(), TRUE, NOW())
  ON CONFLICT (user_id, quest_id) DO UPDATE
  SET progress = 1, is_completed = TRUE, completed_at = NOW(), is_claimed = TRUE, claimed_at = NOW(), updated_at = NOW();

  UPDATE users SET gc_balance = gc_balance + 500, updated_at = NOW()
  WHERE id = p_user_id RETURNING gc_balance INTO v_new_balance;

  INSERT INTO gc_transactions (user_id, amount, balance_after, transaction_type, reference_id, description)
  VALUES (p_user_id, 500, v_new_balance, 'quest_reward', 'daily_login', 'Daily login reward');

  RETURN json_build_object('success', TRUE, 'reward', 500, 'new_balance', v_new_balance);
END;
$function$;

GRANT EXECUTE ON FUNCTION claim_daily_login TO authenticated, anon;

-- ============================================
-- STEP 4: REFERRAL TRACKING (500 GC after 5 quests)
-- ============================================

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
  UPDATE users SET total_quests_completed = total_quests_completed + 1
  WHERE id = p_user_id RETURNING total_quests_completed INTO v_quest_count;

  IF v_quest_count = 5 THEN
    SELECT user_id, (metadata->>'referral_rewarded')::boolean INTO v_referrer_id, v_already_rewarded
    FROM gc_transactions
    WHERE reference_id::text = p_user_id::text AND transaction_type = 'referral_pending'
    LIMIT 1;

    IF v_referrer_id IS NOT NULL AND (v_already_rewarded IS NULL OR v_already_rewarded = FALSE) THEN
      UPDATE users SET gc_balance = gc_balance + 500, updated_at = NOW() WHERE id = v_referrer_id;

      INSERT INTO gc_transactions (user_id, amount, balance_after, transaction_type, reference_id, description)
      VALUES (
        v_referrer_id,
        500,
        (SELECT gc_balance FROM users WHERE id = v_referrer_id),
        'referral_reward',
        p_user_id,
        'Referral completed 5 quests'
      );

      UPDATE gc_transactions
      SET metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{referral_rewarded}', 'true')
      WHERE reference_id::text = p_user_id::text AND transaction_type = 'referral_pending';
    END IF;
  END IF;
END;
$function$;

-- ============================================
-- STEP 5: UPDATE CLAIM FUNCTION
-- ============================================

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
  v_auth_user_id := auth.uid();
  IF v_auth_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Not authenticated');
  END IF;

  SELECT auth_user_id INTO v_user_auth_id FROM users WHERE id = p_user_id;
  IF v_user_auth_id != v_auth_user_id THEN
    RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_quest FROM quest_templates WHERE id = p_quest_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Quest not found');
  END IF;

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

  UPDATE users SET gc_balance = gc_balance + v_quest.gc_reward, updated_at = NOW()
  WHERE id = p_user_id RETURNING gc_balance INTO v_new_balance;

  UPDATE user_quests SET is_claimed = TRUE, claimed_at = NOW(), updated_at = NOW()
  WHERE user_id = p_user_id AND quest_id = p_quest_id;

  INSERT INTO gc_transactions (user_id, amount, balance_after, transaction_type, reference_id, description)
  VALUES (p_user_id, v_quest.gc_reward, v_new_balance, 'quest_reward', p_quest_id, 'Quest reward: ' || v_quest.name);

  IF p_quest_id != 'daily_login' THEN
    PERFORM increment_quest_count_and_check_referral(p_user_id);
  END IF;

  RETURN json_build_object('success', TRUE, 'reward', v_quest.gc_reward, 'new_balance', v_new_balance);
END;
$function$;

-- ============================================
-- STEP 6: UPDATE REGISTRATION (referral = username, optional, 500 GC after 5 quests)
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
  IF EXISTS (SELECT 1 FROM users WHERE LOWER(wallet_address) = LOWER(p_wallet_address)) THEN
    RETURN json_build_object('success', FALSE, 'error', 'Wallet already registered');
  END IF;

  IF EXISTS (SELECT 1 FROM users WHERE LOWER(display_name) = LOWER(p_display_name)) THEN
    RETURN json_build_object('success', FALSE, 'error', 'Display name already taken');
  END IF;

  IF p_invite_code IS NOT NULL THEN
    SELECT id INTO v_inviter_id FROM users WHERE LOWER(display_name) = LOWER(p_invite_code);

    IF v_inviter_id IS NULL THEN
      RETURN json_build_object('success', FALSE, 'error', 'Invalid invite code (username not found)');
    END IF;

    IF LOWER(p_invite_code) = LOWER(p_display_name) THEN
      RETURN json_build_object('success', FALSE, 'error', 'Cannot use your own username as invite code');
    END IF;
  END IF;

  v_nft_holdings := check_nft_holdings(p_wallet_address);

  INSERT INTO users (wallet_address, display_name, email, gc_balance, total_quests_completed)
  VALUES (LOWER(p_wallet_address), p_display_name, p_email, v_initial_gc, 0)
  RETURNING id INTO v_user_id;

  IF v_inviter_id IS NOT NULL THEN
    INSERT INTO gc_transactions (user_id, amount, balance_after, transaction_type, reference_id, description, metadata)
    VALUES (
      v_inviter_id,
      0,
      (SELECT gc_balance FROM users WHERE id = v_inviter_id),
      'referral_pending',
      v_user_id,
      'Pending: ' || p_display_name || ' must complete 5 quests',
      jsonb_build_object('referral_rewarded', false, 'referred_user', v_user_id)
    );
  END IF;

  INSERT INTO user_quests (user_id, quest_id, progress, is_completed, completed_at)
  SELECT v_user_id, qt.id,
         CASE
           WHEN qt.id = 'first_steps' THEN 1
           WHEN qt.id = 'fluffle_holder' AND (v_nft_holdings->>'has_fluffle')::boolean THEN 1
           WHEN qt.id = 'bunnz_holder' AND (v_nft_holdings->>'has_bunnz')::boolean THEN 1
           ELSE 0
         END,
         CASE
           WHEN qt.id = 'first_steps' THEN TRUE
           WHEN qt.id = 'fluffle_holder' AND (v_nft_holdings->>'has_fluffle')::boolean THEN TRUE
           WHEN qt.id = 'bunnz_holder' AND (v_nft_holdings->>'has_bunnz')::boolean THEN TRUE
           ELSE FALSE
         END,
         CASE
           WHEN qt.id = 'first_steps' THEN NOW()
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
