# Fix GP Balance Not Showing

## Problem
GP balance shows 0 at the top of the screen because the database functions don't exist yet.

## Solution
Run `add_gp_balance_system.sql` in Supabase SQL Editor.

## Steps

1. **Go to Supabase Dashboard**
   - https://supabase.com/dashboard
   - Select your project

2. **Open SQL Editor**
   - Click "SQL Editor" in left sidebar
   - Click "New Query"

3. **Copy and Paste**
   - Open `add_gp_balance_system.sql`
   - Copy the ENTIRE file
   - Paste into SQL Editor
   - Click "Run"

4. **Verify Success**
   You should see output like:
   ```
   status: Setup Complete!
   users_with_balance: 1 (or more)
   has_update_gp: 1
   has_get_gp: 1
   has_mines_start: 1
   has_mines_click: 1
   has_mines_cashout: 1
   ```

5. **Refresh Your Site**
   - GP balance should now show correctly
   - New users start with 1000 GP
   - Existing users get 1000 GP added

## What This Does

- Adds `gp_balance` column to users table
- Creates `get_user_gp()` function (fixes the display issue)
- Creates `update_user_gp()` function (for spending/earning GP)
- Creates Mines game functions (for future games)
- Sets all users to start with 1000 GP

## If It Still Shows 0

Try logging out and back in to refresh the cache.
