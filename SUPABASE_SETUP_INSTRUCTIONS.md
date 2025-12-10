# Supabase Setup Instructions for Games

## What You Need to Run

I've analyzed your code and created **2 SQL files** that contain everything you need to make all games functional:

### 1. `supabase_game_setup.sql` - Core Game Functionality
This file creates:

**Tables:**
- `users` - Main user data with gc_balance
- `transactions` - Track all GC movements (wins/losses)
- `scores` - Game scores (for reaction game)
- `codes` - Invite codes system
- `inventory_items` - NFTs and special items (Founder's Sword)

**RPC Functions for Games:**
- `get_user_gc(user_id)` - Get user's GC balance
- `secure_update_gp(amount, type, game)` - Update GC (with JWT auth)
- `update_user_gp(user_id, amount, type, game)` - Update GC (fallback)
- `get_leaderboard(limit)` - Get top players
- `get_user_rank(user_id)` - Get user's rank
- `get_user_invite_codes(user_id)` - Get user's invite codes

### 2. `supabase_auth_setup.sql` - Authentication
This file creates:

**RPC Functions for Auth:**
- `register_user_with_wallet(wallet, name, code)` - Register new user
- `login_with_wallet(wallet, signature)` - Login existing user
- `validate_invite_code(code)` - Check if code is valid
- `reserve_invite_code(code, wallet)` - Reserve code during signup
- `link_auth_to_user(user_id, wallet)` - Link Supabase auth to user

### 3. `add_founders_swords.sql` - Already Created
This adds Founder's Sword to the 47 supporter wallets.

---

## How to Install

### Step 1: Run Core Game Setup
1. Open **Supabase Dashboard** → **SQL Editor**
2. Click **New Query**
3. Copy and paste the entire contents of `supabase_game_setup.sql`
4. Click **Run** (or press Ctrl+Enter)

### Step 2: Run Auth Setup
1. In **SQL Editor**, click **New Query** again
2. Copy and paste the entire contents of `supabase_auth_setup.sql`
3. Click **Run**

### Step 3: (Optional) Add Founder's Swords
1. In **SQL Editor**, click **New Query**
2. Copy and paste the entire contents of `add_founders_swords.sql`
3. Click **Run**

---

## What Games Will Work After Setup

✅ **Crash** - Rocket game with multipliers
✅ **Mines** - Minesweeper-style game
✅ **Blackjack** - Card game
✅ **Trading Sim** - Reaction time game (currently disabled in UI)

All games will:
- Deduct bets from user's GC balance
- Award winnings to user's GC balance
- Track all transactions in the database
- Update leaderboard automatically
- Work with both wallet and email login

---

## Verification

After running the SQL scripts, you can verify everything works:

```sql
-- Check if tables exist
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('users', 'transactions', 'scores', 'codes', 'inventory_items');

-- Check if functions exist
SELECT routine_name FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN ('get_user_gc', 'secure_update_gp', 'login_with_wallet', 'register_user_with_wallet');

-- Test getting a leaderboard
SELECT * FROM get_leaderboard(10);

-- Test getting user GC (replace with actual user ID)
SELECT get_user_gc('YOUR_USER_ID_HERE');
```

---

## What If Something Breaks?

The SQL scripts use `CREATE TABLE IF NOT EXISTS` and `CREATE OR REPLACE FUNCTION`, so:
- ✅ **Safe to run multiple times** - won't duplicate or break existing data
- ✅ **Updates functions** - will update RPC functions to latest version
- ✅ **Preserves data** - won't delete any existing user data

If you get errors, check:
1. You have the correct permissions (should be database owner)
2. UUID extension is enabled: `CREATE EXTENSION IF NOT EXISTS "uuid-ossp";`
3. The `auth` schema exists (for JWT functions)

---

## Starting Balance

When users register:
- **New users get 1000 GC** to start playing
- **Referrer gets 500 GC** when someone uses their invite code
- Each user gets **3 invite codes** upon registration

You can change these values in `supabase_auth_setup.sql` in the `register_user_with_wallet` function.
