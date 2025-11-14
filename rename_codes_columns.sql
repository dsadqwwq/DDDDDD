-- ALTER the codes table columns instead of dropping
-- This preserves existing codes and just renames columns

-- First, let's see what columns you actually have right now
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'codes'
ORDER BY ordinal_position;

-- Step 1: Check if owner_id exists, rename it to created_by
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'codes' AND column_name = 'owner_id'
    ) THEN
        ALTER TABLE codes RENAME COLUMN owner_id TO created_by;
        RAISE NOTICE 'Renamed owner_id to created_by';
    END IF;
END $$;

-- Step 2: Add used_by column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'codes' AND column_name = 'used_by'
    ) THEN
        ALTER TABLE codes ADD COLUMN used_by uuid REFERENCES users(id) ON DELETE SET NULL;
        RAISE NOTICE 'Added used_by column';
    END IF;
END $$;

-- Step 3: Add used_at column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'codes' AND column_name = 'used_at'
    ) THEN
        ALTER TABLE codes ADD COLUMN used_at timestamp with time zone;
        RAISE NOTICE 'Added used_at column';
    END IF;
END $$;

-- Step 4: Recreate the create_user_codes function
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

-- Verify the columns are correct now
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'codes'
ORDER BY ordinal_position;

-- Test the function exists
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_name = 'create_user_codes';

-- Show available codes
SELECT code, created_by, used_by, used_at
FROM codes
WHERE used_by IS NULL
LIMIT 10;
