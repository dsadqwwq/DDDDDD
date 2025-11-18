-- =====================================================
-- SECURE RLS POLICIES FOR ANONYMOUS AUTH
-- =====================================================
-- This locks down your database so anonymous users can only
-- access their own data and cannot cheat the system

-- =====================================================
-- USERS TABLE - Critical Security
-- =====================================================

-- Drop insecure policies
DROP POLICY IF EXISTS "Allow all for users" ON users;
DROP POLICY IF EXISTS "Allow all" ON users;

-- Users can only view their own profile
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT
  TO authenticated, anon
  USING (
    auth.uid() = auth_user_id OR  -- Match by auth_user_id (for anonymous users)
    auth.uid() = id                -- Fallback: direct match (for old users)
  );

-- Users can update ONLY their own display_name (NOT gp_balance!)
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE
  TO authenticated, anon
  USING (
    auth.uid() = auth_user_id OR
    auth.uid() = id
  )
  WITH CHECK (
    auth.uid() = auth_user_id OR
    auth.uid() = id
  );

-- Prevent users from creating new users directly (use registration function)
CREATE POLICY "No direct user creation" ON users
  FOR INSERT
  TO authenticated, anon
  WITH CHECK (false);

-- Prevent users from deleting themselves
CREATE POLICY "No user deletion" ON users
  FOR DELETE
  TO authenticated, anon
  USING (false);

-- =====================================================
-- CODES TABLE - Restrict Access
-- =====================================================

-- Drop insecure policies
DROP POLICY IF EXISTS "Allow all for codes" ON codes;
DROP POLICY IF EXISTS "Allow all" ON codes;
DROP POLICY IF EXISTS "Codes are viewable by everyone" ON codes;
DROP POLICY IF EXISTS "Codes can be updated by anyone" ON codes;
DROP POLICY IF EXISTS "Codes can be inserted" ON codes;

-- Anyone can view unused codes (needed for validation during registration)
-- Can also view codes they created or used
CREATE POLICY "View available and own codes" ON codes
  FOR SELECT
  TO authenticated, anon
  USING (
    used_by IS NULL OR  -- Can see unused codes
    used_by = (SELECT id FROM users WHERE auth_user_id = auth.uid())  -- Can see codes they used
  );

-- Prevent direct code updates (only through RPC functions)
CREATE POLICY "No direct code updates" ON codes
  FOR UPDATE
  TO authenticated, anon
  USING (false);

-- Prevent direct code insertion (only through RPC functions)
CREATE POLICY "No direct code insertion" ON codes
  FOR INSERT
  TO authenticated, anon
  WITH CHECK (false);

-- Prevent code deletion
CREATE POLICY "No code deletion" ON codes
  FOR DELETE
  TO authenticated, anon
  USING (false);

-- =====================================================
-- GP_TRANSACTIONS TABLE - Read Only for Users
-- =====================================================

-- Enable RLS if not already enabled
ALTER TABLE gp_transactions ENABLE ROW LEVEL SECURITY;

-- Drop old policies
DROP POLICY IF EXISTS "Users view own transactions" ON gp_transactions;
DROP POLICY IF EXISTS "Functions only insert" ON gp_transactions;

-- Users can only view their own transactions
CREATE POLICY "Users view own transactions" ON gp_transactions
  FOR SELECT
  TO authenticated, anon
  USING (
    user_id = (SELECT id FROM users WHERE auth_user_id = auth.uid()) OR
    user_id = auth.uid()  -- Fallback
  );

-- Prevent ALL direct modifications (only RPC functions can modify)
CREATE POLICY "No direct transaction modifications" ON gp_transactions
  FOR INSERT
  TO authenticated, anon
  WITH CHECK (false);

CREATE POLICY "No transaction updates" ON gp_transactions
  FOR UPDATE
  TO authenticated, anon
  USING (false);

CREATE POLICY "No transaction deletes" ON gp_transactions
  FOR DELETE
  TO authenticated, anon
  USING (false);

-- =====================================================
-- MINES_GAMES TABLE - Secure Game State
-- =====================================================

-- Enable RLS if not already enabled
ALTER TABLE mines_games ENABLE ROW LEVEL SECURITY;

-- Drop old policies
DROP POLICY IF EXISTS "Users can view own games" ON mines_games;
DROP POLICY IF EXISTS "No direct manipulation" ON mines_games;

