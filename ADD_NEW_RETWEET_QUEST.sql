-- Add new retweet quest for December 2024
-- Run this in Supabase SQL Editor

INSERT INTO quest_templates (
  id,
  name,
  description,
  quest_type,
  gc_reward,
  target_count,
  is_active,
  sort_order
)
VALUES (
  'retweet_dec_2024',
  'Spread the Word',
  'Retweet our discord announcement',
  'one_time',
  1000,
  1,
  true,
  4
)
ON CONFLICT (id)
DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  gc_reward = EXCLUDED.gc_reward,
  is_active = EXCLUDED.is_active;
