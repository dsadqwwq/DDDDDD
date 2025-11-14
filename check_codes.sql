-- Run this query in Supabase SQL Editor to see all available invite codes
-- https://supabase.com/dashboard/project/smgqccnggmyreacjyyil/editor

-- Check if codes table exists
SELECT EXISTS (
  SELECT FROM information_schema.tables
  WHERE table_name = 'codes'
) as codes_table_exists;

-- View all available (unused) invite codes
SELECT
  code,
  created_by,
  used_by,
  created_at
FROM codes
WHERE used_by IS NULL
ORDER BY created_at DESC;

-- View all codes (including used ones)
SELECT
  code,
  created_by,
  used_by,
  used_at,
  created_at
FROM codes
ORDER BY created_at DESC;

-- Count total codes
SELECT
  COUNT(*) FILTER (WHERE used_by IS NULL) as available_codes,
  COUNT(*) FILTER (WHERE used_by IS NOT NULL) as used_codes,
  COUNT(*) as total_codes
FROM codes;
