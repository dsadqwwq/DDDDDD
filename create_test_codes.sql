-- Quick script to create 20 test invite codes
-- Run this in Supabase SQL Editor if you need codes immediately
-- https://supabase.com/dashboard/project/smgqccnggmyreacjyyil/editor

-- Create 20 easy-to-remember test codes
INSERT INTO codes (code, created_by, used_by) VALUES
  ('TEST1234', null, null),
  ('TEST5678', null, null),
  ('DEMO1234', null, null),
  ('DEMO5678', null, null),
  ('ALPHA001', null, null),
  ('ALPHA002', null, null),
  ('BETA0001', null, null),
  ('BETA0002', null, null),
  ('GAMMA123', null, null),
  ('DELTA456', null, null),
  ('START001', null, null),
  ('START002', null, null),
  ('INVITE01', null, null),
  ('INVITE02', null, null),
  ('ACCESS01', null, null),
  ('ACCESS02', null, null),
  ('WELCOME1', null, null),
  ('WELCOME2', null, null),
  ('DUELPVP1', null, null),
  ('DUELPVP2', null, null)
ON CONFLICT (code) DO NOTHING;

-- View the codes that were just created
SELECT code, created_at
FROM codes
WHERE used_by IS NULL
ORDER BY created_at DESC
LIMIT 20;
