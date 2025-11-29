# 🎮 Games System Deployment Guide

## Overview

This guide explains how to deploy the **server-authoritative games system** for Mines, Blackjack, and Crash games. All game logic runs server-side to prevent cheating.

## What's Been Added

### ✅ **New Database Tables**
- `mines_games` - Tracks mines game sessions
- `blackjack_games` - Tracks blackjack game sessions
- `crash_games` - Tracks crash game sessions

### ✅ **New Functions**
**Mines:**
- `mines_start_game(bet_amount, mines_count)` - Start new mines game
- `mines_click_tile(game_id, tile_index)` - Click a tile
- `mines_cashout(game_id)` - Cash out current game

**Blackjack:**
- `blackjack_deal(bet_amount)` - Deal new hand
- `blackjack_hit(game_id)` - Draw another card
- `blackjack_stand(game_id)` - Stand and let dealer play
- `blackjack_end_game(game_id, result)` - Internal function to end game

**Crash:**
- `crash_start_game(bet_amount)` - Place bet for crash round
- `crash_cashout(game_id, multiplier)` - Cash out at current multiplier

**Backward Compatibility:**
- `secure_update_gp()` - Alias for `secure_update_gc()` (frontend compatibility)

## 🚀 Deployment Steps

### 1. Run the Migration in Supabase

```bash
# Option A: Copy/paste into Supabase SQL Editor
# Navigate to your Supabase project → SQL Editor → New Query
# Paste contents of: supabase/migrations/002_add_games_system.sql
# Click "Run"

# Option B: Use Supabase CLI (if you have it set up)
supabase db push
```

### 2. Verify Migration Success

Run this query in Supabase SQL Editor to verify:

```sql
-- Check tables exist
SELECT tablename FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('mines_games', 'blackjack_games', 'crash_games');

-- Check functions exist
SELECT routine_name FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'mines_start_game', 'mines_click_tile', 'mines_cashout',
    'blackjack_deal', 'blackjack_hit', 'blackjack_stand',
    'crash_start_game', 'crash_cashout',
    'secure_update_gp'
  );
```

Expected: All tables and functions should be listed.

### 3. Grant RLS Bypass for Service Role (if needed)

The migration already sets up RLS policies, but if you need service role access:

```sql
GRANT ALL ON mines_games TO service_role;
GRANT ALL ON blackjack_games TO service_role;
GRANT ALL ON crash_games TO service_role;
```

## 🧪 Testing the Games

### Test Mines Game

```sql
-- Start a mines game (logged in user)
SELECT mines_start_game(100, 5);  -- 100 GC bet, 5 mines
-- Returns: { "success": true, "game_id": "...", "new_balance": ... }

-- Click a tile (use game_id from above)
SELECT mines_click_tile('YOUR-GAME-ID', 0);  -- Click tile 0
-- Returns: { "success": true, "result": "safe" | "mine", ... }

-- Cash out (if safe tiles revealed)
SELECT mines_cashout('YOUR-GAME-ID');
-- Returns: { "success": true, "payout": ..., "new_balance": ... }
```

### Test Blackjack

```sql
-- Deal new hand
SELECT blackjack_deal(100);  -- 100 GC bet
-- Returns: { "success": true, "game_id": "...", "player_hand": [...], ... }

-- Hit (draw card)
SELECT blackjack_hit('YOUR-GAME-ID');
-- Returns: { "success": true, "new_card": {...}, "player_value": ... }

-- Stand (dealer plays)
SELECT blackjack_stand('YOUR-GAME-ID');
-- Returns: { "success": true, "result": "player_win" | "dealer_win" | "push", ... }
```

### Test Crash

```sql
-- Start crash round
SELECT crash_start_game(100);  -- 100 GC bet
-- Returns: { "success": true, "game_id": "...", "crash_point": 2.45 }

-- Cash out at 1.5x
SELECT crash_cashout('YOUR-GAME-ID', 1.5);
-- Returns: { "success": true, "payout": 150, ... }

-- Try to cash out after crash (should fail)
SELECT crash_cashout('YOUR-GAME-ID', 3.0);  -- If crash_point was 2.45
-- Returns: { "success": false, "error": "Too late! Game crashed..." }
```

## 🔒 Security Features

### ✅ **Server-Authoritative**
- **Mine positions** generated server-side (hidden from client)
- **Card deck** shuffled server-side
- **Crash points** pre-generated server-side

