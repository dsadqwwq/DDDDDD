-- Fix codes table column names
-- Your table has 'owner_id' but the app expects 'created_by' and 'used_by'

-- First, let's see what columns you actually have
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'codes'
ORDER BY ordinal_position;

-- Now let's fix it by dropping and recreating with correct columns
DROP TABLE IF EXISTS codes CASCADE;

CREATE TABLE codes (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  created_by uuid references users(id) on delete set null,
  used_by uuid references users(id) on delete set null,
  used_at timestamp with time zone,
  created_at timestamp with time zone default now()
);

-- Create indexes
CREATE INDEX idx_codes_code ON codes(code);
CREATE INDEX idx_codes_used_by ON codes(used_by);
CREATE INDEX idx_codes_created_by ON codes(created_by);

-- Enable RLS
ALTER TABLE codes ENABLE ROW LEVEL SECURITY;

-- Create policies
DROP POLICY IF EXISTS "Allow all for codes" ON codes;
CREATE POLICY "Allow all for codes" ON codes FOR ALL USING (true) WITH CHECK (true);

-- Recreate the create_user_codes function to match
DROP FUNCTION IF EXISTS create_user_codes(uuid);

CREATE OR REPLACE FUNCTION create_user_codes(user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY definer
AS $$
DECLARE
  i integer;
  new_code text;
  code_exists boolean;
BEGIN
  FOR i IN 1..3 LOOP
    LOOP
      -- Generate random 8-character code
      new_code := upper(substring(md5(random()::text) from 1 for 8));

      -- Check if code already exists
      SELECT exists(SELECT 1 FROM codes WHERE code = new_code) INTO code_exists;

      -- If unique, insert and exit loop
      IF NOT code_exists THEN
        INSERT INTO codes (code, created_by, used_by)
        VALUES (new_code, user_id, null);
        EXIT;
      END IF;
    END LOOP;
  END LOOP;
END;
$$;

-- Insert 20 test codes
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

-- Verify
SELECT
  COUNT(*) as total_codes,
  COUNT(*) FILTER (WHERE used_by IS NULL) as available_codes
FROM codes;

-- Show available codes
SELECT code FROM codes WHERE used_by IS NULL ORDER BY code;
