-- =====================================================
-- LINK AUTH USER FUNCTION
-- =====================================================
-- This function links anonymous auth users to database users
-- Bypasses RLS to avoid chicken-and-egg problem where
-- auth_user_id must be set before RLS policy allows the update

CREATE OR REPLACE FUNCTION link_auth_to_user(
  p_user_id uuid,
  p_auth_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER  -- Bypass RLS
SET search_path = public
AS $$
BEGIN
  -- Update the user record to link auth_user_id
  UPDATE users
  SET auth_user_id = p_auth_user_id,
      updated_at = now()
  WHERE id = p_user_id;

  RETURN FOUND;
END;
$$;

-- Grant execute to anonymous users
GRANT EXECUTE ON FUNCTION link_auth_to_user TO authenticated, anon;

SELECT 'Link auth function created!' as status;
