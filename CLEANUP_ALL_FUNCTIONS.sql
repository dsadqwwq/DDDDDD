-- ============================================
-- NUCLEAR CLEANUP - Remove ALL GP and GC function versions
-- ============================================

-- List all versions first
SELECT
  routine_name,
  string_agg(parameter_name || ' ' || data_type, ', ' ORDER BY ordinal_position) as signature
FROM information_schema.routines r
LEFT JOIN information_schema.parameters p ON r.specific_name = p.specific_name
WHERE routine_name IN ('update_user_gp', 'secure_update_gp', 'update_user_gc', 'secure_update_gc')
  AND routine_schema = 'public'
GROUP BY routine_name, r.specific_name;

-- Drop by full signature (all possible combinations)
DROP FUNCTION IF EXISTS public.update_user_gp(uuid, bigint) CASCADE;
DROP FUNCTION IF EXISTS public.update_user_gp(uuid, bigint, text) CASCADE;
DROP FUNCTION IF EXISTS public.update_user_gp(uuid, bigint, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.update_user_gp(uuid, bigint, text, text, uuid) CASCADE;

DROP FUNCTION IF EXISTS public.secure_update_gp(bigint) CASCADE;
DROP FUNCTION IF EXISTS public.secure_update_gp(bigint, text) CASCADE;
DROP FUNCTION IF EXISTS public.secure_update_gp(bigint, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.secure_update_gp(bigint, text, text, uuid) CASCADE;

DROP FUNCTION IF EXISTS public.update_user_gc(uuid, bigint) CASCADE;
DROP FUNCTION IF EXISTS public.update_user_gc(uuid, bigint, text) CASCADE;
DROP FUNCTION IF EXISTS public.update_user_gc(uuid, bigint, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.update_user_gc(uuid, bigint, text, text, uuid) CASCADE;

DROP FUNCTION IF EXISTS public.secure_update_gc(bigint) CASCADE;
DROP FUNCTION IF EXISTS public.secure_update_gc(bigint, text) CASCADE;
DROP FUNCTION IF EXISTS public.secure_update_gc(bigint, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.secure_update_gc(bigint, text, text, uuid) CASCADE;

-- Verify all are gone
SELECT routine_name
FROM information_schema.routines
WHERE routine_name IN ('update_user_gp', 'secure_update_gp', 'update_user_gc', 'secure_update_gc')
  AND routine_schema = 'public';

-- Should return 0 rows
