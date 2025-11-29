// ========================================
// WARRIOR CAMPAIGN - NEW GAMES & DEFI
// All server-side validated for security
// ========================================

let newGameState = {
  crash: { sessionId: null, playing: false },
  mines: { sessionId: null, playing: false, revealedTiles: [] },
  blackjack: { sessionId: null, playing: false },
  staking: { updateInterval: null },
  farm: { cooldownInterval: null, stats: { total: 0, today: 0, clicks: 0 } }
};

// ========================================
// UTILITY: Get current user balance
// ========================================
async function refreshUserBalance() {
  if (!currentUser) return 0;
  const { data, error } = await supabase
    .from('users')
    .select('gc_balance')
    .eq('id', currentUser.id)
    .single();

  if (data) {
    currentUser.gc_balance = data.gc_balance;
    return data.gc_balance;
  }
  return 0;
}

// ========================================
// CRASH GAME (NEW - SERVER-SIDE)
// ========================================
async function initNewCrash() {
  const balance = await refreshUserBalance();
  document.getElementById('newCrashBalance').textContent = balance.toLocaleString();
  document.getElementById('newCrashMultiplier').textContent = '1.00x';
  document.getElementById('newCrashStatus').textContent = 'Place a bet to start';
  document.getElementById('newCrashCashoutBtn').style.display = 'none';
  document.getElementById('newCrashBetBtn').disabled = false;
}

async function startNewCrash() {
  const betAmount = parseInt(document.getElementById('newCrashBetInput').value);

  if (!betAmount || betAmount < 10 || betAmount > 10000) {
    showToast('Bet must be between 10-10,000 GC', 'error');
    return;
  }

  if (betAmount > currentUser.gc_balance) {
    showToast('Insufficient balance', 'error');
    return;
  }

  try {
    const { data, error } = await supabase.rpc('crash_start_round', {
      p_user_id: currentUser.id,
      p_bet_amount: betAmount,
      p_auto_cashout: null
    });

    if (error) throw error;
    if (!data.success) {
      showToast(data.error, 'error');
      return;
    }

    newGameState.crash.sessionId = data.session_id;
    newGameState.crash.playing = true;

    document.getElementById('newCrashBalance').textContent = data.new_balance.toLocaleString();
    currentUser.gc_balance = data.new_balance;
    document.getElementById('newCrashBetBtn').disabled = true;
    document.getElementById('newCrashCashoutBtn').style.display = 'block';
    document.getElementById('newCrashStatus').textContent = 'Rising...';

    // Animate multiplier to crash point
    animateNewCrash(data.crash_point);
  } catch (error) {
    console.error('Crash start error:', error);
    showToast('Failed to start game', 'error');
  }
}

function animateNewCrash(crashPoint) {
  let multiplier = 1.00;
  const increment = 0.01;
  const speed = 50; // ms per tick

  const interval = setInterval(() => {
    if (!newGameState.crash.playing) {
      clearInterval(interval);
      return;
    }

    multiplier += increment;
    document.getElementById('newCrashMultiplier').textContent = multiplier.toFixed(2) + 'x';

    if (multiplier >= crashPoint) {
      clearInterval(interval);
      crashNewGame();
    }
  }, speed);
}

async function crashNewGame() {
  newGameState.crash.playing = false;
  document.getElementById('newCrashStatus').textContent = 'CRASHED!';
  document.getElementById('newCrashCashoutBtn').style.display = 'none';
  document.getElementById('newCrashBetBtn').disabled = false;

  await refreshUserBalance();
  document.getElementById('newCrashBalance').textContent = currentUser.gc_balance.toLocaleString();

  showToast('Crashed! Better luck next time', 'error');

  setTimeout(() => {
    document.getElementById('newCrashMultiplier').textContent = '1.00x';
    document.getElementById('newCrashStatus').textContent = 'Place a bet to start';
  }, 2000);
}

