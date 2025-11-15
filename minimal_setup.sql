-- MINIMAL DATABASE SETUP - Just enough to get registration working
-- Run this ENTIRE script in Supabase SQL Editor
-- This will get you up and running in 30 seconds

-- 1. Create users table if it doesn't exist
CREATE TABLE IF NOT EXISTS users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  display_name text unique not null,
  points integer default 0,
  wallet_address text,
  level integer default 1,
  total_wins integer default 0,
  win_streak integer default 0,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- 2. Make sure codes table has correct structure
-- First, drop it if it exists with wrong structure
DROP TABLE IF EXISTS codes CASCADE;

-- Create codes table with correct columns
CREATE TABLE codes (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  created_by uuid references users(id) on delete set null,
  used_by uuid references users(id) on delete set null,
  used_at timestamp with time zone,
  created_at timestamp with time zone default now()
);

-- 3. Create the create_user_codes function (REQUIRED for registration)
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
        INSERT INTO codes (code, created_by)
        VALUES (new_code, user_id);
        EXIT;
      END IF;
    END LOOP;
  END LOOP;
END;
$$;

-- 4. Enable RLS (Row Level Security)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE codes ENABLE ROW LEVEL SECURITY;

-- 5. Create permissive policies (allow everything for now)
DROP POLICY IF EXISTS "Allow all for users" ON users;
CREATE POLICY "Allow all for users" ON users FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for codes" ON codes;
CREATE POLICY "Allow all for codes" ON codes FOR ALL USING (true) WITH CHECK (true);

-- 6. Insert 20 starter codes
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

-- 7. Verify everything was created
SELECT
  (SELECT COUNT(*) FROM users) as total_users,
  (SELECT COUNT(*) FROM codes WHERE used_by IS NULL) as available_codes,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'create_user_codes') as has_create_codes_function;

-- If you see:
-- total_users: any number
-- available_codes: 20
-- has_create_codes_function: 1
-- Then you're ready to go! Try registering with code: TEST1234

-- Display available codes
SELECT code FROM codes WHERE used_by IS NULL ORDER BY code;
