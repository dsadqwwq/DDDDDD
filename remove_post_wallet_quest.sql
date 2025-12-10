-- Remove the 'post_wallet' quest from the database
DELETE FROM user_quest_progress WHERE quest_id = 'post_wallet';
DELETE FROM quest_templates WHERE id = 'post_wallet';
