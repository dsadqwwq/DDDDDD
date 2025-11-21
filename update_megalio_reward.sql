-- ============================================
-- UPDATE MEGALIO QUEST REWARD TO 2000 GC
-- ============================================

UPDATE quest_templates
SET gc_reward = 2000
WHERE id = 'megalio_holder';

-- Verify
SELECT
  'Megalio reward updated!' as status,
  id,
  name,
  gc_reward
FROM quest_templates
WHERE id = 'megalio_holder';
