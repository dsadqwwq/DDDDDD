# Diagnose Why Some Users' GC Doesn't Update

## Problem
Some users play games but their GC balance doesn't update in the database.

## Root Cause
The `secure_update_gc()` RPC function requires a valid Supabase JWT auth session. If the session expires:
- Frontend localStorage shows user as "logged in"
- But `auth.uid()` returns NULL
- RPC function returns "Not authenticated"
- Falls back to `update_user_gc()` which also requires valid auth

## How to Diagnose for Affected Users

**Ask affected users to:**

1. Open browser console (F12)
2. Play a game (win or lose)
3. Look for these console messages:

```
[GC Update] Session check before RPC: {hasSession: false, ...}
[GC Update] RPC result: {error: ..., data: null}
```

If `hasSession: false` → Their Supabase auth session expired

## Quick Test

Run this in browser console while logged in:

```javascript
const { data: { session } } = await supabase.auth.getSession();
console.log('Active session:', !!session, session?.user?.id);
```

If it shows `Active session: false` → No JWT token, GC won't update

## The Fix Options

### Option 1: Enable Auto-Refresh (Recommended)

Supabase client should auto-refresh sessions, but check that it's enabled:

In `script.js` line 5-11, verify:
```javascript
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    autoRefreshToken: true,  // ✅ Should be true
    persistSession: true,     // ✅ Should be true
    detectSessionInUrl: false
  }
});
```

### Option 2: Manual Session Refresh

Add periodic session check:

```javascript
// Check session every 30 minutes
setInterval(async () => {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) {
    console.log('Session expired, need to re-login');
    // Could trigger re-authentication here
  }
}, 30 * 60 * 1000);
```

### Option 3: Modify RPC to Accept user_id Fallback

Update the RPC function to also work with `p_user_id` parameter when JWT is not available.

## Temporary Workaround for Affected Users

If a user's GC stops updating:
1. Ask them to logout completely
2. Clear browser cache/localStorage
3. Login again (this creates fresh auth session)
4. GC should update properly now

## Prevention

Set longer JWT expiry in Supabase Dashboard:
1. Go to Authentication → Settings
2. JWT Expiry → Set to max (e.g., 604800 seconds = 7 days)
3. Refresh Token Rotation → Enable

This reduces how often sessions expire.
