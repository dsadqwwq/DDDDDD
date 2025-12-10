-- ============================================
-- MAKE DAILY LOGIN CLAIMABLE IMMEDIATELY FOR NEW USERS
-- ============================================

-- Update the registration function to mark daily_login as completed (but not claimed) for new users
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
           WHEN qt.id = 'daily_login' THEN 1  -- NEW: Mark daily login as ready to claim
           WHEN qt.id = 'fluffle_holder' AND (v_nft_holdings->>'has_fluffle')::boolean THEN 1
           WHEN qt.id = 'bunnz_holder' AND (v_nft_holdings->>'has_bunnz')::boolean THEN 1
           ELSE 0
         END,
         CASE
           WHEN qt.id = 'first_steps' THEN TRUE
           WHEN qt.id = 'daily_login' THEN TRUE  -- NEW: Mark daily login as completed (ready to claim)
           WHEN qt.id = 'fluffle_holder' AND (v_nft_holdings->>'has_fluffle')::boolean THEN TRUE
           WHEN qt.id = 'bunnz_holder' AND (v_nft_holdings->>'has_bunnz')::boolean THEN TRUE
           ELSE FALSE
         END,
         CASE
           WHEN qt.id = 'first_steps' THEN NOW()
           WHEN qt.id = 'daily_login' THEN NOW()  -- NEW: Set completed_at for daily login
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
