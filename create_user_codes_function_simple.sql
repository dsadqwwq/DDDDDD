-- SIMPLE VERSION: create_user_codes function for basic codes table
-- Use this if your codes table ONLY has 'code' column (no created_by, used_by, etc.)

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
        -- Insert with ONLY the code column (adapts to your table structure)
        INSERT INTO codes (code)
        VALUES (new_code);
        EXIT;
      END IF;
    END LOOP;
  END LOOP;
END;
$$;

-- Test it
SELECT routine_name
FROM information_schema.routines
WHERE routine_name = 'create_user_codes';

-- You can also manually test it:
-- SELECT create_user_codes('00000000-0000-0000-0000-000000000000'::uuid);
-- SELECT * FROM codes ORDER BY created_at DESC LIMIT 3;
