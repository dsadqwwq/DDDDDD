# Secure Server-Side Staking Implementation Guide

## Problem
Currently, staking runs client-side in JavaScript which means users can open the browser console and cheat by:
- Manually setting `ovenState.invested` to 1 billion
- Modifying the compound multiplier
- Skipping the timer

## Solution
Move ALL staking logic to the server (Supabase SQL functions).

---

## Step 1: Run the SQL Setup

Copy and paste `add_staking_system.sql` into Supabase SQL Editor and run it.

This creates:
- `stakes` table to track user stakes
- `stake_deposit()` - securely deposits GP
- `get_stake_value()` - calculates current value with compound interest
- `stake_withdraw()` - withdraws with all gains
- `apply_stake_compound()` - server-side compounding

---

## Step 2: Update Frontend Code

Find these 3 functions in `index.html` and replace them:

### Replace depositToOven()

**Find (around line 8637):**
```javascript
async function depositToOven() {
  const amount = parseInt(document.getElementById('ovenDepositAmount').value);
  // ... old client-side logic ...
  ovenState.invested += amount; // ❌ Client-side - can be cheated
}
```

**Replace with:**
```javascript
async function depositToOven() {
  const amount = parseInt(document.getElementById('ovenDepositAmount').value);

  if (isNaN(amount) || amount <= 0) {
    Toast.error('Please enter a valid amount', 'INVALID');
    return;
  }

  if (amount < 100) {
    Toast.error('Minimum stake is 100 GP', 'MINIMUM NOT MET');
    return;
  }

  const userId = localStorage.getItem('duelpvp_user_id');
  if (!userId) {
    Toast.error('Please log in first', 'NOT LOGGED IN');
    return;
  }

  Loading.show('Depositing to stake...');

  try {
    // ✅ Server-side call - secure!
    const { data, error } = await supabase.rpc('stake_deposit', {
      p_user_id: userId,
      p_amount: amount
    });

    Loading.hide();

    if (error || !data || data.length === 0 || !data[0].success) {
      const message = (data && data[0]?.message) || error?.message || 'Deposit failed';
      Toast.error(message, 'DEPOSIT FAILED');
      return;
    }

    document.getElementById('ovenDepositAmount').value = '';
    await updateOvenDisplay();
    Toast.success(`Deposited ${amount.toLocaleString()} GP!`, 'STAKING');

  } catch (e) {
    Loading.hide();
    console.error('Deposit error:', e);
    Toast.error('Unexpected error occurred', 'ERROR');
  }
}
```

### Replace withdrawFromOven()

**Find (around line 8676):**
```javascript
async function withdrawFromOven() {
  if (ovenState.invested <= 0) { // ❌ Client-side check
    Toast.error('No investment to withdraw', 'NO INVESTMENT');
    return;
  }
  const amount = Math.floor(ovenState.invested); // ❌ Can be manipulated
  await updateUserGP(amount); // ❌ Client calculates amount
}
```

**Replace with:**
```javascript
async function withdrawFromOven() {
  const userId = localStorage.getItem('duelpvp_user_id');
  if (!userId) {
    Toast.error('Please log in first', 'NOT LOGGED IN');
    return;
  }

  Loading.show('Checking stake...');

  try {
    // Get current stake value from server
    const { data: stakeData, error: stakeError } = await supabase.rpc('get_stake_value', { p_user_id: userId });

    if (stakeError || !stakeData || stakeData.length === 0 || stakeData[0].current_value === 0) {
      Loading.hide();
      Toast.error('No active stake to withdraw', 'NO STAKE');
      return;
    }

    const amount = stakeData[0].current_value;
    const profit = stakeData[0].profit;

    Loading.hide();

    const confirmed = await Modal.confirm(
      `Withdraw ${amount.toLocaleString()} GP? (Profit: +${profit.toLocaleString()} GP)`,
      'Confirm Withdrawal'
    );
    if (!confirmed) return;

    Loading.show('Withdrawing...');

    // ✅ Server calculates final value and credits GP
    const { data, error } = await supabase.rpc('stake_withdraw', { p_user_id: userId });

    Loading.hide();

    if (error || !data || data.length === 0 || !data[0].success) {
      const message = (data && data[0]?.message) || error?.message || 'Withdrawal failed';
      Toast.error(message, 'WITHDRAW FAILED');
      return;
    }

    await updateOvenDisplay();
    const timerEl = document.getElementById('ovenTimer');
    if (timerEl) timerEl.textContent = 'No active stake';

    Toast.success(`Withdrawn ${amount.toLocaleString()} GP!`, 'SUCCESS');

  } catch (e) {
    Loading.hide();
    console.error('Withdrawal error:', e);
    Toast.error('Unexpected error occurred', 'ERROR');
  }
}
```

### Replace updateOvenDisplay()

**Find (around line 8552):**
```javascript
function updateOvenDisplay() {
  try {
    const userGP = getUserGP();
    // ...
    if (investedEl) investedEl.textContent = Math.floor(ovenState.invested) + ' GP'; // ❌ Client-side
  } catch (e) {
    console.error('Error updating oven display:', e);
  }
}
```

**Replace with:**
```javascript
async function updateOvenDisplay() {
  try {
    const userId = localStorage.getItem('duelpvp_user_id');
    if (!userId) return;

    // Get current balance
    const userGP = await getUserGP();
    const balanceEl = document.getElementById('ovenUserBalance');
    if (balanceEl) balanceEl.textContent = Math.floor(userGP).toLocaleString() + ' GP';

    // ✅ Get stake value from server
    const { data, error } = await supabase.rpc('get_stake_value', { p_user_id: userId });

    if (error) {
      console.error('Failed to get stake value:', error);
      const investedEl = document.getElementById('ovenInvested');
      const valueEl = document.getElementById('ovenCurrentValue');
      if (investedEl) investedEl.textContent = '0 GP';
      if (valueEl) valueEl.textContent = '0 GP';
      return;
    }

    const investedEl = document.getElementById('ovenInvested');
    const valueEl = document.getElementById('ovenCurrentValue');

    if (data && data.length > 0) {
      if (investedEl) investedEl.textContent = (data[0].staked_amount || 0).toLocaleString() + ' GP';
      if (valueEl) valueEl.textContent = (data[0].current_value || 0).toLocaleString() + ' GP';
    } else {
      if (investedEl) investedEl.textContent = '0 GP';
      if (valueEl) valueEl.textContent = '0 GP';
    }

  } catch (e) {
    console.error('Error updating oven display:', e);
  }
}
```

---

## Step 3: Remove Old Client-Side State

**Delete these (around line 8500-8635):**
- `let ovenState = {...}`
- `function loadOvenState()`
- `function saveOvenState()`
- `function startOvenTimer()`
- `function applyCompound()`

These are no longer needed since everything is server-side.

---

## Security Benefits

**Before (Client-Side):**
```javascript
// User can open console and type:
ovenState.invested = 9999999999;
// Instant billionaire! ❌
```

**After (Server-Side):**
```javascript
// User tries to cheat in console:
ovenState.invested = 9999999999;
// ✅ Does nothing! Value is in database, not JavaScript
// Server calculates everything based on timestamps
```

---

## Test It

1. Run the SQL script
2. Update the 3 functions
3. Try staking 1000 GP
4. Wait 1 hour (or modify server time for testing)
5. Withdraw - should be ~1100 GP

If it works, your staking is now 100% cheat-proof!