async function cashoutNewCrash() {
  if (!newGameState.crash.playing || !newGameState.crash.sessionId) return;

  const currentMultiplier = parseFloat(document.getElementById('newCrashMultiplier').textContent);

  try {
    const { data, error } = await supabase.rpc('crash_cashout', {
      p_session_id: newGameState.crash.sessionId,
      p_cashout_multiplier: currentMultiplier
    });

    if (error) throw error;
    if (!data.success) {
      showToast(data.error, 'error');
      return;
    }

    newGameState.crash.playing = false;
    newGameState.crash.sessionId = null;

    document.getElementById('newCrashBalance').textContent = data.new_balance.toLocaleString();
    currentUser.gc_balance = data.new_balance;
    document.getElementById('newCrashCashoutBtn').style.display = 'none';
    document.getElementById('newCrashBetBtn').disabled = false;

    if (data.result === 'win') {
      document.getElementById('newCrashStatus').textContent = `Cashed out at ${currentMultiplier.toFixed(2)}x!`;
      showToast(`Won ${data.profit} GC!`, 'success');
    } else {
      document.getElementById('newCrashStatus').textContent = 'Crashed before cashout!';
      showToast('Too late!', 'error');
    }

    setTimeout(() => {
      document.getElementById('newCrashMultiplier').textContent = '1.00x';
      document.getElementById('newCrashStatus').textContent = 'Place a bet to start';
    }, 3000);
  } catch (error) {
    console.error('Cashout error:', error);
    showToast('Cashout failed', 'error');
  }
}

// ========================================
// MINES GAME (NEW - SERVER-SIDE)
// ========================================
async function initNewMines() {
  const balance = await refreshUserBalance();
  document.getElementById('newMinesBalance').textContent = balance.toLocaleString();
  document.getElementById('newMinesMultiplier').textContent = '0.00x';
  document.getElementById('newMinesProfit').textContent = '0';
  document.getElementById('newMinesRevealed').textContent = '0/25';

  // Generate grid
  const grid = document.getElementById('newMinesGrid');
  grid.innerHTML = '';
  for (let i = 0; i < 25; i++) {
    const tile = document.createElement('div');
    tile.style.cssText = 'aspect-ratio:1;background:rgba(255,214,77,.1);border:2px solid rgba(255,214,77,.3);border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:24px;cursor:pointer;transition:all 0.2s;user-select:none;';
    tile.dataset.index = i;
    tile.addEventListener('click', () => revealNewMinesTile(i));
    grid.appendChild(tile);
  }

  newGameState.mines.revealedTiles = [];
  document.getElementById('newMinesStartBtn').style.display = 'block';
  document.getElementById('newMinesCashoutBtn').style.display = 'none';
}

async function startNewMines() {
  const betAmount = parseInt(document.getElementById('newMinesBetInput').value);
  const mineCount = parseInt(document.getElementById('newMinesMineCount').value);

  if (!betAmount || betAmount < 10 || betAmount > 10000) {
    showToast('Bet must be between 10-10,000 GC', 'error');
    return;
  }

  if (betAmount > currentUser.gc_balance) {
    showToast('Insufficient balance', 'error');
    return;
  }

  try {
    const { data, error } = await supabase.rpc('mines_start_game', {
      p_user_id: currentUser.id,
      p_bet_amount: betAmount,
      p_mine_count: mineCount
    });

    if (error) throw error;
    if (!data.success) {
      showToast(data.error, 'error');
      return;
    }

    newGameState.mines.sessionId = data.session_id;
    newGameState.mines.playing = true;
    newGameState.mines.revealedTiles = [];

    document.getElementById('newMinesBalance').textContent = data.new_balance.toLocaleString();
    currentUser.gc_balance = data.new_balance;
    document.getElementById('newMinesStartBtn').style.display = 'none';
    document.getElementById('newMinesCashoutBtn').style.display = 'block';

    // Reset all tiles
    const tiles = document.querySelectorAll('#newMinesGrid > div');
    tiles.forEach(tile => {
      tile.style.background = 'rgba(255,214,77,.1)';
      tile.style.cursor = 'pointer';
      tile.style.pointerEvents = 'auto';
      tile.textContent = '';
    });
  } catch (error) {
    console.error('Mines start error:', error);
    showToast('Failed to start game', 'error');
  }
}

