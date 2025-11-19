-- Quest Claim Reward Function
-- Run this in Supabase SQL Editor

-- Function to claim quest reward
CREATE OR REPLACE FUNCTION claim_quest_reward(
  p_user_id UUID,
  p_quest_id TEXT,
  p_reward_points INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_quest_completed BOOLEAN;
BEGIN
  -- Check if quest is completed and not claimed
  SELECT (progress >= 1 AND claimed_at IS NULL) INTO v_quest_completed
  FROM quests
  WHERE user_id = p_user_id
    AND quest_id = p_quest_id
    AND reset_date = CURRENT_DATE;

  IF NOT FOUND OR NOT v_quest_completed THEN
    RETURN FALSE;
  END IF;

  -- Mark as claimed
  UPDATE quests
  SET claimed_at = NOW()
  WHERE user_id = p_user_id
    AND quest_id = p_quest_id
    AND reset_date = CURRENT_DATE;

  -- Add GP reward to user
  UPDATE users
  SET gp = COALESCE(gp, 0) + p_reward_points
  WHERE id = p_user_id;

  RETURN TRUE;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION claim_quest_reward(UUID, TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION claim_quest_reward(UUID, TEXT, INTEGER) TO anon;
