-- ============================================
-- ADD MEGALIO HOLDER QUEST
-- ============================================

-- Add megalio quest to quest_templates
INSERT INTO quest_templates (id, name, description, gc_reward, target_count, quest_type, auto_claim, sort_order)
VALUES
  ('megalio_holder', 'MEGALIO Holder', 'Hold a MEGALIO NFT in your wallet.', 3000, 1, 'one_time', FALSE, 8)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  gc_reward = EXCLUDED.gc_reward,
  target_count = EXCLUDED.target_count,
  sort_order = EXCLUDED.sort_order;

-- Initialize megalio quest for existing users who hold it
INSERT INTO user_quests (user_id, quest_id, progress, is_completed, completed_at)
SELECT
  u.id,
  'megalio_holder',
  1,
  TRUE,
  NOW()
FROM users u
WHERE EXISTS (
  SELECT 1 FROM megalio_holders
  WHERE LOWER("Address") = LOWER(u.wallet_address)
)
ON CONFLICT (user_id, quest_id) DO UPDATE SET
  progress = 1,
  is_completed = TRUE,
  completed_at = COALESCE(user_quests.completed_at, NOW());

-- Verify
SELECT 'Megalio quest added!' as status;