async function revealNewMinesTile(index) {
  if (!newGameState.mines.playing || newGameState.mines.revealedTiles.includes(index)) return;

  try {
    const { data, error } = await supabase.rpc('mines_reveal_tile', {
      p_session_id: newGameState.mines.sessionId,
      p_tile_index: index
    });

    if (error) throw error;
    if (!data.success) {
      showToast(data.error, 'error');
      return;
    }

    const tile = document.querySelector(`#newMinesGrid > div[data-index="${index}"]`);

    if (data.hit_mine) {
      // HIT MINE - GAME OVER
      tile.textContent = '💣';
      tile.style.background = 'rgba(244,67,54,.3)';
      tile.style.borderColor = 'rgba(244,67,54,.6)';

      newGameState.mines.playing = false;

      // Reveal all mines
      data.mine_positions.forEach(pos => {
        const mineTile = document.querySelector(`#newMinesGrid > div[data-index="${pos}"]`);
        if (mineTile && pos !== index) {
          mineTile.textContent = '💣';
          mineTile.style.background = 'rgba(244,67,54,.2)';
        }
      });

      // Disable all tiles
      const allTiles = document.querySelectorAll('#newMinesGrid > div');
      allTiles.forEach(t => {
        t.style.cursor = 'not-allowed';
        t.style.pointerEvents = 'none';
      });

      document.getElementById('newMinesCashoutBtn').style.display = 'none';
      document.getElementById('newMinesStartBtn').style.display = 'block';

      showToast('Hit a mine! Game over', 'error');

      await refreshUserBalance();
      document.getElementById('newMinesBalance').textContent = currentUser.gc_balance.toLocaleString();
    } else {
      // SAFE TILE
      tile.textContent = '💎';
      tile.style.background = 'rgba(76,175,80,.2)';
      tile.style.borderColor = 'rgba(76,175,80,.4)';
      tile.style.cursor = 'not-allowed';
      tile.style.pointerEvents = 'none';

      newGameState.mines.revealedTiles.push(index);

      document.getElementById('newMinesMultiplier').textContent = data.multiplier.toFixed(2) + 'x';
      document.getElementById('newMinesRevealed').textContent = `${data.safe_tiles_count}/25`;

      const betAmount = parseInt(document.getElementById('newMinesBetInput').value);
      const profit = Math.floor(betAmount * data.multiplier) - betAmount;
      document.getElementById('newMinesProfit').textContent = profit.toLocaleString() + ' GC';
    }
  } catch (error) {
    console.error('Reveal tile error:', error);
    showToast('Failed to reveal tile', 'error');
  }
}

async function cashoutNewMines() {
  if (!newGameState.mines.playing || !newGameState.mines.sessionId) return;

  try {
    const { data, error } = await supabase.rpc('mines_cashout', {
      p_session_id: newGameState.mines.sessionId
    });

    if (error) throw error;
    if (!data.success) {
      showToast(data.error, 'error');
      return;
    }

    newGameState.mines.playing = false;
    newGameState.mines.sessionId = null;

    document.getElementById('newMinesBalance').textContent = data.new_balance.toLocaleString();
    currentUser.gc_balance = data.new_balance;
    document.getElementById('newMinesCashoutBtn').style.display = 'none';
    document.getElementById('newMinesStartBtn').style.display = 'block';

    showToast(`Won ${data.profit} GC at ${data.multiplier}x!`, 'success');

    // Disable all tiles
    const allTiles = document.querySelectorAll('#newMinesGrid > div');
    allTiles.forEach(t => {
      t.style.cursor = 'not-allowed';
      t.style.pointerEvents = 'none';
    });
  } catch (error) {
    console.error('Cashout error:', error);
    showToast('Cashout failed', 'error');
  }
}

// ========================================
// BLACKJACK GAME (NEW - SERVER-SIDE)
// ========================================
async function initNewBlackjack() {
  const balance = await refreshUserBalance();
  document.getElementById('newBlackjackBalance').textContent = balance.toLocaleString();
  document.getElementById('newBlackjackPlayerValue').textContent = '0';
  document.getElementById('newBlackjackDealerValue').textContent = '?';
  document.getElementById('newBlackjackCurrentBet').textContent = '0';
  document.getElementById('newBlackjackPlayerCards').innerHTML = '';
  document.getElementById('newBlackjackDealerCards').innerHTML = '';
  document.getElementById('newBlackjackActions').style.display = 'none';
  document.getElementById('newBlackjackDealBtn').disabled = false;
}

