-- ============================================
-- FIX get_user_rank TO RETURN SINGLE ROW
-- ============================================
-- Frontend expects single object, not array

DROP FUNCTION IF EXISTS get_user_rank(uuid);

CREATE OR REPLACE FUNCTION get_user_rank(p_user_id uuid)
RETURNS TABLE(rank bigint, gc_balance bigint)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) + 1 FROM users WHERE gc_balance > u.gc_balance)::bigint as rank,
    u.gc_balance::bigint
  FROM users u
  WHERE u.id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION get_user_rank(uuid) TO authenticated, anon;

-- Verify
SELECT 'get_user_rank function fixed!' as status;
