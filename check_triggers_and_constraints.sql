-- Check for triggers on codes table that might reference owner_id
SELECT
  trigger_name,
  event_manipulation,
  action_statement
FROM information_schema.triggers
WHERE event_object_table = 'codes';

-- Check for foreign key constraints
SELECT
  constraint_name,
  constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'codes';

-- Show ALL columns in codes table to be absolutely sure
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'codes'
ORDER BY ordinal_position;

-- Drop and recreate the entire codes table cleanly
DROP TABLE IF EXISTS codes CASCADE;

CREATE TABLE codes (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  created_by uuid,
  used_by uuid,
  used_at timestamp with time zone,
  created_at timestamp with time zone default now()
);

-- Add foreign keys AFTER creating users table
ALTER TABLE codes ADD CONSTRAINT codes_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE codes ADD CONSTRAINT codes_used_by_fkey FOREIGN KEY (used_by) REFERENCES users(id) ON DELETE SET NULL;

-- RLS
ALTER TABLE codes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for codes" ON codes;
CREATE POLICY "Allow all for codes" ON codes FOR ALL USING (true) WITH CHECK (true);

-- Add test codes
INSERT INTO codes (code) VALUES
  ('TEST1234'), ('TEST5678'), ('DEMO1234'), ('DEMO5678'),
  ('ALPHA001'), ('ALPHA002'), ('BETA0001'), ('BETA0002'),
  ('GAMMA123'), ('DELTA456'), ('START001'), ('START002'),
  ('INVITE01'), ('INVITE02'), ('ACCESS01'), ('ACCESS02'),
  ('WELCOME1'), ('WELCOME2'), ('DUELPVP1'), ('DUELPVP2');

SELECT COUNT(*) as available_codes FROM codes WHERE used_by IS NULL;