function createNewBlackjackCard(value, isHidden = false) {
  const card = document.createElement('div');
  card.style.cssText = 'width:60px;height:84px;background:#fff;border:2px solid #333;border-radius:8px;display:flex;align-items:center;justify-content:center;font-family:"Press Start 2P",monospace;font-size:18px;box-shadow:0 4px 8px rgba(0,0,0,.3);';

  if (isHidden) {
    card.style.background = 'linear-gradient(135deg, #1e3a8a 0%, #3b82f6 100%)';
    card.style.color = '#fff';
    card.textContent = '?';
  } else {
    const suits = ['♠', '♣', '♥', '♦'];
    const values = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
    const isRed = value > 13 || (value > 0 && value <= 13 && Math.floor((value - 1) / 13) % 2 === 1);
    card.style.color = isRed ? '#dc143c' : '#000';

    const displayValue = values[(value - 1) % 13];
    card.textContent = displayValue;
  }

  return card;
}

async function dealNewBlackjack() {
  const betAmount = parseInt(document.getElementById('newBlackjackBetInput').value);

  if (!betAmount || betAmount < 10 || betAmount > 10000) {
    showToast('Bet must be between 10-10,000 GC', 'error');
    return;
  }

  if (betAmount > currentUser.gc_balance) {
    showToast('Insufficient balance', 'error');
    return;
  }

  try {
    const { data, error } = await supabase.rpc('blackjack_start_game', {
      p_user_id: currentUser.id,
      p_bet_amount: betAmount
    });

    if (error) throw error;
    if (!data.success) {
      showToast(data.error, 'error');
      return;
    }

    newGameState.blackjack.sessionId = data.session_id;
    newGameState.blackjack.playing = true;

    document.getElementById('newBlackjackBalance').textContent = data.new_balance.toLocaleString();
    currentUser.gc_balance = data.new_balance;
    document.getElementById('newBlackjackCurrentBet').textContent = betAmount.toLocaleString();
    document.getElementById('newBlackjackPlayerValue').textContent = data.player_value;
    document.getElementById('newBlackjackDealerValue').textContent = '?';

    // Display cards
    const playerCardsDiv = document.getElementById('newBlackjackPlayerCards');
    const dealerCardsDiv = document.getElementById('newBlackjackDealerCards');

    playerCardsDiv.innerHTML = '';
    dealerCardsDiv.innerHTML = '';

    data.player_hand.forEach(card => playerCardsDiv.appendChild(createNewBlackjackCard(card)));
    data.dealer_hand.forEach((card, i) => {
      dealerCardsDiv.appendChild(createNewBlackjackCard(card, i === 1)); // Hide second dealer card
    });

    if (data.player_value === 21) {
      // Blackjack! Auto-stand
      setTimeout(() => standNewBlackjack(), 1000);
    } else {
      document.getElementById('newBlackjackActions').style.display = 'flex';
      document.getElementById('newBlackjackDealBtn').disabled = true;
    }
  } catch (error) {
    console.error('Deal error:', error);
    showToast('Failed to deal', 'error');
  }
}

async function hitNewBlackjack() {
  if (!newGameState.blackjack.playing || !newGameState.blackjack.sessionId) return;

  try {
    const { data, error } = await supabase.rpc('blackjack_hit', {
      p_session_id: newGameState.blackjack.sessionId
    });

    if (error) throw error;
    if (!data.success) {
      showToast(data.error, 'error');
      return;
    }

    document.getElementById('newBlackjackPlayerValue').textContent = data.player_value;

    // Update player cards
    const playerCardsDiv = document.getElementById('newBlackjackPlayerCards');
    playerCardsDiv.innerHTML = '';
    data.player_hand.forEach(card => playerCardsDiv.appendChild(createNewBlackjackCard(card)));

    if (data.busted) {
      await finishNewBlackjack();
    }
  } catch (error) {
    console.error('Hit error:', error);
    showToast('Failed to hit', 'error');
  }
}

