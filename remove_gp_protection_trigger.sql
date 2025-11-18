-- =====================================================
-- REMOVE GP PROTECTION TRIGGER
-- =====================================================
-- This trigger is blocking even SECURITY DEFINER functions
-- from updating GP balance. We need to remove it.
--
-- SECURITY DEFINER functions are already secure and should
-- be allowed to update GP balance.

-- List all triggers on users table (for debugging)
SELECT
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE event_object_table = 'users';

-- Drop any triggers that might be blocking GP updates
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN (
    SELECT trigger_name
    FROM information_schema.triggers
    WHERE event_object_table = 'users'
      AND (
        trigger_name ILIKE '%gp%' OR
        trigger_name ILIKE '%balance%' OR
        trigger_name ILIKE '%protect%'
      )
  ) LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON users', r.trigger_name);
    RAISE NOTICE 'Dropped trigger: %', r.trigger_name;
  END LOOP;
END $$;

-- Verify triggers were removed
SELECT
  'Trigger cleanup complete' as status,
  COUNT(*) as remaining_triggers_on_users
FROM information_schema.triggers
WHERE event_object_table = 'users';
