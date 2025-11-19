# 🧪 Database Testing Guide

Quick guide to test both localStorage and database modes.

---

## 📋 Setup Steps

### 1️⃣ Run the Main Migration (Required First!)

Go to Supabase SQL Editor and run:
```sql
-- Copy/paste contents of: add_gp_balance_system.sql
```

This creates:
- `gp_balance` column on users table
- All the secure RPC functions
- `mines_games` table

### 2️⃣ Create Test User (Optional but Recommended)

Go to Supabase SQL Editor and run:
```sql
-- Copy/paste contents of: create_test_user.sql
```

This creates a test user with:
- **Email**: `test@duelpvp.com`
- **Name**: TestWarrior
- **Starting GP**: 5000

---

## 🎮 How to Test

### Test Mode 1: localStorage (Original Behavior)

**How to login:**
1. Click "Sign in" link
2. Leave email field **empty** (or enter anything except "test@duelpvp.com")
3. Click LOG IN

**What happens:**
- Creates random test user: `test-abc123`
- GP stored in localStorage (can be hacked)
- Toast shows: "LOCALSTORAGE MODE"

**Test this:**
```javascript
// Open DevTools Console
localStorage.setItem('duelpvp_gp', '999999'); // Still works in this mode
// Refresh page - you'll have 999999 GP
```

---

### Test Mode 2: Database (New Secure Mode)

**How to login:**
1. Click "Sign in" link
2. Enter email: `test@duelpvp.com` (or just type `db`)
3. Click LOG IN

**What happens:**
- Logs in as database user: `00000000-0000-0000-0000-000000000001`
- GP fetched from Supabase database
- Toast shows: "DATABASE MODE"
- Shows GP balance from database (should be 5000)

**Test this:**
```javascript
// Open DevTools Console
localStorage.setItem('duelpvp_gp', '999999'); // Won't work!
// Refresh page - GP will reload from database (back to 5000)
```

---

## ✅ What to Verify

### In DATABASE MODE, verify these are FIXED:

#### ✅ Test 1: Can't hack GP balance
```javascript
// DevTools Console
localStorage.setItem('duelpvp_gp', '999999');
// Refresh page
// Expected: Balance loads from database, NOT localStorage
```

#### ✅ Test 2: Negative balance prevented
1. Play a game with 100 GP bet
2. Try to play again with 6000 GP bet (more than your balance)
3. Expected: Error "Insufficient balance"

#### ✅ Test 3: Server validates GP updates
```javascript
// DevTools Console
await updateUserGP(100); // Should work
await updateUserGP(-10000); // Should fail - insufficient balance
```

---

## 🔄 Switching Between Modes

**To switch from localStorage → database:**
1. Logout (or refresh page)
2. Enter email: `test@duelpvp.com`
3. Login

**To switch from database → localStorage:**
1. Logout (or refresh page)
2. Leave email empty
3. Login

---

## 📊 Check Database Values

You can see the actual database values in Supabase:

```sql
-- See test user's current GP
SELECT email, display_name, gp_balance
FROM users
WHERE email = 'test@duelpvp.com';

-- See all GP transactions (coming soon - not implemented yet)
SELECT * FROM mines_games
WHERE user_id = '00000000-0000-0000-0000-000000000001'
ORDER BY created_at DESC;
```

---

## 🐛 Troubleshooting

### Issue: "DATABASE MODE" but GP doesn't persist

**Problem**: SQL migration not run yet

**Solution**: Run `add_gp_balance_system.sql` in Supabase first

---

### Issue: Login shows error

**Problem**: Test user doesn't exist

**Solution**: Run `create_test_user.sql` in Supabase

---

### Issue: Can still hack GP in database mode

**Problem**: Either:
1. SQL functions not created
2. Still in LOCALSTORAGE mode

**Solution**:
1. Check toast message - should say "DATABASE MODE"
2. Verify functions exist in Supabase (run the verify query from migration file)

---

## 🎯 Quick Reference

| Login Email | Mode | GP Storage | Hackable? |
|-------------|------|------------|-----------|
| (empty) | LOCALSTORAGE | localStorage | ✅ Yes (for demo) |
| `test@duelpvp.com` | DATABASE | Supabase | ❌ No (secure!) |
| `db` | DATABASE | Supabase | ❌ No (secure!) |

---

## 🚀 Next Steps After Testing

Once you've verified database mode works:

1. ✅ Remove localStorage fallback (force everyone to use database)
2. ✅ Add real authentication (no more instant test login)
3. ✅ Secure other games (Crash, Blackjack, Trading Sim)
4. ✅ Tighten RLS policies (currently too permissive)

---

**Happy Testing! 🎉**