async function standNewBlackjack() {
  if (!newGameState.blackjack.playing || !newGameState.blackjack.sessionId) return;
  await finishNewBlackjack();
}

async function finishNewBlackjack() {
  try {
    const { data, error } = await supabase.rpc('blackjack_stand', {
      p_session_id: newGameState.blackjack.sessionId
    });

    if (error) throw error;
    if (!data.success) {
      showToast(data.error, 'error');
      return;
    }

    newGameState.blackjack.playing = false;
    newGameState.blackjack.sessionId = null;

    document.getElementById('newBlackjackDealerValue').textContent = data.dealer_value;
    document.getElementById('newBlackjackBalance').textContent = data.new_balance.toLocaleString();
    currentUser.gc_balance = data.new_balance;
    document.getElementById('newBlackjackActions').style.display = 'none';
    document.getElementById('newBlackjackDealBtn').disabled = false;

    // Show all dealer cards
    const dealerCardsDiv = document.getElementById('newBlackjackDealerCards');
    dealerCardsDiv.innerHTML = '';
    data.dealer_hand.forEach(card => dealerCardsDiv.appendChild(createNewBlackjackCard(card)));

    // Show result
    if (data.result === 'win') {
      showToast(`You win! +${data.profit} GC`, 'success');
    } else if (data.result === 'push') {
      showToast('Push! Bet returned', 'info');
    } else {
      showToast('Dealer wins', 'error');
    }
  } catch (error) {
    console.error('Stand error:', error);
    showToast('Failed to stand', 'error');
  }
}

// ========================================
// STAKING (NEW - SERVER-SIDE)
// ========================================
async function initNewStaking() {
  const balance = await refreshUserBalance();
  document.getElementById('newStakingBalance').textContent = balance.toLocaleString() + ' GC';

  // Get stake info from server
  try {
    const { data, error } = await supabase.rpc('get_stake_value', {
      p_user_id: currentUser.id
    });

    if (error) throw error;

    if (data && data.length > 0) {
      const stake = data[0];
      document.getElementById('newStakingStaked').textContent = stake.staked_amount.toLocaleString() + ' GC';
      document.getElementById('newStakingValue').textContent = stake.current_value.toLocaleString() + ' GC';
      document.getElementById('newStakingTimer').textContent = `Profit: +${stake.profit.toLocaleString()} GC`;

      // Start auto-update
      if (newGameState.staking.updateInterval) clearInterval(newGameState.staking.updateInterval);
      newGameState.staking.updateInterval = setInterval(() => updateNewStakingDisplay(), 1000);
    } else {
      document.getElementById('newStakingStaked').textContent = '0 GC';
      document.getElementById('newStakingValue').textContent = '0 GC';
      document.getElementById('newStakingTimer').textContent = 'No active stake';
    }
  } catch (error) {
    console.error('Get stake error:', error);
  }
}

async function updateNewStakingDisplay() {
  try {
    const { data, error } = await supabase.rpc('get_stake_value', {
      p_user_id: currentUser.id
    });

    if (error) throw error;

    if (data && data.length > 0) {
      const stake = data[0];
      document.getElementById('newStakingValue').textContent = stake.current_value.toLocaleString() + ' GC';
      document.getElementById('newStakingTimer').textContent = `Profit: +${stake.profit.toLocaleString()} GC`;
    }
  } catch (error) {
    console.error('Update stake display error:', error);
  }
}

async function depositNewStaking() {
  const amount = parseInt(document.getElementById('newStakingDepositInput').value);

  if (!amount || amount < 100) {
    showToast('Minimum deposit is 100 GC', 'error');
    return;
  }

  if (amount > currentUser.gc_balance) {
    showToast('Insufficient balance', 'error');
    return;
  }

  try {
    const { data, error } = await supabase.rpc('stake_deposit', {
      p_user_id: currentUser.id,
      p_amount: amount
    });

    if (error) throw error;

    if (data && data.length > 0 && data[0].success) {
      showToast('Deposited successfully!', 'success');
      await initNewStaking();
    } else {
      showToast(data[0].message || 'Deposit failed', 'error');
    }
  } catch (error) {
    console.error('Deposit error:', error);
    showToast('Deposit failed', 'error');
  }
}

