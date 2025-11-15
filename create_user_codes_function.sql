-- Create ONLY the create_user_codes RPC function
-- This function generates 3 invite codes for a new user
-- Run this if you're getting errors during registration

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

-- Test it by checking if the function was created
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'create_user_codes';
