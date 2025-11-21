-- ============================================
-- COMPLETE MEGALIO QUEST FOR SPECIFIC USER
-- ============================================
-- This manually completes the megalio quest for the wallet holder

-- Complete the quest for the specific wallet
INSERT INTO user_quests (user_id, quest_id, progress, is_completed, completed_at, created_at, updated_at)
SELECT
  u.id,
  'megalio_holder',
  1,
  TRUE,
  NOW(),
  NOW(),
  NOW()
FROM users u
WHERE LOWER(u.wallet_address) = LOWER('0x8eb8e0ffd835cf37cff5d55b768708dd1c8f9e70')
ON CONFLICT (user_id, quest_id) DO UPDATE SET
  progress = 1,
  is_completed = TRUE,
  completed_at = COALESCE(user_quests.completed_at, NOW()),
  updated_at = NOW();

-- Verify it worked
SELECT
  'Quest Status' as check,
  u.display_name,
  u.wallet_address,
  uq.quest_id,
  uq.progress,
  uq.is_completed,
  uq.is_claimed
FROM users u
LEFT JOIN user_quests uq ON u.id = uq.user_id AND uq.quest_id = 'megalio_holder'
WHERE LOWER(u.wallet_address) = LOWER('0x8eb8e0ffd835cf37cff5d55b768708dd1c8f9e70');
