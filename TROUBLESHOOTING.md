# 🔧 Database Setup Troubleshooting

## Issue: Functions Not Being Created

If you ran `add_gp_balance_system.sql` but are getting "function does not exist" errors, use this guide.

---

## Quick Fix: Use Step-by-Step Setup

Instead of running the large SQL file all at once, use `step_by_step_setup.sql`:

### How to Use:

1. Open Supabase SQL Editor
2. Open `step_by_step_setup.sql`
3. **Copy ONLY Step 1** (the first SELECT query)
4. Paste into SQL Editor and click "Run"
5. **Check the result** - you should see the `gp_balance` column
6. **Move to Step 2** - copy ONLY the Step 2 code
7. Run it and check for errors
8. **Continue step by step** until all functions are created

### Why This Works:

- **Explicit schema references**: Uses `public.` prefix everywhere
- **Search path set**: Each function has `SET search_path = public`
- **Immediate verification**: Test after each step
- **Isolated errors**: If one step fails, you know exactly which one

---

## Common Errors and Fixes

### Error: "permission denied for schema public"

**Cause**: Your Supabase user doesn't have permission to create functions

**Fix**: You need to be the database owner or have CREATEFUNCTION ON FUNCTION get_user_gp(uuid) TO anon, authenticated;
```

Expected result: `GRANT` (no errors)

---

### Test 3: Call the function from SQL

```sql
SELECT public.get_user_gp('00000000-0000-0000-0000-000000000001'::uuid);
```

Expected result: Should return a number (likely 5000 if you created the test user)

---

### Test 4: Call via RPC (like JavaScript does)

In your browser console:

```javascript
const { data, error } = await supabase.rpc('get_user_gp', {
  p_user_id: '00000000-0000-0000-0000-000000000001'
});
console.log('Data:', data, 'Error:', error);
```

Expected result: `Data: 5000 Error: null`

If you get 404 error here but SQL query worked, the issue is RPC permissions.

---

## Most Likely Causes

Based on the error "function get_user_gp(uuid) does not exist":

1. **SQL file had an error midway** - Only part of it ran
2. **Missing schema prefix** - Function created in wrong schema
3. **Wrong Supabase project** - You're looking in a different database

---

## Nuclear Option: Start Fresh

If nothing works, run this to drop everything and start over:

```sql
-- Drop all functions
DROP FUNCTION IF EXISTS public.get_user_gp(uuid);
DROP FUNCTION IF EXISTS public.update_user_gp(uuid, bigint);
DROP FUNCTION IF EXISTS public.mines_start_game(uuid, bigint, integer);
DROP FUNCTION IF EXISTS public.mines_click_tile(uuid, integer);
DROP FUNCTION IF EXISTS public.mines_cashout(uuid);

-- Drop table
DROP TABLE IF EXISTS public.mines_games;

-- Now run step_by_step_setup.sql step by step
```

---

## Need More Help?

Check the Supabase logs:
1. Go to your Supabase project
2. Click "Logs" in sidebar
3. Select "Postgres Logs"
4. Look for errors around the time you ran the SQL

The error messages there will show exactly what went wrong.
