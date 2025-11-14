-- First, let's see what columns the codes table actually has
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'codes'
ORDER BY ordinal_position;

-- If the table has the wrong structure, let's drop and recreate it properly
DROP TABLE IF EXISTS codes CASCADE;

-- Create codes table with correct structure
CREATE TABLE codes (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  created_by uuid references users(id) on delete set null,
  used_by uuid references users(id) on delete set null,
  used_at timestamp with time zone,
  created_at timestamp with time zone default now()
);

-- Create index
CREATE INDEX IF NOT EXISTS idx_codes_code ON codes(code);
CREATE INDEX IF NOT EXISTS idx_codes_used_by ON codes(used_by);

-- Enable RLS
ALTER TABLE codes ENABLE ROW LEVEL SECURITY;

-- Create policies
DROP POLICY IF EXISTS "Codes are viewable by everyone" ON codes;
CREATE POLICY "Codes are viewable by everyone"
  ON codes FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Codes can be updated by anyone" ON codes;
CREATE POLICY "Codes can be updated by anyone"
  ON codes FOR UPDATE
  USING (true);

DROP POLICY IF EXISTS "Codes can be inserted" ON codes;
CREATE POLICY "Codes can be inserted"
  ON codes FOR INSERT
  WITH CHECK (true);

-- Now insert 20 test codes
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

-- Show the available codes
SELECT code, created_at
FROM codes
WHERE used_by IS NULL
ORDER BY created_at DESC;
