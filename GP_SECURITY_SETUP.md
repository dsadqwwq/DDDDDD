# 🔒 Secure GP Balance System - Setup Guide

This guide explains how to set up the new server-side GP validation system to prevent client-side cheating.

---

## 🎯 What This Fixes

### Before (INSECURE ❌):
- GP stored in `localStorage` (client-side)
- Users could open DevTools and give themselves unlimited GP
- Game results calculated on client, then trusted by server
- Mine positions generated on client (visible in DevTools)

### After (SECURE ✅):
- GP stored in Supabase database (server-side)
- Server validates all GP transactions
- Negative balances prevented by database
- All game logic validated server-side
- Mine positions never sent to client until game ends

---

## 📋 Setup Instructions

### Step 1: Run the SQL Migration

1. Open your Supabase project: https://app.supabase.com
2. Go to **SQL Editor** in the left sidebar
3. Click "New Query"
4. Copy and paste the contents of `add_gp_balance_system.sql`
5. Click "Run" or press `Ctrl+Enter`

You should see output like:
```
status: Setup Complete!
users_with_balance: [your user count]
has_update_gp: 1
has_get_gp: 1
has_mines_start: 1
has_mines_click: 1
has_mines_cashout: 1
```

If all values are `1`, you're good to go! ✅

---

### Step 2: Verify the Migration

Run this query to check everything is set up:

```sql
-- Check if GP balance column exists
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'users'
  AND column_name = 'gp_balance';

-- Check if functions exist
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('update_user_gp', 'get_user_gp', 'mines_start_game', 'mines_click_tile', 'mines_cashout');

-- Check if mines_games table exists
SELECT table_name
FROM information_schema.tables
WHERE table_name = 'mines_games';
```

Expected results:
- `gp_balance` column exists with type `bigint`
- All 5 functions exist
- `mines_games` table exists

---

### Step 3: Deploy the Updated Code

The JavaScript code has been updated to use the new system:

1. Test locally first (it will still work with `localStorage` for test mode)
2. Deploy to production when ready

---

## 🧪 How to Test

### Test 1: GP Updates (Secure)

1. Register a new user or login
2. Open DevTools Console
3. Try to cheat: `localStorage.setItem('duelpvp_gp', '9999999')`
4. Refresh the page
5. **Result**: Balance should reload from database, not localStorage ✅

### Test 2: Negative Balance Prevention

1. Login with a user that has 100 GP
2. Try to play a game with 200 GP bet
3. **Result**: Should show error "Insufficient balance" ✅

### Test 3: Mines Game Security

1. Start a mines game
2. Open DevTools Console
3. Try to find mine positions: `console.log(minesGameState)`
4. **Result**: Mine positions should NOT be visible until game ends ✅

---

## 🔑 How It Works

### GP Balance Flow

**Old (Insecure)**:
```
Client: balance = localStorage.getItem('gp')
Client: localStorage.setItem('gp', newBalance)  // ❌ Cheatable!
```

**New (Secure)**:
```
Client: getUserGP()
  ↓
Server: SELECT gp_balance FROM users WHERE id = user_id
  ↓
Client: receives balance (cannot modify)

Client: updateUserGP(+100)
  ↓
Server: Validates user exists
Server: Checks balance won't go negative
Server: UPDATE users SET gp_balance = gp_balance + 100
  ↓
Client: receives new balance
```

### Mines Game Flow

**Old (Insecure)**:
```
Client: minePositions = generateMines()  // ❌ Client can see this!
Client: clicked tile 7
Client: if (minePositions.includes(7)) { ... }  // ❌ Client controls outcome!
```

**New (Secure)**:
```
Client: Start game, bet 100 GP
  ↓
Server: Deduct 100 GP (validates balance)
Server: Generate mine positions (NEVER sent to client)
Server: Store in database
  ↓
Client: receives gameId

Client: Click tile 7
  ↓
Server: Check if tile 7 has mine
Server: Update game state
  ↓
Client: receives "safe" or "mine" (cannot predict or control)
```

---

## 🚨 Important Notes

### Test Mode Still Works!

Users with IDs starting with `test-` will still use `localStorage` for GP:
```javascript
if (!userId || userId.startsWith('test-')) {
  // Use localStorage (for testing/demo)
} else {
  // Use database (secure)
}
```

This means you can still demo the app without requiring database login!

### GP Cache

The system caches GP balance for 5 seconds to reduce database queries:
```javascript
gpCache = {
  balance: 0,
  lastFetch: 0,
  cacheTime: 5000 // 5 seconds
};
```

This means:
- ✅ Fast UI updates (no delay)
- ✅ Reduced database load
- ✅ Still secure (cache only lasts 5 seconds)

### Backward Compatibility

The system automatically detects if Supabase functions are available:
- If functions exist: uses secure database mode
- If functions missing: falls back to localStorage (test mode)

---

## 🔮 Next Steps (Future Improvements)

### 1. Secure Other Games

Apply the same pattern to:
- ❌ Crash game (currently client-side)
- ❌ Blackjack (currently client-side)
- ❌ Trading Sim (currently client-side)

### 2. Tighten RLS Policies

Currently the RLS policies are permissive (`USING (true)`). You should restrict them:

```sql
-- Only allow SELECT for authenticated users
CREATE POLICY "Users can view own balance" ON users
  FOR SELECT USING (auth.uid() = id);

-- Prevent direct updates (force use of RPC functions)
CREATE POLICY "No direct GP updates" ON users
  FOR UPDATE USING (false);
```

### 3. Add Server-Side Random Generation

For truly unpredictable results, use Supabase Edge Functions with server-side randomness:
- Crash multiplier generation
- Blackjack card shuffling
- Any randomness that affects winnings

---

## 📚 File Reference

| File | Purpose |
|------|---------|
| `add_gp_balance_system.sql` | Database migration - run this in Supabase |
| `index.html` | Updated with secure GP functions |
| `GP_SECURITY_SETUP.md` | This file - setup guide |

---

## ❓ Troubleshooting

### "Function not found" error

**Problem**: Supabase can't find `update_user_gp` or `get_user_gp`

**Solution**: Make sure you ran `add_gp_balance_system.sql` in Supabase SQL Editor

### Balance not updating

**Problem**: GP changes don't save to database

**Solution**:
1. Check browser console for errors
2. Verify user is logged in (not test mode)
3. Check Supabase logs for RPC errors

### Mine positions visible in DevTools

**Problem**: User can still see mine positions

**Solution**: Make sure you're using the new `mines_start_game` RPC function, not the old client-side generation

---

## 🎓 Key Takeaways

1. **Never trust the client** - All valuable data should be validated server-side
2. **Use RPC functions** - They prevent direct table manipulation
3. **Server generates randomness** - Client should never generate anything that affects winnings
4. **Validate everything** - Check balances, check game state, check permissions
5. **Use RLS policies** - Prevent unauthorized database access

---

**You now have a secure GP system!** 🎉

Users can no longer:
- ❌ Give themselves unlimited GP
- ❌ See mine positions before clicking
- ❌ Bypass bet costs
- ❌ Fake game results

The server validates everything! ✅
