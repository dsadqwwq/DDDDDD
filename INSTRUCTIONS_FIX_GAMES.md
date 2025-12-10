# Fix Your Games - Quick Instructions

## The Problem

Your `users` table has `gc_balance`, but your game functions are trying to use `gp_balance` (which doesn't exist).

When users try to play games, they'll get: **ERROR: column "gp_balance" does not exist**

## The Solution

Run **`fix_game_functions.sql`** in your Supabase SQL Editor.

This will:
1. Fix `secure_update_gp()` to use `gc_balance`
2. Fix `update_user_gp()` to use `gc_balance`
3. Create `mines_games` table (needed for Mines game)

## How to Run It

1. Open **Supabase Dashboard** → **SQL Editor**
2. Click **New Query**
3. Copy and paste the entire contents of **`fix_game_functions.sql`**
4. Click **Run** (or press Ctrl+Enter)

Done! Your games (Crash, Mines, Blackjack) will now work.

---

## Other Files

- ✅ **`fix_game_functions.sql`** - RUN THIS to fix games
- ✅ **`add_founders_swords.sql`** - Run this to add swords to 47 wallets
- ❌ **`supabase_game_setup.sql`** - DO NOT RUN (would overwrite your functions)
- ❌ **`supabase_auth_setup.sql`** - DO NOT RUN (would overwrite your functions)
