-- Show the actual definition of create_user_codes function
-- This will reveal if it still has owner_id in it

SELECT
  routine_name,
  routine_definition
FROM information_schema.routines
WHERE routine_name = 'create_user_codes';

-- Also drop ALL versions of this function and recreate clean
DROP FUNCTION IF EXISTS create_user_codes(uuid) CASCADE;
DROP FUNCTION IF EXISTS create_user_codes CASCADE;

-- Recreate it properly
CREATE FUNCTION create_user_codes(user_id uuid)
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
      new_code := upper(substring(md5(random()::text) from 1 for 8));
      SELECT exists(SELECT 1 FROM codes WHERE code = new_code) INTO code_exists;
      IF NOT code_exists THEN
        INSERT INTO codes (code, created_by) VALUES (new_code, user_id);
        EXIT;
      END IF;
    END LOOP;
  END LOOP;
END;
$$;

-- Verify it was created
SELECT routine_name FROM information_schema.routines WHERE routine_name = 'create_user_codes';
