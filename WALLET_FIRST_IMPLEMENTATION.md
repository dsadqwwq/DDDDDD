# Wallet-First Registration Implementation Guide

## New Flow
1. **Code Entry** → Validates invite code
2. **Wallet Connect** → User connects wallet + signs message
3. **Warrior Name** → User chooses display name
4. **Complete** → Account created with wallet as primary ID

---

## Step 1: Run Database Migration

Copy `wallet_first_auth.sql` into Supabase SQL Editor and run it.

This will:
- Make email optional in users table
- Add wallet_address uniqueness constraint
- Create `register_with_wallet()` function

---

## Step 2: Update Frontend Code

### A. Update handleJoin() Function

**Find (around line 6119):**
```javascript
async function handleJoin() {
  const codeInput = document.getElementById('code');
  const code = codeInput.value.trim().toUpperCase();

  clearError('codeError');

  if (!code) {
    showError('codeError', 'Please enter an access code');
    return;
  }

  // Validate code exists in database and is unused
  Loading.show('Validating access code...');

  const { data: codeData, error: codeError } = await supabase
    .from('codes')
    .select('*')
    .eq('code', code)
    .is('used_by', null)
    .single();

  Loading.hide();

  if (codeError || !codeData) {
    showError('codeError', 'Invalid or already used access code');
    return;
  }

  // Code is valid, proceed to registration
  swapContent('register', code);
}
```

**Replace with:**
```javascript
async function handleJoin() {
  const codeInput = document.getElementById('code');
  const code = codeInput.value.trim().toUpperCase();

  clearError('codeError');

  if (!code) {
    showError('codeError', 'Please enter an access code');
    return;
  }

  // Validate code exists in database and is unused
  Loading.show('Validating access code...');

  const { data: codeData, error: codeError } = await supabase
    .from('codes')
    .select('*')
    .eq('code', code)
    .is('used_by', null)
    .single();

  Loading.hide();

  if (codeError || !codeData) {
    showError('codeError', 'Invalid or already used access code');
    return;
  }

  // Code is valid, proceed to wallet connect
  swapContent('walletConnect', code);
}
```

### B. Add Wallet Connect Screen to swapContent()

**Find the swapContent() function and add this case after 'home':**

```javascript
} else if (newContent === 'walletConnect') {
  panelContent.style.display = 'block';
  dashboardContent.style.display = 'none';
  pageContainer.classList.add('bottom-aligned');
  pageContainer.classList.remove('center-aligned');

  panelContent.innerHTML = `
    <div class="panel-header">
      <div class="warrior-title">CONNECT WALLET</div>
      <div class="sub-text">Sign to verify ownership • No gas fees</div>
    </div>

    <div class="wallet-connect-container" style="text-align:center;padding:40px 20px;">
      <div style="font-size:64px;margin-bottom:20px;">🔐</div>
      <div style="font-family:'Press Start 2P',monospace;font-size:12px;color:var(--gold);margin-bottom:12px;">
        SECURE AUTHENTICATION
      </div>
      <div style="font-family:Inter,system-ui,Arial;font-size:14px;color:#a0a8b0;margin-bottom:30px;line-height:1.6;">
        Connect your wallet to continue.<br>
        You'll be asked to sign a message to prove ownership.<br>
        <strong style="color:var(--gold);">No transaction, no gas fees.</strong>
      </div>
      <button class="btn-submit" id="connectWalletForRegBtn" style="width:100%;max-width:300px;">
        CONNECT WALLET
      </button>
      <div style="margin-top:20px;">
        <a id="backToCodeLink" style="color:#6b7280;font-size:12px;cursor:pointer;text-decoration:underline;">
          ← Back to code entry
        </a>
      </div>
    </div>
  `;

  // Store the code for later use
  tempRegistrationData.inviteCode = data;

  document.getElementById('connectWalletForRegBtn').addEventListener('click', handleWalletConnectForRegistration);
  document.getElementById('backToCodeLink').addEventListener('click', () => swapContent('home'));
```

### C. Create handleWalletConnectForRegistration() Function

**Add this new function after handleJoin():**

