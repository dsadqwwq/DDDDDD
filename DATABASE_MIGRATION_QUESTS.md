# Database Migration Required - Quest System Updates

## Overview
The frontend code has been updated to support new quests and remove deprecated ones. The following database changes are required for the new quest system to work properly.

## Required Database Changes

### 1. Add New Quest: `retweet_jan_2025`

Add this quest to your Supabase `quests` table:

```sql
INSERT INTO quests (id, name, description, gc_reward, quest_type, is_active, target_count)
VALUES (
  'retweet_jan_2025',
  'Retweet & Earn',
  'Retweet our latest post on X',
  1000,
  'manual',
  true,
  1
);
```

**Quest Details:**
- **Reward:** 1000 GC
- **Type:** Manual (requires user submission)
- **Target Post:** https://x.com/Duelpvp/status/1998705426238509128

### 2. Disable Old Quests (Keep for Completed Users)

Set these quests to inactive so they no longer appear for new users, but remain in history for users who already completed them:

```sql
-- Disable invite quest
UPDATE quests SET is_active = false WHERE id = 'invite_used';

-- Disable old like & retweet quest
UPDATE quests SET is_active = false WHERE id = 'like_retweet';

-- Disable NFT holder quests
UPDATE quests SET is_active = false WHERE id IN ('bunnz_holder', 'fluffle_holder', 'megalio_holder');
```

### 3. Verify Active Quests

After migration, these should be the only active quests:

```sql
SELECT id, name, gc_reward, is_active
FROM quests
WHERE is_active = true
ORDER BY gc_reward DESC;
```

Expected results:
- `retweet_jan_2025` - Retweet & Earn - 1000 GC
- `first_login` - First Steps - 500 GC
- `twitter_follow` - Follow Us - 500 GC

## Frontend Code Status

✅ Frontend code is already in place:
- Handler function `openRetweetJan2025Quest()` created
- Quest button rendering logic updated
- Quest icon (🔄) mapped
- URL target set to correct Twitter post

## Testing Checklist

After running the migration:

- [ ] New users see only 3 active quests (first_login, retweet_jan_2025, twitter_follow)
- [ ] Users who completed old quests can still see them in "Completed" tab
- [ ] Clicking "START QUEST" on retweet quest opens https://x.com/Duelpvp/status/1998705426238509128
- [ ] Completing retweet quest awards 1000 GC
- [ ] Old quests (invite_used, like_retweet, NFT holders) no longer appear for new users

## Notes

- The `get_user_quests` RPC function should automatically handle filtering by `is_active` flag
- Users who already completed deprecated quests will keep their rewards and completion status
- Handler functions for old quests are preserved in the frontend for backwards compatibility
