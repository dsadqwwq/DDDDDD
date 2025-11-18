# 🔒 RLS Security Guide for Anonymous Auth

## ⚠️ THE PROBLEM

With anonymous authentication enabled, your Supabase project currently has **INSECURE** policies:

```sql
CREATE POLICY "Allow all for users" ON users FOR ALL USING (true);
CREATE POLICY "Allow all for codes" ON codes FOR ALL USING (true);
```

This means **ANY anonymous user can:**
- ❌ Read ALL users' data (emails, wallets, GP balances)
- ❌ Modify ANY user's GP balance directly
- ❌ Change ANY user's display name
- ❌ Mark ANY code as used
- ❌ View other users' private information

**This is a critical security vulnerability!**

---

## ✅ THE SOLUTION

Run `secure_rls_policies.sql` to lock down your database with proper Row Level Security.

### What Gets Secured:

#### 1. **USERS Table** - Only Access Your Own Data

**Before (INSECURE):**
```sql
-- Any user can see everyone's data
SELECT * FROM users; -- Returns ALL users ❌
```

**After (SECURE):**
```sql
-- Users can only see their own profile
SELECT * FROM users WHERE auth.uid() = auth_user_id; -- Only YOUR data ✅
```

**Locked Down:**
- ✅ Users can only VIEW their own profile
- ✅ Users can only UPDATE their own display_name
- ✅ Users CANNOT update gp_balance directly (must use RPC functions)
- ✅ Users CANNOT create new users directly
- ✅ Users CANNOT delete any users

---

#### 2. **CODES Table** - Prevent Code Abuse

**Before (INSECURE):**
```sql
-- Any user can mark ANY code as used
UPDATE codes SET used_by = 'my-user-id' WHERE code = 'ANYCODE'; -- ❌
```

**After (SECURE):**
```sql
-- Only RPC functions can update codes
UPDATE codes ... -- BLOCKED ✅
-- Must use register_with_wallet() function instead
```

**Locked Down:**
- ✅ Users can VIEW unused codes (needed for registration)
- ✅ Users can view codes they created/used
- ✅ Users CANNOT update codes directly
- ✅ Users CANNOT insert codes directly
- ✅ Users CANNOT delete codes

---

#### 3. **GP_TRANSACTIONS Table** - Audit Trail Protection

**Before (INSECURE):**
```sql
-- Users could potentially delete transaction history
DELETE FROM gp_transactions WHERE user_id = 'my-id'; -- ❌
```

**After (SECURE):**
```sql
-- Read-only for users, write-only for RPC functions
DELETE FROM gp_transactions ... -- BLOCKED ✅
```

**Locked Down:**
- ✅ Users can VIEW their own transactions
- ✅ Users CANNOT insert transactions directly
- ✅ Users CANNOT modify transactions
- ✅ Users CANNOT delete transactions

---

#### 4. **MINES_GAMES Table** - Prevent Game Cheating

**Before (INSECURE):**
```sql
-- Users could modify game state to cheat
UPDATE mines_games SET result = 'win' WHERE id = 'game-id'; -- ❌
```

**After (SECURE):**
```sql
-- All game operations go through RPC functions
UPDATE mines_games ... -- BLOCKED ✅
```

**Locked Down:**
- ✅ Users can VIEW their own games
- ✅ Users CANNOT create games directly
- ✅ Users CANNOT modify game results
- ✅ Users CANNOT delete games

---

## 🔐 How RLS Policies Work with Anonymous Auth

### Anonymous User Flow:

1. **User connects wallet** → Signs in anonymously
2. **Supabase creates anonymous auth session** → Gets JWT token
3. **JWT contains `auth.uid()`** → Unique user identifier
4. **User record linked** → `users.auth_user_id = auth.uid()`
5. **RLS policies enforce** → User can only access their own data

### Policy Example:

```sql
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT
  USING (
    auth.uid() = auth_user_id  -- Only if auth ID matches
  );
```

**What this does:**
- When user queries `SELECT * FROM users`
- Supabase automatically adds: `WHERE auth.uid() = auth_user_id`
- User only sees their own row
- Other users' data is invisible

---

## 🛡️ SECURITY DEFINER Functions Bypass RLS

Your RPC functions are marked `SECURITY DEFINER`:

```sql
CREATE FUNCTION secure_update_gp(...)
LANGUAGE plpgsql
SECURITY DEFINER  -- <-- This bypasses RLS
```

**This means:**
- ✅ Users call: `secure_update_gp(-100, 'game', 'mines')`
- ✅ Function runs with elevated privileges
- ✅ Function validates business logic (prevent negative balance)
- ✅ Function updates GP (bypasses RLS)
- ✅ User gets result back

**Why this is safe:**
- Function contains validation logic
- Users can't bypass the function to update GP directly
- All GP changes are logged in gp_transactions

---

## 📝 Installation Steps

### 1. **Run the Secure RLS Migration**

