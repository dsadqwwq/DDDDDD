-- ============================================
-- UPDATE QUEST SYSTEM
-- ============================================
-- Run this in Supabase SQL Editor

-- 1. Add the new retweet quest (1000 GC)
INSERT INTO quests (id, name, description, gc_reward, quest_type, is_active, target_count)
VALUES (
  'retweet_jan_2025',
  'Retweet & Earn',
  'Retweet our latest post on X',
  1000,
  'manual',
  true,
  1
)
ON CONFLICT (id) DO UPDATE
SET gc_reward = 1000, is_active = true;

-- 2. Disable old quests (keeps them for users who completed them)
UPDATE quests SET is_active = false
WHERE id IN ('invite_used', 'like_retweet', 'bunnz_holder', 'fluffle_holder', 'megalio_holder');

-- 3. Verify active quests
SELECT id, name, gc_reward, is_active, quest_type
FROM quests
ORDER BY is_active DESC, gc_reward DESC;
