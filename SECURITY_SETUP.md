# Secure GP System Deployment Guide

## Overview
This update prevents script kiddies from cheating by exploiting client-side GP functions.

## What Changed

### Security Improvements
1. **JWT-Based Authentication**: GP functions now get user ID from the JWT token, not client parameters
2. **Transaction Logging**: All GP changes are logged with game type, amount, and timestamps
3. **Fallback Support**: Code works with both old and new database functions during migration

### Old (INSECURE)
```javascript
// User could call this with ANY user_id!
supabase.rpc('update_user_gp', {
  p_user_id: 'someone-elses-uuid',  // ❌ Can target any user!
  p_amount: 1000000                  // ❌ Can add unlimited GP!
})
```

### New (SECURE)
```javascript
// User ID comes from JWT - can only modify their own balance!
supabase.rpc('secure_update_gp', {
  p_amount: 1000,        // ✅ Limited to ±100k per transaction
  p_transaction_type: 'game_win',
  p_game_type: 'crash'   // ✅ All transactions logged
})
// Server gets user_id from auth.uid() - can't be spoofed!
```

## Deployment Steps

### 1. Run SQL Migration

Go to your Supabase dashboard → SQL Editor and run:

```bash
# Copy contents of secure_gp_system.sql
```

Or use Supabase CLI:
```bash
supabase db push
```

### 2. Verify Setup

Run this in SQL Editor to confirm:
```sql
SELECT
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('secure_update_gp', 'secure_get_gp');
```

You should see both functions listed.

### 3. Test Transaction Logging

After playing a game, check logs:
```sql
SELECT
  user_id,
  amount,
  balance_before,
  balance_after,
  transaction_type,
  game_type,
  created_at
FROM gp_transactions
ORDER BY created_at DESC
LIMIT 10;
```

### 4. Deploy Client Code

The client code (index.html) is already updated with:
- ✅ Secure function calls
- ✅ Fallback to old functions during migration
- ✅ Game type tracking for all transactions

Simply push to your hosting service.

## How It Prevents Cheating

### Before (Vulnerable)
```javascript
// Anyone could open console and type:
updateUserGP(1000000)  // Add 1M GP ❌

// Or worse:
supabase.rpc('update_user_gp', {
  p_user_id: 'victim-uuid',
  p_amount: -1000000  // Steal from others! ❌
})
```

### After (Secure)
```javascript
// Trying to cheat:
supabase.rpc('secure_update_gp', {
  p_amount: 1000000  // ❌ Rejected: "Amount too large"
})

// Server-side checks:
// 1. Gets user_id from JWT (can't be faked)
// 2. Validates amount (max ±100k per transaction)
// 3. Prevents negative balance
// 4. Logs everything for audit trail
```

## Transaction Audit

View any user's transaction history:
```sql
SELECT * FROM gp_transactions
WHERE user_id = 'user-uuid-here'
ORDER BY created_at DESC;
```

## Rollback (If Needed)

If something breaks, the code falls back to old functions automatically.
To fully rollback:

```sql
-- Remove new functions
DROP FUNCTION IF EXISTS secure_update_gp;
DROP FUNCTION IF EXISTS secure_get_gp;
```

Client code will automatically use old `update_user_gp` and `get_user_gp`.

## Additional Security Recommendations

1. **Enable RLS on users table**:
```sql
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only view own data" ON users
  FOR SELECT USING (auth.uid() = id);
```

2. **Add rate limiting** (optional):
   - Implement in `secure_update_gp` function
   - Track requests per minute/hour
   - Block suspicious patterns

3. **Monitor logs regularly** for suspicious activity:
   - Multiple large transactions in short time
   - Unusual transaction patterns
   - Balance discrepancies

## Support

If you encounter issues:
1. Check Supabase logs for function errors
2. Verify JWT tokens are being sent correctly
3. Test with a test account first
4. Check browser console for client-side errors