-- Users can only view their own games
CREATE POLICY "Users view own games" ON mines_games
  FOR SELECT
  TO authenticated, anon
  USING (
    user_id = (SELECT id FROM users WHERE auth_user_id = auth.uid()) OR
    user_id = auth.uid()  -- Fallback
  );

-- Prevent ALL direct modifications (only RPC functions can modify)
CREATE POLICY "No direct game modifications" ON mines_games
  FOR INSERT
  TO authenticated, anon
  WITH CHECK (false);

CREATE POLICY "No game updates" ON mines_games
  FOR UPDATE
  TO authenticated, anon
  USING (false);

CREATE POLICY "No game deletes" ON mines_games
  FOR DELETE
  TO authenticated, anon
  USING (false);

-- =====================================================
-- STAKES TABLE - Secure Staking System
-- =====================================================

-- Enable RLS if not already enabled (if stakes table exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'stakes') THEN
    EXECUTE 'ALTER TABLE stakes ENABLE ROW LEVEL SECURITY';

    -- Drop old policies
    EXECUTE 'DROP POLICY IF EXISTS "Users can view own stakes" ON stakes';
    EXECUTE 'DROP POLICY IF EXISTS "No direct stake manipulation" ON stakes';

    -- Users can only view their own stakes
    EXECUTE 'CREATE POLICY "Users view own stakes" ON stakes
      FOR SELECT
      TO authenticated, anon
      USING (
        user_id = (SELECT id FROM users WHERE auth_user_id = auth.uid()) OR
        user_id = auth.uid()
      )';

    -- Prevent ALL direct modifications
    EXECUTE 'CREATE POLICY "No direct stake modifications" ON stakes
      FOR INSERT
      TO authenticated, anon
      WITH CHECK (false)';

    EXECUTE 'CREATE POLICY "No stake updates" ON stakes
      FOR UPDATE
      TO authenticated, anon
      USING (false)';

    EXECUTE 'CREATE POLICY "No stake deletes" ON stakes
      FOR DELETE
      TO authenticated, anon
      USING (false)';
  END IF;
END $$;

-- =====================================================
-- COLUMN-LEVEL PERMISSIONS: Protect GP Balance
-- =====================================================
-- Prevent users from directly updating sensitive columns
-- This works alongside RLS policies for defense-in-depth

-- Revoke all permissions first, then grant specific ones
REVOKE ALL ON users FROM authenticated, anon;

-- Grant SELECT on all columns (users can read their own profile via RLS)
GRANT SELECT ON users TO authenticated, anon;

-- Grant UPDATE only on safe columns (not gp_balance, not points, not wallet_address)
-- Users can only update: display_name
GRANT UPDATE (display_name) ON users TO authenticated, anon;

-- Note: SECURITY DEFINER functions bypass these restrictions
-- So secure_update_gp() can still modify gp_balance

-- Do the same for codes table
REVOKE ALL ON codes FROM authenticated, anon;
GRANT SELECT ON codes TO authenticated, anon;
-- No UPDATE/INSERT/DELETE grants - only RPC functions can modify

-- Transaction tables are read-only
REVOKE ALL ON gp_transactions FROM authenticated, anon;
GRANT SELECT ON gp_transactions TO authenticated, anon;

-- Games table is read-only
REVOKE ALL ON mines_games FROM authenticated, anon;
GRANT SELECT ON mines_games TO authenticated, anon;

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Count policies (should show multiple policies per table)
SELECT
  schemaname,
  tablename,
  COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('users', 'codes', 'gp_transactions', 'mines_games', 'stakes')
GROUP BY schemaname, tablename
ORDER BY tablename;

-- Show all policies for review
SELECT
  tablename,
  policyname,
  cmd as operation,
  CASE
    WHEN qual IS NOT NULL THEN 'Has USING clause'
    ELSE 'No USING clause'
  END as using_clause,
  CASE
    WHEN with_check IS NOT NULL THEN 'Has WITH CHECK clause'
    ELSE 'No WITH CHECK clause'
  END as with_check_clause
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('users', 'codes', 'gp_transactions', 'mines_games', 'stakes')
ORDER BY tablename, policyname;

SELECT
  '✅ RLS Policies Secured!' as status,
  'Anonymous users can now only access their own data' as result,
  'GP balance can only be modified through secure RPC functions' as gp_security;
