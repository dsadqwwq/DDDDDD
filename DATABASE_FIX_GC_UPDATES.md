# Fix GC Balance Updates Not Persisting to Database

## Problem
GC balance updates are showing on the website frontend but not persisting to the Supabase database. This affects:
- Quest rewards not being credited to database
- Game wins/losses not updating database balance
- Leaderboard rankings not reflecting actual earnings

## Root Cause
The frontend calls several RPC (Remote Procedure Call) functions to update GC, but these functions either don't exist or aren't properly updating the `gc_balance` column in the `users` table.

## Required RPC Functions

Your Supabase database needs the following RPC functions. Run these in your **Supabase SQL Editor**:

### 1. `secure_update_gc` - JWT-based GC update (used by games)

```sql
CREATE OR REPLACE FUNCTION secure_update_gc(
  p_amount INTEGER,
  p_transaction_type TEXT,
  p_game_type TEXT DEFAULT NULL
)
RETURNS TABLE(success BOOLEAN, new_balance BIGINT, message TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_new_balance BIGINT;
BEGIN
  -- Get user ID from JWT (auth.uid())
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 0::BIGINT, 'Not authenticated'::TEXT;
    RETURN;
  END IF;

  -- Update GC balance
  UPDATE users
  SET gc_balance = GREATEST(gc_balance + p_amount, 0),
      updated_at = NOW()
  WHERE id = v_user_id
  RETURNING gc_balance INTO v_new_balance;

  -- Log transaction (optional - if you have a transactions table)
  -- INSERT INTO gc_transactions (user_id, amount, transaction_type, game_type, created_at)
  -- VALUES (v_user_id, p_amount, p_transaction_type, p_game_type, NOW());

  RETURN QUERY SELECT true, v_new_balance, 'Balance updated successfully'::TEXT;
END;
$$;
```

### 2. `update_user_gc` - Fallback GC update with user_id parameter

```sql
CREATE OR REPLACE FUNCTION update_user_gc(
  p_user_id UUID,
  p_amount INTEGER,
  p_transaction_type TEXT,
  p_game_type TEXT DEFAULT NULL
)
RETURNS TABLE(success BOOLEAN, new_balance BIGINT, message TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_new_balance BIGINT;
BEGIN
  -- Update GC balance
  UPDATE users
  SET gc_balance = GREATEST(gc_balance + p_amount, 0),
      updated_at = NOW()
  WHERE id = p_user_id
  RETURNING gc_balance INTO v_new_balance;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 0::BIGINT, 'User not found'::TEXT;
    RETURN;
  END IF;

  -- Log transaction (optional)
  -- INSERT INTO gc_transactions (user_id, amount, transaction_type, game_type, created_at)
  -- VALUES (p_user_id, p_amount, p_transaction_type, p_game_type, NOW());

  RETURN QUERY SELECT true, v_new_balance, 'Balance updated successfully'::TEXT;
END;
$$;
```

### 3. `complete_manual_quest` - For manual quests (Twitter, etc.)

```sql
CREATE OR REPLACE FUNCTION complete_manual_quest(
  p_quest_id TEXT,
  p_user_id UUID
)
RETURNS TABLE(success BOOLEAN, reward INTEGER, error TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_quest_reward INTEGER;
  v_already_completed BOOLEAN;
BEGIN
  -- Check if quest already completed
  SELECT EXISTS(
    SELECT 1 FROM user_quest_progress
    WHERE user_id = p_user_id AND quest_id = p_quest_id AND is_claimed = true
  ) INTO v_already_completed;

  IF v_already_completed THEN
    RETURN QUERY SELECT false, 0, 'Quest already completed'::TEXT;
    RETURN;
  END IF;

  -- Get quest reward
  SELECT gc_reward INTO v_quest_reward
  FROM quests
  WHERE id = p_quest_id;

  IF v_quest_reward IS NULL THEN
    RETURN QUERY SELECT false, 0, 'Quest not found'::TEXT;
    RETURN;
  END IF;

  -- Mark quest as completed and claimed
  INSERT INTO user_quest_progress (user_id, quest_id, is_completed, is_claimed, completed_at)
  VALUES (p_user_id, p_quest_id, true, true, NOW())
  ON CONFLICT (user_id, quest_id)
  DO UPDATE SET
    is_completed = true,
    is_claimed = true,
    completed_at = NOW();

  -- Award GC
  UPDATE users
  SET gc_balance = gc_balance + v_quest_reward,
      updated_at = NOW()
  WHERE id = p_user_id;

  RETURN QUERY SELECT true, v_quest_reward, NULL::TEXT;
END;
$$;
```

