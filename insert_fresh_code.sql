-- EMERGENCY CODE INSERTION
-- Use this if you need a fresh code RIGHT NOW
-- Run this in Supabase SQL Editor, then try the code below

-- Insert a fresh unused code
INSERT INTO codes (code, created_by, used_by, used_at)
VALUES ('FRESH999', null, null, null)
ON CONFLICT (code) DO NOTHING;

-- Verify it was inserted
SELECT code, used_by FROM codes WHERE code = 'FRESH999';

-- If you see FRESH999 with used_by = null, then use code: FRESH999 to register
