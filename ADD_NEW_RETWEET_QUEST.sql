-- Add new retweet quest for December 2024
-- Run this in Supabase SQL Editor

INSERT INTO quest_templates (
  quest_id,
  quest_name,
  description,
  quest_type,
  gc_reward,
  target_count,
  is_active,
  created_at
)
VALUES (
  'retweet_dec_2024',
  'Spread the Word',
  'Retweet our announcement on X',
  'manual',
  1000,
  1,
  true,
  NOW()
)
ON CONFLICT (quest_id)
DO UPDATE SET
  quest_name = EXCLUDED.quest_name,
  description = EXCLUDED.description,
  gc_reward = EXCLUDED.gc_reward,
  is_active = EXCLUDED.is_active;