```javascript
async function handleWalletConnectForRegistration() {
  try {
    // Check if MetaMask/wallet is installed
    if (typeof window.ethereum === 'undefined') {
      Modal.alert('No Web3 wallet detected! Please install MetaMask or another Ethereum wallet.', 'Wallet Not Found');
      return;
    }

    Loading.show('Connecting wallet...');

    // Request account access
    const accounts = await window.ethereum.request({
      method: 'eth_requestAccounts'
    });

    const walletAddress = accounts[0];

    // Check if wallet already registered
    const { data: existingUser } = await supabase
      .from('users')
      .select('id')
      .eq('wallet_address', walletAddress)
      .single();

    if (existingUser) {
      Loading.hide();
      Modal.alert('This wallet is already registered. Please login instead.', 'Wallet Already Registered');
      return;
    }

    // Request signature to verify ownership
    const message = `Sign to register on Duel PVP\nWallet: ${walletAddress}\nCode: ${tempRegistrationData.inviteCode}\nTimestamp: ${Date.now()}`;

    const signature = await window.ethereum.request({
      method: 'personal_sign',
      params: [message, walletAddress]
    });

    // Store wallet and signature
    tempRegistrationData.walletAddress = walletAddress;
    tempRegistrationData.signature = signature;

    Loading.hide();
    Toast.success('Wallet verified!', 'SUCCESS');

    // Proceed to warrior naming
    swapContent('nameWarrior');

  } catch (error) {
    Loading.hide();
    console.error('Wallet connection error:', error);
    if (error.code === 4001) {
      Toast.warning('You cancelled the wallet connection', 'Connection Cancelled');
    } else {
      Modal.alert('Failed to connect wallet: ' + error.message, 'Connection Error');
    }
  }
}
```

### D. Update handleNameWarrior() Function

**Find handleNameWarrior() and replace it with:**

```javascript
async function handleNameWarrior() {
  const warriorName = document.getElementById('warriorName').value.trim();

  // Clear previous errors
  clearError('warriorNameError');

  if (!warriorName) {
    showError('warriorNameError', 'Warrior name is required');
    return;
  }

  if (warriorName.length < 3) {
    showError('warriorNameError', 'Must be at least 3 characters');
    return;
  }

  if (warriorName.length > 16) {
    showError('warriorNameError', 'Must be 16 characters or less');
    return;
  }

  Loading.show('Creating your account...');

  try {
    // Call server-side registration function
    const { data, error } = await supabase.rpc('register_with_wallet', {
      p_wallet_address: tempRegistrationData.walletAddress,
      p_display_name: warriorName,
      p_invite_code: tempRegistrationData.inviteCode
    });

    if (error || !data || data.length === 0 || !data[0].success) {
      Loading.hide();
      const errorCode = data && data[0]?.error_code;
      const message = data && data[0]?.message;

      if (errorCode === 'NAME_TAKEN') {
        showError('warriorNameError', 'Display name already taken');
      } else if (errorCode === 'WALLET_EXISTS') {
        Modal.alert('This wallet is already registered', 'Registration Failed');
      } else {
        Modal.alert(message || 'Registration failed', 'Error');
      }
      return;
    }

    const userId = data[0].user_id;

    // Store session info
    localStorage.setItem('duelpvp_user_id', userId);
    localStorage.setItem('duelpvp_wallet', tempRegistrationData.walletAddress);
    localStorage.setItem('duelpvp_display_name', warriorName);
    localStorage.setItem('duelpvp_warrior', warriorName);

    // Set username in dashboard
    document.getElementById('userName').textContent = warriorName.toUpperCase();

    // Initialize GP cache
    await initializeGPCache();
    const gp = await getUserGP();

    Loading.hide();
    Toast.success(`Welcome, ${warriorName}!`, `${gp} GP`);
    swapContent('dashboard');

    // Clear temp data
    tempRegistrationData = {
      walletAddress: '',
      inviteCode: '',
      signature: ''
    };

  } catch (e) {
    Loading.hide();
    console.error('Registration error:', e);
    Modal.alert('Registration failed: ' + e.message, 'Error');
  }
}
```

### E. Update tempRegistrationData

**Find (around line 5080):**
```javascript
let tempRegistrationData = {
  email: '',
  warriorName: '',
  password: '',
  inviteCode: ''
};
```

**Replace with:**
```javascript
let tempRegistrationData = {
  walletAddress: '',
  inviteCode: '',
  signature: ''
};
```

### F. Remove Old Email/Password Registration

**Find and DELETE the 'register' case in swapContent()** - it's no longer needed since we're going straight to wallet connect.

---

## Step 3: Update Login to Support Wallet-Only Accounts

**Find handleLogin() and update it to handle wallet-only accounts:**

The existing wallet login should work, but update the email login to show a message if the account is wallet-only.

---

## Step 4: Test the Flow

1. Go to homepage
2. Enter code (e.g., TEST1234)
3. Should see "CONNECT WALLET" screen
4. Click "Connect Wallet" → MetaMask popup
5. Sign message → No gas fees
6. Enter warrior name
7. Account created! ✅

---

## Benefits of This Approach

✅ **No email required** - Pure Web3 experience
✅ **One signature** - Proves wallet ownership
✅ **Faster onboarding** - 3 steps instead of 5
✅ **No passwords** - Wallet is the password
✅ **Crypto-native** - Appeals to your target audience

---

## Optional: Keep Email as Backup

If you want to allow BOTH wallet-only AND email accounts:
- Keep the old email registration path
- Add a choice screen: "Register with Wallet" or "Register with Email"
- Best of both worlds

Let me know if you want that hybrid approach!
