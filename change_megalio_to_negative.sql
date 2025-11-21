-- ============================================
-- UPDATE MEGALIO QUEST REWARD TO -500 GC
-- ============================================

UPDATE quest_templates
SET gc_reward = -500
WHERE id = 'megalio_holder';

-- Verify
SELECT
  'Megalio reward changed to -500 GC!' as status,
  id,
  name,
  gc_reward
FROM quest_templates
WHERE id = 'megalio_holder';
