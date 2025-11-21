-- ============================================
-- REMOVE MEGALIO QUEST FROM VISIBILITY
-- ============================================

-- Option 1: Deactivate the quest (keeps data, just hides it)
UPDATE quest_templates
SET is_active = FALSE
WHERE id = 'megalio_holder';

-- Option 2: Delete all megalio quest data completely (uncomment if you want full removal)
-- DELETE FROM user_quests WHERE quest_id = 'megalio_holder';
-- DELETE FROM quest_templates WHERE id = 'megalio_holder';

-- Verify it's hidden
SELECT
  'Megalio quest hidden!' as status,
  id,
  name,
  is_active
FROM quest_templates
WHERE id = 'megalio_holder';
