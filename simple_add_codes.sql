-- SIMPLE SOLUTION: Add codes to whatever table structure exists
-- This script adapts to your current table structure

-- Option 1: If your table only has 'code' column
INSERT INTO codes (code) VALUES
  ('TEST1234'),
  ('TEST5678'),
  ('DEMO1234'),
  ('DEMO5678'),
  ('ALPHA001'),
  ('ALPHA002'),
  ('BETA0001'),
  ('BETA0002'),
  ('GAMMA123'),
  ('DELTA456'),
  ('START001'),
  ('START002'),
  ('INVITE01'),
  ('INVITE02'),
  ('ACCESS01'),
  ('ACCESS02'),
  ('WELCOME1'),
  ('WELCOME2'),
  ('DUELPVP1'),
  ('DUELPVP2')
ON CONFLICT (code) DO NOTHING;

-- Check what was created
SELECT * FROM codes LIMIT 20;
