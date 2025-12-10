-- ============================================
-- ADD MISSING COLUMNS TO USERS TABLE
-- ============================================
-- Run this in Supabase SQL Editor to fix the errors

-- Add win_streak column (tracks consecutive wins)
ALTER TABLE users
ADD COLUMN IF NOT EXISTS win_streak INTEGER DEFAULT 0;

-- Add total_wins column (tracks total game wins)
ALTER TABLE users
ADD COLUMN IF NOT EXISTS total_wins INTEGER DEFAULT 0;

-- Verify columns were added
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'users'
AND column_name IN ('win_streak', 'total_wins', 'gc_balance');
