-- Function to get a user's rank and GC balance (updated for GC system)
-- This is used when the user is not in the top 500

CREATE OR REPLACE FUNCTION get_user_rank(p_user_id uuid)
RETURNS TABLE(rank bigint, gc_balance bigint)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH ranked_users AS (
    SELECT
      id,
      gc_balance,
      ROW_NUMBER() OVER (ORDER BY gc_balance DESC, created_at ASC) as user_rank
    FROM users
  )
  SELECT
    user_rank::bigint as rank,
    ranked_users.gc_balance
  FROM ranked_users
  WHERE id = p_user_id;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_user_rank(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_rank(uuid) TO anon;