```sql
-- In Supabase SQL Editor, run:
-- File: secure_rls_policies.sql
```

### 2. **Verify Policies Were Created**

After running the migration, you should see output like:

```
┌─────────────┬───────────────────┬──────────────┐
│ schemaname  │ tablename         │ policy_count │
├─────────────┼───────────────────┼──────────────┤
│ public      │ users             │ 4            │
│ public      │ codes             │ 5            │
│ public      │ gp_transactions   │ 4            │
│ public      │ mines_games       │ 4            │
└─────────────┴───────────────────┴──────────────┘

✅ RLS Policies Secured!
```

### 3. **Test Security**

Open browser console and try to cheat:

```javascript
// Try to see all users (should only see yourself)
const { data } = await supabase.from('users').select('*');
console.log(data); // Should only show YOUR user

// Try to update GP directly (should fail)
const { error } = await supabase
  .from('users')
  .update({ gp_balance: 999999 })
  .eq('id', 'your-user-id');
console.log(error); // Should show "new row violates row-level security policy"

// Try to use secure function (should work)
const { data: result } = await supabase.rpc('secure_update_gp', {
  p_amount: 100,
  p_transaction_type: 'reward'
});
console.log(result); // Should work ✅
```

---

## 🎯 What Anonymous Users CAN Do (Allowed)

✅ **View their own profile**
```sql
SELECT * FROM users WHERE auth_user_id = auth.uid();
```

✅ **Update their own display name**
```sql
UPDATE users SET display_name = 'NewName' WHERE auth_user_id = auth.uid();
```

✅ **View unused invite codes**
```sql
SELECT * FROM codes WHERE used_by IS NULL;
```

✅ **Use RPC functions**
```sql
SELECT secure_get_gp();
SELECT secure_update_gp(-100, 'game', 'mines');
SELECT register_with_wallet('0x...', 'WarriorName', 'CODE123');
```

---

## 🚫 What Anonymous Users CANNOT Do (Blocked)

❌ **View other users' profiles**
```sql
SELECT * FROM users WHERE id != current_user_id; -- Returns empty
```

❌ **Update GP balance directly**
```sql
UPDATE users SET gp_balance = 999999 WHERE id = current_user_id; -- BLOCKED
```

❌ **Modify invite codes**
```sql
UPDATE codes SET used_by = NULL WHERE code = 'USED_CODE'; -- BLOCKED
```

❌ **Delete transaction history**
```sql
DELETE FROM gp_transactions WHERE user_id = current_user_id; -- BLOCKED
```

❌ **Modify game results**
```sql
UPDATE mines_games SET result = 'win' WHERE id = game_id; -- BLOCKED
```

---

## 🧪 Testing Checklist

After running the migration, test these scenarios:

### ✅ Test 1: Can only see own data
- [ ] Login with wallet A
- [ ] Query users table → Should only see user A
- [ ] Login with wallet B
- [ ] Query users table → Should only see user B

### ✅ Test 2: Cannot modify GP directly
- [ ] Try: `supabase.from('users').update({ gp_balance: 999999 })`
- [ ] Should get RLS policy error

### ✅ Test 3: RPC functions still work
- [ ] Call `secure_get_gp()` → Should return balance
- [ ] Call `secure_update_gp(100)` → Should update balance
- [ ] Call `secure_update_gp(-999999)` → Should fail (insufficient balance)

### ✅ Test 4: Cannot see other users' codes
- [ ] Login as user A
- [ ] Try to view codes used by user B
- [ ] Should not see them (or only see unused codes)

### ✅ Test 5: Registration still works
- [ ] Try to register new user with wallet
- [ ] Should create user successfully
- [ ] Should mark code as used
- [ ] Should generate 3 new codes

---

## 📊 Security Comparison

| Feature | Before (INSECURE) | After (SECURE) |
|---------|------------------|----------------|
| View own data | ✅ | ✅ |
| View others' data | ✅ ❌ | ❌ |
| Update own profile | ✅ | ✅ |
| Update others' profiles | ✅ ❌ | ❌ |
| Modify GP directly | ✅ ❌ | ❌ |
| Modify GP via RPC | ✅ | ✅ |
| Delete transactions | ✅ ❌ | ❌ |
| Cheat in games | ✅ ❌ | ❌ |

---

## 🚨 Critical Security Principles

1. **Never trust the client** - All validation happens server-side
2. **Use RPC functions** - They enforce business logic
3. **RLS policies** - Prevent direct table access
4. **Audit trails** - Log all GP transactions
5. **SECURITY DEFINER** - Functions bypass RLS safely

---

## 🎓 Summary

**Before this migration:**
- Anonymous users could read/modify ANY data
- GP balance could be changed in DevTools
- Game results could be manipulated
- Transaction history could be deleted

**After this migration:**
- Anonymous users can ONLY access their own data
- GP balance can ONLY be modified through secure RPC functions
- Game logic is server-side validated
- Transaction history is read-only for users

**Your app is now secure!** 🎉