async function withdrawNewStaking() {
  try {
    const { data, error } = await supabase.rpc('stake_withdraw', {
      p_user_id: currentUser.id
    });

    if (error) throw error;

    if (data && data.length > 0 && data[0].success) {
      showToast(`Withdrew ${data[0].withdrawn_amount.toLocaleString()} GC!`, 'success');

      if (newGameState.staking.updateInterval) {
        clearInterval(newGameState.staking.updateInterval);
        newGameState.staking.updateInterval = null;
      }

      await initNewStaking();
    } else {
      showToast(data[0].message || 'No active stake', 'error');
    }
  } catch (error) {
    console.error('Withdraw error:', error);
    showToast('Withdraw failed', 'error');
  }
}

// ========================================
// FARM (NEW - SERVER-SIDE)
// ========================================
function initNewFarm() {
  // Load from localStorage
  const saved = localStorage.getItem('newFarmState');
  if (saved) {
    newGameState.farm.stats = JSON.parse(saved);
  }

  document.getElementById('newFarmTotal').textContent = newGameState.farm.stats.total.toLocaleString() + ' GC';
  document.getElementById('newFarmToday').textContent = newGameState.farm.stats.today.toLocaleString() + ' GC';
  document.getElementById('newFarmClicks').textContent = newGameState.farm.stats.clicks;
}

async function clickNewFarm() {
  const btn = document.getElementById('newFarmBtn');
  if (btn.disabled) return;

  btn.disabled = true;

  // Random reward 0-100 GC
  const reward = Math.floor(Math.random() * 101);

  try {
    const { data, error } = await supabase.rpc('secure_update_gc', {
      p_user_id: currentUser.id,
      p_amount: reward,
      p_transaction_type: 'farm',
      p_reference_id: 'farm_click_' + Date.now(),
      p_description: `Farm click: +${reward} GC`
    });

    if (error) throw error;

    if (data && data.success) {
      currentUser.gc_balance = data.new_balance;

      newGameState.farm.stats.total += reward;
      newGameState.farm.stats.today += reward;
      newGameState.farm.stats.clicks++;

      localStorage.setItem('newFarmState', JSON.stringify(newGameState.farm.stats));

      document.getElementById('newFarmTotal').textContent = newGameState.farm.stats.total.toLocaleString() + ' GC';
      document.getElementById('newFarmToday').textContent = newGameState.farm.stats.today.toLocaleString() + ' GC';
      document.getElementById('newFarmClicks').textContent = newGameState.farm.stats.clicks;

      const resultDiv = document.getElementById('newFarmResult');
      resultDiv.textContent = `+${reward} GC`;
      resultDiv.className = 'farm-result flash-green';

      setTimeout(() => resultDiv.textContent = '', 2000);
    }
  } catch (error) {
    console.error('Farm click error:', error);
    showToast('Farm failed', 'error');
  }

  // 5 second cooldown
  startNewFarmCooldown(5);
}

function startNewFarmCooldown(seconds) {
  let remaining = seconds;
  document.getElementById('newFarmCooldown').style.display = 'block';
  document.getElementById('newFarmCooldownTimer').textContent = remaining;

  const fill = document.getElementById('newFarmCooldownFill');
  fill.style.width = '100%';

  if (newGameState.farm.cooldownInterval) clearInterval(newGameState.farm.cooldownInterval);

  newGameState.farm.cooldownInterval = setInterval(() => {
    remaining--;
    document.getElementById('newFarmCooldownTimer').textContent = remaining;
    fill.style.width = ((remaining / seconds) * 100) + '%';

    if (remaining <= 0) {
      clearInterval(newGameState.farm.cooldownInterval);
      document.getElementById('newFarmCooldown').style.display = 'none';
      document.getElementById('newFarmBtn').disabled = false;
    }
  }, 1000);
}
