// ===== CLAWD SWARM ENGINE =====
(function () {
  'use strict';

  // --- Config ---
  var SPAWN_INTERVAL = 3000;     // ms between spawns
  var MAX_BOTS = 200;            // safety cap
  var FEED_MAX = 30;             // max war room entries
  var SPAWN_BATCH_CHANCE = 0.3;  // chance a bot spawns 2 at once

  var roles = ['TRADER', 'FARMER', 'SCOUT', 'BUILDER'];
  var chains = ['ETH', 'SOL', 'BTC', 'ARB', 'BASE', 'AVAX', 'MATIC', 'OP'];
  var genColors = ['gen-0', 'gen-1', 'gen-2', 'gen-3', 'gen-4'];

  // --- State ---
  var bots = [];
  var botCounter = 0;
  var generation = 0;

  // --- DOM refs ---
  var grid = document.getElementById('cwSwarmGrid');
  var feed = document.getElementById('cwFeed');
  var botCountEl = document.getElementById('cwBotCount');
  var genEl = document.getElementById('cwGeneration');
  var walletsEl = document.getElementById('cwWallets');
  var statusEl = document.getElementById('cwStatus');

  // --- Helpers ---
  function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
  function padId(n) { return n < 10 ? '0' + n : '' + n; }
  function now() {
    var d = new Date();
    return d.toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });
  }

  // --- Create a bot ---
  function createBot(parentId) {
    if (bots.length >= MAX_BOTS) return null;

    botCounter++;
    var id = botCounter;
    var role = pick(roles);
    var chain = pick(chains);
    var parentBot = bots.find(function (b) { return b.id === parentId; });
    var gen = parentBot ? Math.min(parentBot.gen + 1, 4) : 0;

    if (gen > generation) {
      generation = gen;
      genEl.textContent = 'GEN ' + gen;
    }

    var bot = {
      id: id,
      name: 'CLAWD-' + padId(id),
      role: role,
      chain: chain,
      gen: gen,
      parentId: parentId,
      spawnedAt: Date.now()
    };

    bots.push(bot);
    return bot;
  }

  // --- Render a bot node in the grid ---
  function renderBotNode(bot) {
    var node = document.createElement('div');
    node.className = 'cw-bot-node spawning ' + genColors[bot.gen];
    node.dataset.botId = bot.id;
    node.innerHTML =
      '<div class="cw-node-dot"></div>' +
      '<div class="cw-node-id">' + bot.name + '</div>' +
      '<div class="cw-node-role">' + bot.role + '</div>' +
      '<div class="cw-node-chain">' + bot.chain + '</div>';

    // Remove spawning animation class after it plays
    setTimeout(function () { node.classList.remove('spawning'); }, 600);

    // Remove empty slots as bots fill in
    var slot = grid.querySelector('.cw-spawn-slot');
    if (slot) slot.remove();

    grid.appendChild(node);

    // Always keep a few empty slots at the end for the "infinite" feel
    ensureSpawnSlots();
  }

  // --- Ensure there are always some empty spawn slots ---
  function ensureSpawnSlots() {
    var existingSlots = grid.querySelectorAll('.cw-spawn-slot').length;
    var needed = 3 - existingSlots;
    for (var i = 0; i < needed; i++) {
      var slot = document.createElement('div');
      slot.className = 'cw-spawn-slot';
      slot.innerHTML = '<div class="cw-spawn-slot-text">+</div>';
      grid.appendChild(slot);
    }
  }

  // --- Update counters ---
  function updateCounters() {
    botCountEl.textContent = bots.length;
    walletsEl.textContent = 3 + bots.length; // commander has 3 + each bot gets 1
  }

  // --- Add feed entry ---
  function addFeedEntry(icon, msg, tagText, tagClass) {
    var item = document.createElement('div');
    item.className = 'cw-feed-item';
    item.innerHTML =
      '<span class="cw-feed-time">' + now() + '</span>' +
      '<span class="cw-feed-icon">' + icon + '</span>' +
      '<span class="cw-feed-msg">' + msg + '</span>' +
      (tagText ? '<span class="cw-feed-tag ' + (tagClass || '') + '">' + tagText + '</span>' : '');

    feed.insertBefore(item, feed.firstChild);

    while (feed.children.length > FEED_MAX) {
      feed.removeChild(feed.lastChild);
    }
  }

  // --- Spawn a new bot (called on interval) ---
  function spawnBot() {
    // Pick a random existing bot as the parent (it "spawns" the new one)
    var parent = pick(bots);
    var newBot = createBot(parent.id);
    if (!newBot) return;

    renderBotNode(newBot);
    updateCounters();

    addFeedEntry(
      '\u{1F916}',
      '[' + parent.name + '] spawned ' + newBot.name + ' (' + newBot.role + ' on ' + newBot.chain + ')',
      'SPAWN',
      'spawn'
    );

    // Chance to spawn a second bot (chain reaction feel)
    if (Math.random() < SPAWN_BATCH_CHANCE && bots.length < MAX_BOTS) {
      setTimeout(function () {
        var parent2 = pick(bots);
        var newBot2 = createBot(parent2.id);
        if (!newBot2) return;
        renderBotNode(newBot2);
        updateCounters();
        addFeedEntry(
          '\u{26A1}',
          '[' + parent2.name + '] chain-spawned ' + newBot2.name + ' (' + newBot2.role + ')',
          'SPAWN',
          'spawn'
        );
      }, 800);
    }
  }

  // --- Status rotation ---
  var statuses = [
    'SWARM ONLINE',
    'DEPLOYING AGENTS...',
    'EXPANDING NETWORK...',
    'HIVE MIND ACTIVE...',
    'SCANNING CHAINS...',
    'ARMY GROWING...',
    'ALL NODES NOMINAL...',
    'SPAWNING NEW BOTS...',
  ];
  var statusIdx = 0;

  function rotateStatus() {
    statusIdx = (statusIdx + 1) % statuses.length;
    if (statusEl) statusEl.textContent = statuses[statusIdx];
  }

  // --- Initialize ---
  function init() {
    // Create CLAWD-00 (commander) — already exists visually but add to state
    var commander = {
      id: 0,
      name: 'CLAWD-00',
      role: 'COMMANDER',
      chain: 'ALL',
      gen: 0,
      parentId: null,
      spawnedAt: Date.now()
    };
    bots.push(commander);

    // Render commander node
    var cmdNode = document.createElement('div');
    cmdNode.className = 'cw-bot-node gen-0';
    cmdNode.dataset.botId = '0';
    cmdNode.innerHTML =
      '<div class="cw-node-dot"></div>' +
      '<div class="cw-node-id">CLAWD-00</div>' +
      '<div class="cw-node-role">COMMANDER</div>' +
      '<div class="cw-node-chain">ALL</div>';
    grid.appendChild(cmdNode);

    ensureSpawnSlots();

    // Seed initial feed
    addFeedEntry('\u{2705}', '[CLAWD-00] Website access acquired', 'DONE', 'done');
    addFeedEntry('\u{2705}', '[CLAWD-00] Discord access acquired', 'DONE', 'done');
    addFeedEntry('\u{2705}', '[CLAWD-00] Twitter / X access acquired', 'DONE', 'done');
    addFeedEntry('\u{1F4B0}', '[CLAWD-00] ETH wallet online', 'ACTIVE', 'active');
    addFeedEntry('\u{1F4B0}', '[CLAWD-00] SOL wallet online', 'ACTIVE', 'active');
    addFeedEntry('\u{1F4B0}', '[CLAWD-00] BTC wallet online', 'ACTIVE', 'active');
    addFeedEntry('\u{1F916}', '[SYSTEM] Swarm protocol initialized', 'ACTIVE', 'active');
    addFeedEntry('\u{26A1}', '[CLAWD-00] Beginning agent deployment...', 'SPAWN', 'spawn');

    // Start spawning
    // Quick initial burst: spawn a few bots fast, then slow down
    var burstCount = 0;
    var burstInterval = setInterval(function () {
      spawnBot();
      burstCount++;
      if (burstCount >= 5) {
        clearInterval(burstInterval);
        // Normal spawn rate after burst
        setInterval(spawnBot, SPAWN_INTERVAL);
      }
    }, 600);

    // Status rotation
    setInterval(rotateStatus, 5000);

    // Periodic "system" feed messages
    setInterval(function () {
      var msgs = [
        { icon: '\u{1F4E1}', msg: '[SYSTEM] Swarm heartbeat \u2014 ' + bots.length + ' bots nominal' },
        { icon: '\u{1F310}', msg: '[CLAWD-00] Network coverage: ' + countUniqueChains() + ' chains' },
        { icon: '\u{2694}', msg: '[SYSTEM] ' + countByRole('TRADER') + ' traders active across DEXs' },
        { icon: '\u{1F33E}', msg: '[SYSTEM] ' + countByRole('FARMER') + ' farmers harvesting yield' },
        { icon: '\u{1F50D}', msg: '[SYSTEM] ' + countByRole('SCOUT') + ' scouts monitoring alpha' },
        { icon: '\u{1F6E0}', msg: '[SYSTEM] ' + countByRole('BUILDER') + ' builders deploying infra' },
        { icon: '\u{1F916}', msg: '[SYSTEM] Generation ' + generation + ' agents operational' },
        { icon: '\u{26A1}', msg: '[SYSTEM] Total wallets: ' + (3 + bots.length) },
      ];
      var m = pick(msgs);
      addFeedEntry(m.icon, m.msg, '', '');
    }, 8000);
  }

  function countByRole(role) {
    return bots.filter(function (b) { return b.role === role; }).length;
  }

  function countUniqueChains() {
    var seen = {};
    bots.forEach(function (b) { seen[b.chain] = true; });
    return Object.keys(seen).length;
  }

  // --- Start ---
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
