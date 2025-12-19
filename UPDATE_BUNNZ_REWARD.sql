-- Update BAD BUNNZ holder quest reward from 1500 to 850 GC
-- Run this in Supabase SQL Editor

UPDATE quest_templates
SET gc_reward = 850
WHERE id = 'bunnz_holder';

-- Verify the update
SELECT id, name, gc_reward
FROM quest_templates
WHERE id = 'bunnz_holder';
