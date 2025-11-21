-- ============================================
-- ADD MEGALIO HOLDER QUEST
-- ============================================

-- Add megalio quest to quest_templates
INSERT INTO quest_templates (id, name, description, gc_reward, target_count, quest_type, auto_claim, sort_order, is_active)
VALUES
  ('megalio_holder', 'MEGALIO Holder', 'Hold a MEGALIO NFT in your wallet.', 2000, 1, 'one_time', FALSE, 8, TRUE)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  gc_reward = EXCLUDED.gc_reward,
  target_count = EXCLUDED.target_count,
  sort_order = EXCLUDED.sort_order,
  is_active = TRUE;

-- Initialize megalio quest for ALL existing users
-- Holders get it auto-completed, non-holders get it as pending
INSERT INTO user_quests (user_id, quest_id, progress, is_completed, completed_at, created_at, updated_at)
SELECT
  u.id,
  'megalio_holder',
  CASE
    WHEN EXISTS (
      SELECT 1 FROM megalio_holders m
      WHERE LOWER(m."Address") = LOWER(u.wallet_address)
    ) THEN 1
    ELSE 0
  END,
  EXISTS (
    SELECT 1 FROM megalio_holders m
    WHERE LOWER(m."Address") = LOWER(u.wallet_address)
  ),
  CASE
    WHEN EXISTS (
      SELECT 1 FROM megalio_holders m
      WHERE LOWER(m."Address") = LOWER(u.wallet_address)
    ) THEN NOW()
    ELSE NULL
  END,
  NOW(),
  NOW()
FROM users u
ON CONFLICT (user_id, quest_id) DO UPDATE SET
  progress = CASE
    WHEN EXISTS (
      SELECT 1 FROM megalio_holders m
      JOIN users u2 ON LOWER(m."Address") = LOWER(u2.wallet_address)
      WHERE u2.id = user_quests.user_id
    ) THEN 1
    ELSE user_quests.progress
  END,
  is_completed = EXISTS (
    SELECT 1 FROM megalio_holders m
    JOIN users u2 ON LOWER(m."Address") = LOWER(u2.wallet_address)
    WHERE u2.id = user_quests.user_id
  ),
  completed_at = CASE
    WHEN EXISTS (
      SELECT 1 FROM megalio_holders m
      JOIN users u2 ON LOWER(m."Address") = LOWER(u2.wallet_address)
      WHERE u2.id = user_quests.user_id
    ) THEN COALESCE(user_quests.completed_at, NOW())
    ELSE user_quests.completed_at
  END,
  updated_at = NOW();

-- Verify
SELECT
  'Megalio quest initialization complete!' as status,
  COUNT(*) as total_users,
  COUNT(CASE WHEN uq.is_completed THEN 1 END) as holders_completed
FROM users u
LEFT JOIN user_quests uq ON u.id = uq.user_id AND uq.quest_id = 'megalio_holder';
