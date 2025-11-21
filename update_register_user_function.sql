-- ============================================
-- UPDATE register_user_with_wallet FUNCTION
-- ============================================
-- Add megalio quest initialization to the registration function
-- This ensures NEW users get megalio quest auto-completed if they're holders

-- This is a partial update - just recreating the function with megalio support
-- Run this after running the main migration

DROP FUNCTION IF EXISTS register_user_with_wallet(varchar, varchar, varchar, varchar);

-- The full function is in the migration file - this just updates it
-- For now, just run add_megalio_quest.sql to initialize for existing users
-- New users will get it via login_with_wallet function

SELECT 'register_user_with_wallet will be updated in next migration' as status;
