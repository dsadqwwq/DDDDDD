-- Function to get a user's rank and GC balance (updated for GC system)
-- This is used when the user is not in the top 500

DROP FUNCTION IF EXISTS get_user_rank(uuid);

CREATE OR REPLACE FUNCTION get_user_rank(p_user_id uuid)
RETURNS TABLE(rank bigint, user_gc_balance bigint)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_gc_balance bigint;
BEGIN
  -- Get the user's gc_balance
  SELECT gc_balance INTO v_gc_balance FROM users WHERE id = p_user_id;

  -- Return rank and balance
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) + 1 FROM users WHERE gc_balance > v_gc_balance)::bigint,
    v_gc_balance;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_user_rank(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_rank(uuid) TO anon;
