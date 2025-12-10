-- ============================================
-- COMPLETE FIX: Games + Username-Based Referrals
-- ============================================
-- Run this entire file in Supabase SQL Editor

-- ============================================
-- PART 1: FIX GAME FUNCTIONS (gp_balance → gc_balance)
-- ============================================

CREATE OR REPLACE FUNCTION public.secure_update_gp(p_amount bigint, p_transaction_type text DEFAULT 'game'::text, p_game_type text DEFAULT NULL::text, p_reference_id uuid DEFAULT NULL::uuid)
RETURNS TABLE(new_balance bigint, success boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_user_id uuid;
  v_user_id uuid;
  v_current_balance bigint;
  v_new_balance bigint;
BEGIN
  v_auth_user_id := auth.uid();
  IF v_auth_user_id IS NULL THEN
    RETURN QUERY SELECT 0::bigint, false, 'Not authenticated';
    RETURN;
  END IF;

  SELECT id INTO v_user_id FROM users WHERE auth_user_id = v_auth_user_id;
  IF v_user_id IS NULL THEN
    SELECT id INTO v_user_id FROM users WHERE id = v_auth_user_id;
  END IF;
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT 0::bigint, false, 'User not found';
    RETURN;
  END IF;

  IF p_amount > 100000 THEN
    RETURN QUERY SELECT 0::bigint, false, 'Amount too large (max 100k per transaction)';
    RETURN;
  END IF;
  IF p_amount < -100000 THEN
    RETURN QUERY SELECT 0::bigint, false, 'Amount too negative (max -100k per transaction)';
    RETURN;
  END IF;

  SELECT gc_balance INTO v_current_balance FROM users WHERE id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT 0::bigint, false, 'User not found';
    RETURN;
  END IF;

  v_new_balance := v_current_balance + p_amount;
  IF v_new_balance < 0 THEN
    RETURN QUERY SELECT v_current_balance, false, 'Insufficient balance';
    RETURN;
  END IF;

  UPDATE users SET gc_balance = v_new_balance, updated_at = now() WHERE id = v_user_id;

  BEGIN
    INSERT INTO gc_transactions (user_id, amount, balance_before, balance_after, transaction_type, game_type, reference_id)
    VALUES (v_user_id, p_amount, v_current_balance, v_new_balance, p_transaction_type, p_game_type, p_reference_id);
  EXCEPTION WHEN undefined_table THEN
    NULL;
  END;

  RETURN QUERY SELECT v_new_balance, true, 'Balance updated';
END;
$function$;

-- ============================================

CREATE OR REPLACE FUNCTION public.update_user_gp(p_user_id uuid, p_amount bigint, p_transaction_type text DEFAULT 'general'::text, p_game_type text DEFAULT NULL::text, p_reference_id uuid DEFAULT NULL::uuid)
RETURNS TABLE(new_balance bigint, success boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_current_balance bigint;
  v_new_balance bigint;
BEGIN
  SELECT gc_balance INTO v_current_balance FROM users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT 0::bigint, false, 'User not found';
    RETURN;
  END IF;

  v_new_balance := v_current_balance + p_amount;
  IF v_new_balance < 0 THEN
    RETURN QUERY SELECT v_current_balance, false, 'Insufficient balance';
    RETURN;
  END IF;

  UPDATE users SET gc_balance = v_new_balance, updated_at = now() WHERE id = p_user_id;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'gc_transactions') THEN
    INSERT INTO gc_transactions (user_id, amount, balance_before, balance_after, transaction_type, game_type, reference_id)
    VALUES (p_user_id, p_amount, v_current_balance, v_new_balance, p_transaction_type, p_game_type, p_reference_id);
  END IF;

  RETURN QUERY SELECT v_new_balance, true, 'Balance updated';
END;
$function$;

-- ============================================

CREATE OR REPLACE FUNCTION public.update_user_gp(p_user_id uuid, p_amount bigint)
RETURNS TABLE(new_balance bigint, success boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_current_balance bigint;
  v_new_balance bigint;
BEGIN
  SELECT gc_balance INTO v_current_balance FROM users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT 0::bigint, false, 'User not found';
    RETURN;
  END IF;

  v_new_balance := v_current_balance + p_amount;
  IF v_new_balance < 0 THEN
    RETURN QUERY SELECT v_current_balance, false, 'Insufficient balance';
    RETURN;
  END IF;

  UPDATE users SET gc_balance = v_new_balance, updated_at = now() WHERE id = p_user_id;
  RETURN QUERY SELECT v_new_balance, true, 'Balance updated';
END;
$function$;

-- ============================================
-- PART 2: CREATE MINES_GAMES TABLE (if missing)
-- ============================================

CREATE TABLE IF NOT EXISTS mines_games (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  bet_amount BIGINT NOT NULL,
  mines_count INTEGER NOT NULL,
  mine_positions INTEGER[] NOT NULL,
  revealed_tiles INTEGER[] DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'active',
  payout BIGINT DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  ended_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_mines_games_user_id ON mines_games(user_id);
CREATE INDEX IF NOT EXISTS idx_mines_games_status ON mines_games(status);

-- ============================================
-- PART 3: USERNAME-BASED REFERRAL SYSTEM
-- ============================================
-- Each user's display_name IS their invite code (works unlimited times)
-- When someone uses your username as code → you get 100 GC

CREATE OR REPLACE FUNCTION public.validate_invite_code(p_code character varying)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_inviter RECORD;
BEGIN
  -- Check if p_code matches any user's display_name
  SELECT id, display_name INTO v_inviter
  FROM users
  WHERE LOWER(display_name) = LOWER(p_code);

  IF NOT FOUND THEN
    RETURN json_build_object('valid', FALSE, 'error', 'Invalid invite code (username not found)');
  END IF;

  -- Always valid (unlimited uses)
  RETURN json_build_object('valid', TRUE, 'code', v_inviter.display_name);
END;
$function$;

-- ============================================

CREATE OR REPLACE FUNCTION public.reserve_invite_code(p_code character varying, p_wallet_address character varying)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_inviter RECORD;
BEGIN
  -- Check if p_code matches any user's display_name
  SELECT id, display_name INTO v_inviter
  FROM users
  WHERE LOWER(display_name) = LOWER(p_code);

  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Invalid invite code (username not found)');
  END IF;

  -- No actual reservation needed (unlimited uses)
  RETURN json_build_object('success', TRUE, 'reserved_until', NOW() + INTERVAL '5 minutes');
END;
$function$;

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

    -- Prevent self-referral
    IF LOWER(p_invite_code) = LOWER(p_display_name) THEN
      RETURN json_build_object('success', FALSE, 'error', 'Cannot use your own username as invite code');
    END IF;
  END IF;

  -- Check NFT holdings
  v_nft_holdings := check_nft_holdings(p_wallet_address);

  -- Create user with 0 GC
  INSERT INTO users (wallet_address, display_name, email, gc_balance)
  VALUES (LOWER(p_wallet_address), p_display_name, p_email, v_initial_gc)
  RETURNING id INTO v_user_id;

  -- Reward inviter with 100 GC (unlimited uses - every signup counts)
  IF v_inviter_id IS NOT NULL THEN
    UPDATE users
    SET gc_balance = gc_balance + 100,
        updated_at = NOW()
    WHERE id = v_inviter_id;

    -- Log the referral reward transaction
    INSERT INTO gc_transactions (
      user_id,
      amount,
      balance_after,
      transaction_type,
      reference_id,
      description
    ) VALUES (
      v_inviter_id,
      100,
      (SELECT gc_balance FROM users WHERE id = v_inviter_id),
      'referral_reward',
      v_user_id,
      'Referral reward for inviting ' || p_display_name
    );

    -- Update inviter's quest progress
    INSERT INTO user_quests (user_id, quest_id, progress)
    VALUES (v_inviter_id, 'invite_3_friends', 1)
    ON CONFLICT (user_id, quest_id) DO UPDATE
    SET progress = user_quests.progress + 1,
        is_completed = (user_quests.progress + 1 >= 3),
        completed_at = CASE WHEN user_quests.progress + 1 >= 3 THEN NOW() ELSE NULL END,
        updated_at = NOW();
  END IF;

  -- Initialize quests for user (auto-complete first_steps but do NOT auto-claim)
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

  -- Return success with user info
  RETURN json_build_object(
    'success', TRUE,
    'user_id', v_user_id,
    'has_fluffle', (v_nft_holdings->>'has_fluffle')::boolean,
    'has_bunnz', (v_nft_holdings->>'has_bunnz')::boolean
  );
END;
$function$;

-- ============================================
-- PART 4: UPDATE get_user_invite_codes
-- ============================================
-- Returns the user's own username as their invite code

CREATE OR REPLACE FUNCTION public.get_user_invite_codes(p_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_display_name TEXT;
  v_referral_count INTEGER;
BEGIN
  -- Get user's display name
  SELECT display_name INTO v_display_name
  FROM users
  WHERE id = p_user_id;

  IF v_display_name IS NULL THEN
    RETURN json_build_object('code', NULL, 'uses', 0);
  END IF;

  -- Count how many people used this username as invite code
  SELECT COUNT(*) INTO v_referral_count
  FROM gc_transactions
  WHERE user_id = p_user_id
    AND transaction_type = 'referral_reward';

  -- Return username as the invite code
  RETURN json_build_object(
    'code', v_display_name,
    'uses', v_referral_count,
    'unlimited', true
  );
END;
$function$;

-- ============================================
-- VERIFICATION
-- ============================================

-- Check if everything is working:
-- SELECT * FROM information_schema.tables WHERE table_name = 'mines_games';
-- SELECT routine_name FROM information_schema.routines WHERE routine_name IN ('validate_invite_code', 'register_user_with_wallet');
