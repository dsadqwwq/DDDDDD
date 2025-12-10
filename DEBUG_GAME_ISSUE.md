# Debug Why Games Don't Work on Live

## Quick Test

Have someone on the **LIVE** site open browser console (F12) and run:

```javascript
// Check if there's an auth session
const { data: { session } } = await supabase.auth.getSession();
console.log('Has auth session:', !!session);
console.log('Auth user ID:', session?.user?.id);

// Check localStorage user ID
const userId = localStorage.getItem('duelpvp_user_id');
console.log('localStorage user ID:', userId);

// Try to call the function manually
const testResult = await supabase.rpc('secure_update_gc', {
  p_amount: 100,
  p_transaction_type: 'test',
  p_game_type: 'test'
});
console.log('Test RPC result:', testResult);
```

## Expected Results

**If it works (like on preview):**
```
Has auth session: true
Auth user ID: some-uuid-here
localStorage user ID: some-uuid-here
Test RPC result: {data: [{new_balance: ..., success: true, message: "Success"}], error: null}
```

**If it's broken (like on live):**
```
Has auth session: false   ← THIS IS THE PROBLEM
Auth user ID: undefined
localStorage user ID: some-uuid-here
Test RPC result: {data: [{new_balance: 0, success: false, message: "Not authenticated"}], error: null}
```

## The Real Fix

If the test shows `Has auth session: false`, then the issue is:

**Users on live don't have Supabase auth sessions**

This means either:
1. Anonymous auth is disabled on live Supabase
2. Auth sessions expired and aren't refreshing
3. Users logged in before anonymous auth was enabled

### Solution A: Enable Anonymous Auth

1. Go to your LIVE Supabase project
2. **Authentication** → **Providers**
3. Find **Anonymous** → **Enable it**
4. Save

### Solution B: Force Users to Re-login

Tell users to:
1. Logout
2. Clear browser cache
3. Login again

This will create fresh auth sessions.

### Solution C: Make Function Work Without Auth

Run `SIMPLE_FIX_GAMES.sql` which I created, but modify it to not require auth at all (less secure but will work).