### 4. `claim_quest_reward` - For claiming completed quests

```sql
CREATE OR REPLACE FUNCTION claim_quest_reward(
  p_quest_id TEXT,
  p_user_id UUID
)
RETURNS TABLE(success BOOLEAN, reward INTEGER, error TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_quest_reward INTEGER;
  v_is_completed BOOLEAN;
  v_is_claimed BOOLEAN;
BEGIN
  -- Check quest status
  SELECT is_completed, is_claimed
  INTO v_is_completed, v_is_claimed
  FROM user_quest_progress
  WHERE user_id = p_user_id AND quest_id = p_quest_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 0, 'Quest progress not found'::TEXT;
    RETURN;
  END IF;

  IF NOT v_is_completed THEN
    RETURN QUERY SELECT false, 0, 'Quest not completed yet'::TEXT;
    RETURN;
  END IF;

  IF v_is_claimed THEN
    RETURN QUERY SELECT false, 0, 'Reward already claimed'::TEXT;
    RETURN;
  END IF;

  -- Get quest reward
  SELECT gc_reward INTO v_quest_reward
  FROM quests
  WHERE id = p_quest_id;

  -- Mark as claimed
  UPDATE user_quest_progress
  SET is_claimed = true,
      claimed_at = NOW()
  WHERE user_id = p_user_id AND quest_id = p_quest_id;

  -- Award GC
  UPDATE users
  SET gc_balance = gc_balance + v_quest_reward,
      updated_at = NOW()
  WHERE id = p_user_id;

  RETURN QUERY SELECT true, v_quest_reward, NULL::TEXT;
END;
$$;
```

### 5. `get_user_gc` - Fetch current GC balance

```sql
CREATE OR REPLACE FUNCTION get_user_gc(p_user_id UUID)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_balance BIGINT;
BEGIN
  SELECT gc_balance INTO v_balance
  FROM users
  WHERE id = p_user_id;

  RETURN COALESCE(v_balance, 0);
END;
$$;
```

## Verify Database Schema

Make sure your `users` table has the `gc_balance` column:

```sql
-- Check if column exists
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'gc_balance';

-- If it doesn't exist, add it:
ALTER TABLE users ADD COLUMN IF NOT EXISTS gc_balance BIGINT DEFAULT 0;
```

## Check RLS (Row Level Security) Policies

Make sure RLS policies allow authenticated users to read their own balance:

```sql
-- Enable RLS on users table if not already enabled
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Allow users to read their own data
CREATE POLICY "Users can read own data" ON users
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- The RPC functions use SECURITY DEFINER so they bypass RLS
```

## Testing

After running the SQL above, test in Supabase SQL Editor:

```sql
-- Test getting GC (replace with actual user UUID)
SELECT get_user_gc('YOUR-USER-UUID-HERE');

-- Test updating GC (replace with actual user UUID)
SELECT * FROM update_user_gc(
  'YOUR-USER-UUID-HERE',
  100,
  'test',
  'manual_test'
);

-- Verify the update
SELECT id, display_name, gc_balance FROM users WHERE id = 'YOUR-USER-UUID-HERE';
```

## Common Issues

1. **"Function does not exist" error**
   - Run all the CREATE FUNCTION SQL above

2. **"Permission denied" error**
   - Check RLS policies
   - Ensure functions use `SECURITY DEFINER`

3. **Updates show in frontend but not database**
   - Clear your browser cache (GC might be cached)
   - Check that the RPC functions are actually calling UPDATE on the users table

4. **Auth errors**
   - Make sure user is properly authenticated
   - Check that `auth.uid()` returns a valid UUID

## Frontend Code Status

✅ The frontend code is already correctly calling these functions:
- Games use `secure_update_gc()`
- Quest completions use `complete_manual_quest()` or `claim_quest_reward()`
- Balance fetching uses `get_user_gc()` and direct table queries

Once you create these RPC functions in Supabase, GC updates will persist to the database immediately.