### ✅ **Prevents Cheating**
- No direct table access (RLS policies block)
- All mutations through secure functions
- JWT authentication required
- Balance validation (can't bet more than you have)

### ✅ **Audit Trail**
All transactions logged to `gc_transactions`:
```sql
-- View recent game transactions
SELECT * FROM gc_transactions
WHERE transaction_type IN ('game_win', 'game_loss')
ORDER BY created_at DESC
LIMIT 20;
```

## 📊 How It Works

### Mines Game Flow
1. Player calls `mines_start_game(bet, mines)` → Bet deducted, mines generated
2. Server stores **hidden** mine positions
3. Player calls `mines_click_tile(game_id, index)` → Server checks if mine
4. If safe: multiplier increases, player can continue or cashout
5. If mine: game over, all mines revealed
6. Player calls `mines_cashout(game_id)` → Payout = bet × multiplier

### Blackjack Flow
1. Player calls `blackjack_deal(bet)` → Bet deducted, cards dealt
2. Server shuffles deck, deals 2 to player, 1 visible + 1 hidden to dealer
3. Player calls `blackjack_hit(game_id)` repeatedly → Draw cards
4. Player calls `blackjack_stand(game_id)` → Dealer reveals and plays
5. Server determines winner, pays out accordingly

### Crash Flow
1. Player calls `crash_start_game(bet)` → Bet deducted, crash point generated
2. Server returns **hidden** crash_point to track (client shows multiplier increasing)
3. Player calls `crash_cashout(game_id, multiplier)` when ready
4. Server validates multiplier < crash_point
5. If valid: payout = bet × multiplier
6. If too late (multiplier >= crash_point): game lost

## 🐛 Troubleshooting

### "Function does not exist" errors
```bash
# Re-run the migration
# Make sure you're connected to the right Supabase project
```

### "Not authenticated" errors
```bash
# Check user is logged in with valid JWT
# Frontend should be calling supabase.auth.getSession()
```

### Balance not updating
```sql
-- Check if transaction was logged
SELECT * FROM gc_transactions
WHERE user_id = 'YOUR-USER-ID'
ORDER BY created_at DESC
LIMIT 10;

-- Check user's current balance
SELECT gc_balance FROM users WHERE id = 'YOUR-USER-ID';
```

### Games not visible in table
```sql
-- Check RLS policies
SELECT * FROM mines_games WHERE user_id = 'YOUR-USER-ID';

-- If empty but games were created, RLS might be blocking
-- Temporarily disable to debug (DON'T DO IN PRODUCTION)
ALTER TABLE mines_games DISABLE ROW LEVEL SECURITY;
```

## 🎯 Next Steps: Frontend Integration

The current frontend games are **client-side only**. You'll need to update them to call the new server functions:

### Example: Update Mines Game (index.html)

**Before (client-side, insecure):**
```javascript
async function startMinesGame() {
  updateUserGC(-betAmount, 'mines');  // Client-side deduction ❌
  minesGameState.minePositions = generateMinePositions(count);  // Client knows mines ❌
}
```

**After (server-side, secure):**
```javascript
async function startMinesGame() {
  const { data, error } = await supabase.rpc('mines_start_game', {
    p_bet_amount: betAmount,
    p_mines_count: minesCount
  });

  if (data.success) {
    minesGameState.gameId = data.game_id;  // Store game ID
    minesGameState.minePositions = null;   // Don't know mines until game ends ✅
  }
}

async function handleMinesTileClick(index) {
  const { data, error } = await supabase.rpc('mines_click_tile', {
    p_game_id: minesGameState.gameId,
    p_tile_index: index
  });

  if (data.result === 'mine') {
    // Reveal all mines from server response
    showMines(data.mine_positions);
  }
}
```

## ✅ Verification Checklist

- [ ] Migration ran successfully in Supabase
- [ ] All 3 game tables exist
- [ ] All 9 game functions exist
- [ ] `secure_update_gp` alias created
- [ ] RLS policies active on game tables
- [ ] Test games work via SQL queries
- [ ] `gc_transactions` logging game wins/losses
- [ ] No errors in Supabase logs

## 📝 Notes

- **Backward compatibility:** The `secure_update_gp()` function was added so existing frontend code won't break
- **GP vs GC:** The system now uses "GC" (Gold Coins) instead of "GP". The column is `gc_balance` in users table.
- **Transaction logging:** All game bets and payouts are logged to `gc_transactions` with `transaction_type` = `'game_win'` or `'game_loss'`
- **Provably fair:** Crash game uses seeded RNG for transparency

## 🔗 Related Files

- Migration: `supabase/migrations/002_add_games_system.sql`
- Original schema: `supabase/migrations/001_gc_quest_system.sql`
- Frontend games: `index.html` (lines 9959+ for Mines, 10247+ for Blackjack, 8269+ for Crash)

---

**Questions?** Check the Supabase logs or test the functions directly in SQL Editor first!
