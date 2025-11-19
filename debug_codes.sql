-- DIAGNOSTIC QUERIES - Run these in Supabase SQL Editor
-- Copy each query one at a time to see what's happening

-- 1. Check if codes table exists
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'codes';
-- Expected: Should show "codes"

-- 2. Check if any codes exist at all
SELECT COUNT(*) as total_codes FROM codes;
-- Expected: Should show a number > 0

-- 3. Check unused codes
SELECT code, created_at, used_by
FROM codes
WHERE used_by IS NULL
ORDER BY created_at DESC;
-- Expected: Should show list of unused codes

-- 4. Check all codes (including used ones)
SELECT code, created_by, used_by, used_at
FROM codes
ORDER BY created_at DESC
LIMIT 20;
-- Shows all codes with their status

-- 5. Check if TEST1234 specifically exists
SELECT * FROM codes WHERE code = 'TEST1234';
-- Should show the TEST1234 code if it exists

-- 6. Check if 1440A873 exists
SELECT * FROM codes WHERE code = '1440A873';
-- Should show this code if it exists
