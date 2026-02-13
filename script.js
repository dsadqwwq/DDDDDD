    // ===== SUPABASE CLIENT =====
    const SUPABASE_URL = 'https://smgqccnggmyreacjyyil.supabase.co';
    const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtZ3FjY25nZ215cmVhY2p5eWlsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI5ODIwNDgsImV4cCI6MjA3ODU1ODA0OH0.y1AeyXkKCdVvE3JUIlCyDl6p12TFrgMkEiUocUB4YMI';

    const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: {
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: false
      }
    });

    // ===== WALLET CONNECTION =====
    let web3Provider = null;
    let selectedWalletType = null;

    // Detect available wallets
    function getAvailableWallets() {
      const wallets = [];

      if (window.ethereum) {
        if (window.ethereum.isMetaMask) {
          wallets.push({ id: 'metamask', name: 'MetaMask', icon: '🦊' });
        } else if (window.ethereum.isCoinbaseWallet) {
          wallets.push({ id: 'coinbase', name: 'Coinbase Wallet', icon: '🔵' });
        } else if (window.ethereum.isTrust) {
          wallets.push({ id: 'trust', name: 'Trust Wallet', icon: '🛡️' });
        } else {
          wallets.push({ id: 'injected', name: 'Browser Wallet', icon: '🔗' });
        }
      }

      return wallets;
    }

    // Show wallet selection modal - Redesigned with glassmorphism
    function showWalletSelector() {
      return new Promise((resolve, reject) => {
        // Always show all wallet options
        const walletOptions = [
          { id: 'metamask', name: 'MetaMask', icon: '🦊', check: () => window.ethereum?.isMetaMask },
          { id: 'rabby', name: 'Rabby', icon: '🐰', check: () => window.ethereum?.isRabby },
          { id: 'coinbase', name: 'Coinbase Wallet', icon: '🔵', check: () => window.ethereum?.isCoinbaseWallet },
          { id: 'trust', name: 'Trust Wallet', icon: '🛡️', check: () => window.ethereum?.isTrust },
          { id: 'walletconnect', name: 'WalletConnect', icon: '🔗', check: () => false, comingSoon: true }
        ];

        // Create custom wallet selector overlay
        const overlay = document.createElement('div');
        overlay.id = 'wallet-selector-overlay';
        overlay.innerHTML = `
          <div class="wallet-selector-modal">
            <button class="wallet-selector-close" id="wallet-close-btn">&times;</button>

            <div class="wallet-selector-header">
              <img src="duelpvp-logo.svg" alt="Duel PVP" class="wallet-selector-logo">
              <h2 class="wallet-selector-title">Connect Wallet</h2>
              <p class="wallet-selector-subtitle">Choose your preferred wallet to continue</p>
            </div>

            <div class="wallet-selector-options">
              ${walletOptions.map(w => {
                const isAvailable = w.check();
                const isComingSoon = w.comingSoon;
                return `
                  <button class="wallet-option ${!isAvailable && !isComingSoon ? 'unavailable' : ''} ${isComingSoon ? 'coming-soon' : ''}"
                          data-wallet="${w.id}"
                          ${!isAvailable ? 'data-unavailable="true"' : ''}
                          ${isComingSoon ? 'data-coming-soon="true"' : ''}>
                    <span class="wallet-option-icon">${w.icon}</span>
                    <span class="wallet-option-name">${w.name}</span>
                    ${isComingSoon ? '<span class="wallet-option-badge">SOON</span>' : ''}
                    ${!isAvailable && !isComingSoon ? '<span class="wallet-option-status">Not installed</span>' : ''}
                    ${isAvailable ? '<span class="wallet-option-arrow">→</span>' : ''}
                  </button>
                `;
              }).join('')}
            </div>

            <div class="wallet-selector-footer">
              <p>By connecting, you agree to our <a href="#" onclick="return false;">Terms of Service</a></p>
            </div>
          </div>
        `;

        // Add styles
        const styles = document.createElement('style');
        styles.id = 'wallet-selector-styles';
        styles.textContent = `
          #wallet-selector-overlay {
            position: fixed;
            inset: 0;
            background: rgba(0, 0, 0, 0.85);
            backdrop-filter: blur(12px);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 10000;
            animation: walletFadeIn 0.3s ease-out;
          }

          @keyframes walletFadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
          }

          @keyframes walletSlideIn {
            from {
              opacity: 0;
              transform: translateY(-20px) scale(0.95);
            }
            to {
              opacity: 1;
              transform: translateY(0) scale(1);
            }
          }

          .wallet-selector-modal {
            position: relative;
            width: min(420px, 90vw);
            background: rgba(12, 16, 20, 0.95);
            border: 2px solid rgba(255, 214, 77, 0.4);
            border-radius: 16px;
            padding: 32px;
            backdrop-filter: blur(20px);
            box-shadow:
              0 24px 80px rgba(0, 0, 0, 0.8),
              0 0 60px rgba(255, 214, 77, 0.15),
              inset 0 1px 0 rgba(255, 255, 255, 0.05);
            animation: walletSlideIn 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
          }

          .wallet-selector-close {
            position: absolute;
            top: 16px;
            right: 16px;
            width: 32px;
            height: 32px;
            border: none;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 8px;
            color: #888;
            font-size: 20px;
            cursor: pointer;
            transition: all 0.2s ease;
            display: flex;
            align-items: center;
            justify-content: center;
          }

          .wallet-selector-close:hover {
            background: rgba(255, 255, 255, 0.2);
            color: #fff;
          }

          .wallet-selector-header {
            text-align: center;
            margin-bottom: 28px;
          }

          .wallet-selector-logo {
            width: 72px;
            height: 72px;
            margin-bottom: 16px;
            filter: drop-shadow(0 4px 12px rgba(255, 214, 77, 0.3));
          }

          .wallet-selector-title {
            font-family: 'Press Start 2P', monospace;
            font-size: 14px;
            color: var(--gold);
            margin: 0 0 8px 0;
            text-shadow: 0 2px 8px rgba(255, 214, 77, 0.3);
          }

          .wallet-selector-subtitle {
            font-family: Inter, system-ui, Arial;
            font-size: 13px;
            color: #888;
            margin: 0;
          }

          .wallet-selector-options {
            display: flex;
            flex-direction: column;
            gap: 12px;
          }

          .wallet-option {
            display: flex;
            align-items: center;
            gap: 16px;
            width: 100%;
            padding: 16px 20px;
            background: rgba(255, 255, 255, 0.03);
            border: 2px solid rgba(255, 255, 255, 0.1);
            border-radius: 12px;
            color: #e6ecf1;
            font-family: Inter, system-ui, Arial;
            font-size: 14px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.2s ease;
          }

          .wallet-option:hover:not(.unavailable):not(.coming-soon) {
            background: rgba(255, 214, 77, 0.1);
            border-color: var(--gold);
            transform: translateY(-2px);
            box-shadow: 0 8px 24px rgba(255, 214, 77, 0.2);
          }

          .wallet-option.unavailable,
          .wallet-option.coming-soon {
            opacity: 0.5;
            cursor: pointer;
          }

          .wallet-option.unavailable:hover,
          .wallet-option.coming-soon:hover {
            background: rgba(255, 255, 255, 0.05);
            border-color: rgba(255, 255, 255, 0.2);
          }

          .wallet-option-icon {
            font-size: 28px;
            width: 40px;
            text-align: center;
          }

          .wallet-option-name {
            flex: 1;
            text-align: left;
          }

          .wallet-option-badge {
            font-size: 9px;
            font-weight: 700;
            color: #ffc107;
            background: rgba(255, 193, 7, 0.2);
            padding: 4px 8px;
            border-radius: 6px;
            letter-spacing: 0.5px;
          }

          .wallet-option-status {
            font-size: 11px;
            color: #666;
          }

          .wallet-option-arrow {
            font-size: 18px;
            color: var(--gold);
            opacity: 0;
            transform: translateX(-8px);
            transition: all 0.2s ease;
          }

          .wallet-option:hover .wallet-option-arrow {
            opacity: 1;
            transform: translateX(0);
          }

          .wallet-selector-footer {
            margin-top: 24px;
            padding-top: 20px;
            border-top: 1px solid rgba(255, 255, 255, 0.1);
            text-align: center;
          }

          .wallet-selector-footer p {
            font-family: Inter, system-ui, Arial;
            font-size: 11px;
            color: #666;
            margin: 0;
          }

          .wallet-selector-footer a {
            color: var(--gold);
            text-decoration: none;
          }

          .wallet-selector-footer a:hover {
            text-decoration: underline;
          }
        `;

        document.head.appendChild(styles);
        document.body.appendChild(overlay);

        // Close function
        const closeSelector = () => {
          overlay.remove();
          styles.remove();
          reject(new Error('User cancelled'));
        };

        // Close button handler
        document.getElementById('wallet-close-btn').addEventListener('click', closeSelector);

        // Click outside to close
        overlay.addEventListener('click', (e) => {
          if (e.target === overlay) closeSelector();
        });

        // Escape key to close
        const escHandler = (e) => {
          if (e.key === 'Escape') {
            closeSelector();
            document.removeEventListener('keydown', escHandler);
          }
        };
        document.addEventListener('keydown', escHandler);

        // Wallet option click handlers
        document.querySelectorAll('.wallet-option').forEach(btn => {
          btn.addEventListener('click', () => {
            const walletId = btn.getAttribute('data-wallet');
            const isUnavailable = btn.getAttribute('data-unavailable');
            const isComingSoon = btn.getAttribute('data-coming-soon');

            if (isComingSoon) {
              Toast.info('WalletConnect coming soon!', 'COMING SOON');
              return;
            }

            if (isUnavailable) {
              let installUrl = 'https://metamask.io/download/';
              if (walletId === 'coinbase') installUrl = 'https://www.coinbase.com/wallet';
              if (walletId === 'trust') installUrl = 'https://trustwallet.com/download';

              window.open(installUrl, '_blank');
              return;
            }

            overlay.remove();
            styles.remove();
            document.removeEventListener('keydown', escHandler);
            resolve(walletId);
          });
        });
      });
    }

    // Track if we're in the middle of connecting (to prevent reload)
    let isConnecting = false;
    let walletListenersAdded = false;

    // Connect wallet
    async function connectWallet() {
      const walletId = await showWalletSelector();
      selectedWalletType = walletId;

      if (!window.ethereum) {
        throw new Error('No wallet detected');
      }

      isConnecting = true;
      web3Provider = new ethers.providers.Web3Provider(window.ethereum);

      // Only add event listeners once, and respect isConnecting flag
      if (!walletListenersAdded) {
        walletListenersAdded = true;

        // Handle account/chain changes - but not during initial connection
        window.ethereum.on("accountsChanged", (accounts) => {
          if (isConnecting) return; // Don't reload during connection flow
          if (accounts.length === 0) {
            disconnectWallet();
          } else {
            window.location.reload();
          }
        });

        window.ethereum.on("chainChanged", () => {
          if (isConnecting) return; // Don't reload during connection flow
          window.location.reload();
        });
      }

      return web3Provider;
    }

    // Mark connection as complete (call after successful login/registration)
    function finishWalletConnection() {
      isConnecting = false;
    }

    // Disconnect wallet
    function disconnectWallet() {
      web3Provider = null;
      selectedWalletType = null;
    }

    // Get connected wallet address
    async function getWalletAddress() {
      if (!web3Provider) {
        await connectWallet();
      }

      // Request accounts
      await window.ethereum.request({ method: 'eth_requestAccounts' });

      const signer = web3Provider.getSigner();
      return await signer.getAddress();
    }

    // Sign message with wallet
    async function signMessage(message) {
      if (!web3Provider) {
        await connectWallet();
      }
      const signer = web3Provider.getSigner();
      return await signer.signMessage(message);
    }

    // ===== MODAL SYSTEM =====
    const Modal = {
      overlay: null,
      title: null,
      body: null,
      actions: null,
      confirmBtn: null,
      cancelBtn: null,
      closeBtn: null,
      resolveCallback: null,

      init() {
        this.overlay = document.getElementById('modalOverlay');
        this.title = document.getElementById('modalTitle');
        this.body = document.getElementById('modalBody');
        this.actions = document.getElementById('modalActions');
        this.confirmBtn = document.getElementById('modalConfirmBtn');
        this.cancelBtn = document.getElementById('modalCancelBtn');
        this.closeBtn = document.getElementById('modalClose');

        // Close modal handlers
        this.closeBtn.addEventListener('click', () => this.close(false));
        this.cancelBtn.addEventListener('click', () => this.close(false));
        this.confirmBtn.addEventListener('click', () => this.close(true));

        // Close on overlay click
        this.overlay.addEventListener('click', (e) => {
          if (e.target === this.overlay) this.close(false);
        });

        // Close on ESC key
        document.addEventListener('keydown', (e) => {
          if (e.key === 'Escape' && this.overlay.classList.contains('show')) {
            this.close(false);
          }
        });
      },

      show(options) {
        return new Promise((resolve) => {
          this.resolveCallback = resolve;

          this.title.textContent = options.title || 'Confirmation';

          // Support HTML content
          if (options.html) {
            this.body.innerHTML = options.html;
          } else {
            this.body.textContent = options.message || '';
          }

          // Show/hide action buttons based on type
          if (options.type === 'alert') {
            this.cancelBtn.style.display = 'none';
            this.confirmBtn.textContent = 'OK';
            this.actions.style.display = 'flex';
          } else if (options.type === 'custom') {
            // Hide all action buttons for custom modals
            this.actions.style.display = 'none';
          } else {
            this.cancelBtn.style.display = 'block';
            this.confirmBtn.textContent = options.confirmText || 'CONFIRM';
            this.cancelBtn.textContent = options.cancelText || 'CANCEL';
            this.actions.style.display = 'flex';
          }

          this.overlay.classList.add('show');
        });
      },

      close(confirmed = false) {
        this.overlay.classList.remove('show');
        // Reset actions display
        this.actions.style.display = 'flex';
        if (this.resolveCallback) {
          this.resolveCallback(confirmed);
          this.resolveCallback = null;
        }
      },

      alert(message, title = 'Alert') {
        return this.show({ type: 'alert', message, title });
      },

      confirm(message, title = 'Confirmation') {
        return this.show({ type: 'confirm', message, title });
      }
    };

    // ===== TOAST NOTIFICATION SYSTEM =====
    const Toast = {
      container: null,

      init() {
        this.container = document.getElementById('toastContainer');
      },

      show(options) {
        const toast = document.createElement('div');
        toast.className = `toast toast-${options.type || 'info'}`;

        const icon = this.getIcon(options.type);
        const title = options.title || this.getDefaultTitle(options.type);

        toast.innerHTML = `
          <div class="toast-icon">${icon}</div>
          <div class="toast-content">
            <div class="toast-title">${title}</div>
            ${options.message ? `<div class="toast-message">${options.message}</div>` : ''}
          </div>
        `;

        this.container.appendChild(toast);

        // Auto dismiss after duration
        const duration = options.duration || 3000;
        setTimeout(() => {
          this.remove(toast);
        }, duration);

        return toast;
      },

      remove(toast) {
        toast.classList.add('removing');
        setTimeout(() => {
          if (toast.parentNode) {
            toast.parentNode.removeChild(toast);
          }
        }, 300);
      },

      success(message, title) {
        return this.show({ type: 'success', message, title });
      },

      error(message, title) {
        return this.show({ type: 'error', message, title });
      },

      warning(message, title) {
        return this.show({ type: 'warning', message, title });
      },

      info(message, title) {
        return this.show({ type: 'info', message, title });
      },

      getIcon(type) {
        const icons = {
          success: '✓',
          error: '✕',
          warning: '⚠',
          info: 'ℹ'
        };
        return icons[type] || icons.info;
      },

      getDefaultTitle(type) {
        const titles = {
          success: 'SUCCESS',
          error: 'ERROR',
          warning: 'WARNING',
          info: 'INFO'
        };
        return titles[type] || 'INFO';
      }
    };

    // ===== LOADING OVERLAY =====
    const Loading = {
      overlay: null,
      text: null,

      init() {
        this.overlay = document.getElementById('loadingOverlay');
        this.text = document.getElementById('loadingText');
      },

      show(message = 'Loading...') {
        this.text.textContent = message;
        this.overlay.style.display = 'flex';
      },

      hide() {
        this.overlay.style.display = 'none';
      }
    };

    // Initialize systems on DOM ready
    document.addEventListener('DOMContentLoaded', async () => {
      Modal.init();
      Toast.init();
      Loading.init();

      // Parse URL parameters for referral code
      const urlParams = new URLSearchParams(window.location.search);
      const refCode = urlParams.get('ref');
      if (refCode) {
        tempRegistrationData.inviteCode = refCode;
      }

      // Set up event listeners for initial home page
      const connectWalletBtn = document.getElementById('connectWalletBtn');
      if (connectWalletBtn) {
        connectWalletBtn.addEventListener('click', handleUnifiedWalletConnect);
      }

      // Initialize app - check for existing session (Blur-style auto-reconnect)
      await initializeApp();
    });

    // Particle System
    class ParticleSystem {
      constructor(canvas) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.particles = [];
        this.resize();
        window.addEventListener('resize', () => this.resize());
        this.animate();
      }

      resize() {
        this.canvas.width = window.innerWidth;
        this.canvas.height = window.innerHeight;
      }

      createLavaEmber() {
        // Embers rise from lava areas (bottom 40% of screen, concentrated in center-right where lava is)
        return {
          x: Math.random() * this.canvas.width * 0.7 + this.canvas.width * 0.15, // Center 70% of screen
          y: this.canvas.height - Math.random() * 50, // Start near bottom
          vx: (Math.random() - 0.5) * 0.3, // Slight horizontal drift
          vy: -(Math.random() * 0.8 + 0.3), // Rise upward (slower)
          size: Math.random() * 3 + 1, // 1-4px
          life: 1,
          decay: Math.random() * 0.003 + 0.001, // Fade out slowly
          color: Math.random() > 0.5 ? 'rgba(255,140,60,' : 'rgba(255,100,40,', // Orange/red
          twinkle: Math.random() * Math.PI * 2,
          twinkleSpeed: Math.random() * 0.05 + 0.02,
          type: 'ember'
        };
      }

      createTwinklingStar() {
        // Stars appear in top 30% of screen with size variations
        const sizeRoll = Math.random();
        let size, glowIntensity;

        if (sizeRoll > 0.95) {
          // 5% chance - Large bright star
          size = Math.random() * 1.5 + 2.5; // 2.5-4px
          glowIntensity = 1.2;
        } else if (sizeRoll > 0.7) {
          // 25% chance - Medium star
          size = Math.random() * 1 + 1.5; // 1.5-2.5px
          glowIntensity = 0.9;
        } else {
          // 70% chance - Small star
          size = Math.random() * 0.8 + 0.5; // 0.5-1.3px
          glowIntensity = 0.6;
        }

        return {
          x: Math.random() * this.canvas.width,
          y: Math.random() * this.canvas.height * 0.3, // Top 30%
          vx: 0,
          vy: 0,
          size: size,
          life: 1,
          decay: 0, // Stars don't fade out
          color: 'rgba(255,255,255,',
          twinkle: Math.random() * Math.PI * 2,
          twinkleSpeed: Math.random() * 0.03 + 0.01,
          glowIntensity: glowIntensity,
          type: 'star'
        };
      }

      createShootingStar() {
        // Shooting stars streak across the top half
        const startSide = Math.random() > 0.5 ? 'left' : 'right';
        return {
          x: startSide === 'left' ? 0 : this.canvas.width,
          y: Math.random() * this.canvas.height * 0.4, // Top 40%
          vx: (startSide === 'left' ? 1 : -1) * (Math.random() * 3 + 4), // Fast horizontal
          vy: Math.random() * 0.5 + 0.5, // Slight downward angle
          size: Math.random() * 1 + 1.5, // 1.5-2.5px
          life: 1,
          decay: 0.015, // Fade quickly
          color: 'rgba(255,255,220,',
          tailLength: Math.random() * 40 + 60, // 60-100px tail
          type: 'shooting'
        };
      }

      animate() {
        requestAnimationFrame(() => this.animate());

        // Clear canvas
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

        // Add new particles
        if (Math.random() < 0.15) { // 15% chance each frame for embers
          this.particles.push(this.createLavaEmber());
        }

        // Occasionally add shooting stars (rare)
        if (Math.random() < 0.002) { // 0.2% chance per frame (~1 every 8 seconds)
          this.particles.push(this.createShootingStar());
        }

        // Update and draw particles
        this.particles = this.particles.filter(p => {
          // Update position
          p.x += p.vx;
          p.y += p.vy;

          // Update life
          p.life -= p.decay;

          // Update twinkle (if applicable)
          if (p.twinkle !== undefined) {
            p.twinkle += p.twinkleSpeed;
          }

          // Calculate opacity and draw based on type
          let opacity;

          if (p.type === 'star') {
            opacity = (Math.sin(p.twinkle) * 0.3 + 0.7) * 0.6 * p.glowIntensity;
            this.ctx.shadowBlur = p.size * 8 * p.glowIntensity;
            this.ctx.shadowColor = `rgba(255,255,255,${0.8 * p.glowIntensity})`;
            this.ctx.fillStyle = p.color + opacity + ')';
            this.ctx.beginPath();
            this.ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
            this.ctx.fill();

          } else if (p.type === 'shooting') {
            opacity = p.life;
            // Draw shooting star trail
            const gradient = this.ctx.createLinearGradient(
              p.x, p.y,
              p.x - p.vx * p.tailLength / 5, p.y - p.vy * p.tailLength / 5
            );
            gradient.addColorStop(0, `rgba(255,255,220,${opacity * 0.8})`);
            gradient.addColorStop(0.5, `rgba(255,255,255,${opacity * 0.4})`);
            gradient.addColorStop(1, 'rgba(255,255,255,0)');

            this.ctx.shadowBlur = 15;
            this.ctx.shadowColor = `rgba(255,255,220,${opacity})`;
            this.ctx.strokeStyle = gradient;
            this.ctx.lineWidth = p.size * 2;
            this.ctx.lineCap = 'round';
            this.ctx.beginPath();
            this.ctx.moveTo(p.x, p.y);
            this.ctx.lineTo(p.x - p.vx * 10, p.y - p.vy * 10);
            this.ctx.stroke();

            // Draw bright head
            this.ctx.fillStyle = `rgba(255,255,255,${opacity})`;
            this.ctx.beginPath();
            this.ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
            this.ctx.fill();

          } else { // ember
            opacity = p.life * (Math.sin(p.twinkle) * 0.2 + 0.8);
            this.ctx.shadowBlur = p.size * 8;
            this.ctx.shadowColor = 'rgba(255,140,60,0.6)';
            this.ctx.fillStyle = p.color + opacity + ')';
            this.ctx.beginPath();
            this.ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
            this.ctx.fill();
          }

          // Keep particle if alive and on screen
          if (p.type === 'star') {
            return true; // Stars stay forever
          } else if (p.type === 'shooting') {
            return p.life > 0 && p.x > -100 && p.x < this.canvas.width + 100; // Shooting stars fade or leave screen
          } else {
            return p.life > 0 && p.y > -50; // Embers fade or go off screen
          }
        });

        // Maintain star count
        const starCount = this.particles.filter(p => p.type === 'star').length;
        if (starCount < 40) { // Keep ~40 stars with variations
          this.particles.push(this.createTwinklingStar());
        }
      }
    }

    // Initialize particle system
    const particlesCanvas = document.getElementById('particlesCanvas');
    const particleSystem = new ParticleSystem(particlesCanvas);

    // Single page app logic
    const pageContainer = document.getElementById('pageContainer');
    const panelContent = document.getElementById('panelContent');
    const dashboardContent = document.getElementById('dashboardContent');
    const leaderboardContent = document.getElementById('leaderboardContent');
    const questContent = document.getElementById('questContent');
    const referralsContent = document.getElementById('referralsContent');
    const inventoryContent = document.getElementById('inventoryContent');
    const shopContent = document.getElementById('shopContent');
    const ovenContent = document.getElementById('ovenContent');
    const farmContent = document.getElementById('farmContent');
    const gameContent = document.getElementById('gameContent');

    // Debug: Check if all elements exist
    console.log('Elements loaded:', {
      pageContainer: !!pageContainer,
      panelContent: !!panelContent,
      dashboardContent: !!dashboardContent,
      leaderboardContent: !!leaderboardContent,
      questContent: !!questContent,
      inventoryContent: !!inventoryContent,
      viewLeaderboardBtn: !!document.getElementById('viewLeaderboardBtn')
    });
    
    // Game variables
    let gameState = {
      attempts: [],
      bestTime: null,
      isPlaying: false,
      startTime: null,
      reactionTimer: null,
      chartAnimation: null
    };

    // Temporary registration data
    let tempRegistrationData = {
      walletAddress: '',
      inviteCode: '',
      signature: '',
      termsAccepted: false
    };
    // Helper function to hide all content containers
    function hideAllContainers() {
      panelContent.style.display = 'none';
      dashboardContent.style.display = 'none';
      leaderboardContent.style.display = 'none';
      questContent.style.display = 'none';
      referralsContent.style.display = 'none';
      inventoryContent.style.display = 'none';
      shopContent.style.display = 'none';
      ovenContent.style.display = 'none';
      farmContent.style.display = 'none';
      gameContent.style.display = 'none';
    }


    // Helper function to swap content with fade animation
    function swapContent(newContent, data) {
      console.log('[swapContent] Switching to:', newContent);
      // Find currently visible element
      const allContainers = [panelContent, dashboardContent, leaderboardContent, questContent, referralsContent, inventoryContent, shopContent, ovenContent, farmContent, gameContent];
      const currentVisible = allContainers.find(el => el.style.display !== 'none' && el.style.display !== '');
      console.log('[swapContent] Current visible:', currentVisible?.id || 'none');

      // Add fade-out to current visible element
      if (currentVisible) {
        currentVisible.classList.add('fade-out');
        currentVisible.classList.remove('fade-in', 'fade-in-delayed');
      }

      // Wait for fade-out animation, then swap content
      setTimeout(() => {
        console.log('[swapContent] Timeout fired, executing case:', newContent);
        if (newContent === 'login') {
          panelContent.style.display = 'block';
          dashboardContent.style.display = 'none';
          leaderboardContent.style.display = 'none';
          questContent.style.display = 'none';
          inventoryContent.style.display = 'none';
          panelContent.classList.remove('panel-transparent');
          pageContainer.classList.remove('bottom-aligned');

          panelContent.innerHTML = `
          <div class="panel-header">
            <div class="sys">Welcome back, champion<span class="blink">.</span></div>
            <div class="sub-text">Connect your wallet to access the arena</div>
          </div>

          <div style="text-align:center;padding:40px 20px;">
            <div style="margin-bottom:20px;">
              <svg width="64" height="64" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
                <polygon points="50,5 90,27.5 90,72.5 50,95 10,72.5 10,27.5"
                         fill="none"
                         stroke="url(#walletLoginGradient)"
                         stroke-width="4"/>
                <circle cx="40" cy="50" r="10" fill="#22c55e"/>
                <circle cx="60" cy="50" r="10" fill="#ef4444"/>
                <defs>
                  <linearGradient id="walletLoginGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                    <stop offset="0%" style="stop-color:#FFD64D;stop-opacity:1" />
                    <stop offset="50%" style="stop-color:#D4AF37;stop-opacity:1" />
                    <stop offset="100%" style="stop-color:#D4A033;stop-opacity:1" />
                  </linearGradient>
                </defs>
              </svg>
            </div>
            <div style="font-family:'Press Start 2P',monospace;font-size:12px;color:var(--gold);margin-bottom:12px;">
              WALLET AUTHENTICATION
            </div>
            <div style="font-family:Inter,system-ui,Arial;font-size:14px;color:#a0a8b0;margin-bottom:30px;line-height:1.6;">
              Sign in with your connected wallet.<br>
              Only wallets with existing accounts can login.
            </div>
            <button class="btn-submit" id="walletLoginBtn" style="width:100%;max-width:300px;">
              SIGN IN WITH WALLET
            </button>
          </div>

          <div class="helper">
            Don't have an account? <a id="backLink">Create account</a>
          </div>
        `;

        // Re-attach event listeners
        document.getElementById('walletLoginBtn').addEventListener('click', handleWalletLogin);
        const backLink = document.getElementById('backLink');
        backLink.addEventListener('click', () => swapContent('home'));
        backLink.addEventListener('keypress', (e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            swapContent('home');
          }
        });

      } else if (newContent === 'termsAcceptance') {
        panelContent.style.display = 'block';
        dashboardContent.style.display = 'none';
        leaderboardContent.style.display = 'none';
        questContent.style.display = 'none';
        inventoryContent.style.display = 'none';
        pageContainer.classList.add('center-aligned');
        pageContainer.classList.remove('bottom-aligned');
        panelContent.classList.remove('panel-transparent');

        panelContent.innerHTML = `
          <div class="panel-header">
            <div class="warrior-title">TERMS & DISCLAIMER</div>
            <div class="sub-text">Please read and accept to continue</div>
          </div>

          <div style="max-width:500px;margin:0 auto;padding:20px;">
            <div style="background:#1a1a1a;border:1px solid #333;border-radius:8px;padding:20px;margin-bottom:20px;max-height:300px;overflow-y:auto;text-align:left;font-size:13px;line-height:1.6;color:#a0a8b0;">
              <p style="color:var(--gold);font-weight:bold;margin-bottom:10px;">⚠️ IMPORTANT - READ CAREFULLY</p>
              <p style="margin-bottom:10px;">By connecting your wallet and using this service, you acknowledge and agree that:</p>
              <ul style="margin-left:20px;margin-bottom:15px;">
                <li style="margin-bottom:8px;">This is <strong>experimental alpha software</strong> provided "AS IS" without warranties of any kind</li>
                <li style="margin-bottom:8px;">Virtual items (NFTs, GC, tokens) have <strong>NO monetary value</strong> and are <strong>NOT investment vehicles</strong></li>
                <li style="margin-bottom:8px;">This project <strong>may never fully launch</strong>, be completed, or continue development</li>
                <li style="margin-bottom:8px;">The service may be modified, suspended, or <strong>discontinued at any time</strong> without notice</li>
                <li style="margin-bottom:8px;">You are using this platform for <strong>entertainment purposes only</strong> at your own risk</li>
                <li style="margin-bottom:8px;"><strong>No promises or guarantees</strong> are made about future features, updates, or token launches</li>
                <li style="margin-bottom:8px;">All blockchain transactions are <strong>irreversible</strong> and you are solely responsible for your wallet security</li>
                <li style="margin-bottom:8px;">You must be <strong>18 years or older</strong> to use this service</li>
              </ul>
              <p style="font-size:11px;color:#666;">For full terms, see our <a href="#" style="color:var(--gold);">Terms of Service</a> and <a href="#" style="color:var(--gold);">Privacy Policy</a></p>
            </div>

            <div class="input-group" style="margin-bottom:20px;">
              <label style="display:flex;align-items:start;cursor:pointer;font-size:14px;color:#e5e7eb;">
                <input type="checkbox" id="termsCheckbox" style="margin-right:12px;margin-top:4px;width:18px;height:18px;cursor:pointer;">
                <span>I have read and agree to the Terms of Service. I understand this is experimental software, virtual items have no value, and the project may never launch.</span>
              </label>
              <div class="error-msg" id="termsError"></div>
            </div>

            <div style="display:flex;gap:10px;">
              <button class="btn-cancel" id="backToWalletBtn" style="flex:1;">← BACK</button>
              <button class="btn-submit" id="acceptTermsBtn" style="flex:2;">ACCEPT & CONTINUE</button>
            </div>
          </div>
        `;

        // Re-attach event listeners
        document.getElementById('acceptTermsBtn').addEventListener('click', handleTermsAcceptance);
        document.getElementById('backToWalletBtn').addEventListener('click', () => swapContent('home'));
        document.getElementById('termsCheckbox').addEventListener('change', () => clearError('termsError'));

      } else if (newContent === 'nameWarrior') {
        panelContent.style.display = 'block';
        dashboardContent.style.display = 'none';
        leaderboardContent.style.display = 'none';
        questContent.style.display = 'none';
        inventoryContent.style.display = 'none';
        pageContainer.classList.add('center-aligned');
        pageContainer.classList.remove('bottom-aligned');
        panelContent.classList.remove('panel-transparent');

        panelContent.innerHTML = `
          <div class="panel-header">
            <div class="warrior-title">your legend begins here</div>
            <div class="sub-text">Choose a name that strikes fear into your enemies</div>
          </div>

          <div class="input-group">
            <input id="warriorName" class="warrior-input" type="text" placeholder="NAME YOUR WARRIOR" maxlength="16" autocomplete="off">
            <div class="error-msg" id="warriorNameError"></div>
          </div>

          <div class="input-group">
            <label class="input-label" style="font-size:12px;color:#888;">Referral Code (Optional)</label>
            <input id="referralCode" class="warrior-input" type="text" placeholder="enter code" maxlength="16" autocomplete="off">
            <div class="error-msg" id="referralCodeError"></div>
          </div>

          <div class="input-group">
            <button class="btn-submit" id="confirmNameBtn" style="width:100%;">ENTER THE ARENA</button>
          </div>
        `;

        panelContent.classList.remove('fade-in', 'warrior-naming');
        void panelContent.offsetWidth;
        panelContent.classList.add('warrior-naming');

        // Prefill referral code if available from URL
        if (tempRegistrationData.inviteCode) {
          setTimeout(() => {
            const referralInput = document.getElementById('referralCode');
            if (referralInput) {
              referralInput.value = tempRegistrationData.inviteCode;
            }
          }, 100);
        }

        // Re-attach event listeners
        document.getElementById('confirmNameBtn').addEventListener('click', handleNameWarrior);
        document.getElementById('warriorName').addEventListener('input', () => clearError('warriorNameError'));
        document.getElementById('warriorName').addEventListener('keypress', (e) => {
          if (e.key === 'Enter') handleNameWarrior();
        });
        // Auto-focus the input
        setTimeout(() => {
          document.getElementById('warriorName').focus();
        }, 500);

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
            <div style="margin-bottom:20px;">
              <svg width="64" height="64" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
                <polygon points="50,5 90,27.5 90,72.5 50,95 10,72.5 10,27.5"
                         fill="none"
                         stroke="url(#walletConnectGradient)"
                         stroke-width="4"/>
                <circle cx="40" cy="50" r="10" fill="#22c55e"/>
                <circle cx="60" cy="50" r="10" fill="#ef4444"/>
                <defs>
                  <linearGradient id="walletConnectGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                    <stop offset="0%" style="stop-color:#FFD64D;stop-opacity:1" />
                    <stop offset="50%" style="stop-color:#D4AF37;stop-opacity:1" />
                    <stop offset="100%" style="stop-color:#D4A033;stop-opacity:1" />
                  </linearGradient>
                </defs>
              </svg>
            </div>
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

        // Store the code for later use (only if explicitly provided)
        if (data !== undefined) {
          tempRegistrationData.inviteCode = data;
        }

        document.getElementById('connectWalletForRegBtn').addEventListener('click', handleWalletConnectForRegistration);
        document.getElementById('backToCodeLink').addEventListener('click', () => swapContent('home'));

      } else if (newContent === 'connectWalletForReg') {
        panelContent.style.display = 'block';
        dashboardContent.style.display = 'none';
        leaderboardContent.style.display = 'none';
        questContent.style.display = 'none';
        inventoryContent.style.display = 'none';
        pageContainer.classList.add('center-aligned');
        pageContainer.classList.remove('bottom-aligned');
        panelContent.classList.remove('panel-transparent');

        panelContent.innerHTML = `
          <div class="panel-header">
            <div class="warrior-title">CREATE ACCOUNT</div>
            <div class="sub-text">Connect your wallet to begin your journey</div>
          </div>

          <div class="wallet-connect-container" style="text-align:center;padding:40px 20px;">
            <div style="margin-bottom:20px;">
              <svg width="64" height="64" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
                <polygon points="50,5 90,27.5 90,72.5 50,95 10,72.5 10,27.5"
                         fill="none"
                         stroke="url(#walletRegGradient)"
                         stroke-width="4"/>
                <circle cx="40" cy="50" r="10" fill="#22c55e"/>
                <circle cx="60" cy="50" r="10" fill="#ef4444"/>
                <defs>
                  <linearGradient id="walletRegGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                    <stop offset="0%" style="stop-color:#FFD64D;stop-opacity:1" />
                    <stop offset="50%" style="stop-color:#D4AF37;stop-opacity:1" />
                    <stop offset="100%" style="stop-color:#D4A033;stop-opacity:1" />
                  </linearGradient>
                </defs>
              </svg>
            </div>
            <div style="font-family:'Press Start 2P',monospace;font-size:12px;color:var(--gold);margin-bottom:12px;">
              NEW WARRIOR REGISTRATION
            </div>
            <div style="font-family:Inter,system-ui,Arial;font-size:14px;color:#a0a8b0;margin-bottom:30px;line-height:1.6;">
              Connect your wallet to create a new account.<br>
              You'll be asked to sign a message to prove ownership.<br>
              <strong style="color:var(--gold);">No transaction, no gas fees.</strong>
            </div>
            <button class="btn-submit" id="connectWalletRegBtn" style="width:100%;max-width:300px;">
              CONNECT WALLET
            </button>
            <div style="margin-top:20px;">
              <a id="backToHomeLink" style="color:#6b7280;font-size:12px;cursor:pointer;text-decoration:underline;">
                ← Back
              </a>
            </div>
          </div>
        `;

        document.getElementById('connectWalletRegBtn').addEventListener('click', handleWalletConnectForRegistration);
        document.getElementById('backToHomeLink').addEventListener('click', () => swapContent('home'));

      } else if (newContent === 'home') {
        panelContent.style.display = 'block';
        dashboardContent.style.display = 'none';
        leaderboardContent.style.display = 'none';
        questContent.style.display = 'none';
        inventoryContent.style.display = 'none';
        pageContainer.classList.add('bottom-aligned');
        pageContainer.classList.remove('center-aligned');
        panelContent.classList.add('panel-transparent');

        // Create glass card wrapper if it doesn't exist
        let glassWrapper = pageContainer.querySelector('.glass-card-wrapper');
        if (!glassWrapper) {
          glassWrapper = document.createElement('div');
          glassWrapper.className = 'glass-card-wrapper';
          glassWrapper.style.cssText = 'background:rgba(0,0,0,0.75);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);border:2px solid rgba(255,214,77,0.3);border-radius:20px;padding:32px;width:min(800px,92vw);margin-left:auto;margin-right:auto;box-shadow:0 8px 32px rgba(0,0,0,0.5), 0 0 0 1px rgba(255,255,255,0.1) inset;';

          // Create banner inside wrapper
          const banner = document.createElement('div');
          banner.className = 'campaign-end-banner';
          banner.style.cssText = 'background:linear-gradient(135deg, rgba(212,175,55,0.15) 0%, rgba(255,214,77,0.1) 100%);border:2px solid rgba(255,214,77,0.5);border-radius:12px;padding:28px 32px;margin-bottom:24px;text-align:center;box-shadow:0 4px 16px rgba(255,214,77,0.2);';
          banner.innerHTML = `
            <div style="font-size:32px;margin-bottom:12px;">⚔️</div>
            <div style="font-family:'Press Start 2P',monospace;font-size:14px;color:#FFD700;margin-bottom:16px;line-height:1.6;text-shadow:0 2px 4px rgba(0,0,0,0.5);">PRE-SEASON COMPLETE</div>
            <div style="font-family:'Courier New',monospace;font-size:15px;color:#ffffff;line-height:1.8;margin-bottom:8px;">
              Thank you for participating in the campaign!
            </div>
            <div style="font-family:'Courier New',monospace;font-size:14px;color:#4CAF50;line-height:1.8;">
              Founder's Swords minting Monday, December 22 • Season 1 coming soon
            </div>
          `;
          glassWrapper.appendChild(banner);

          // Create About section inside wrapper
          const aboutSection = document.createElement('div');
          aboutSection.className = 'campaign-earn-section';
          aboutSection.style.cssText = 'margin-bottom:24px;';
          aboutSection.innerHTML = `
            <div class="campaign-earn-title">ABOUT</div>

            <!-- Main Description -->
            <div style="background:rgba(0,0,0,0.5);border:2px solid rgba(255,214,77,0.4);border-radius:12px;padding:28px;margin-bottom:24px;box-shadow:0 4px 12px rgba(0,0,0,0.3);">
              <div style="font-family:'Press Start 2P',monospace;font-size:11px;color:#FFD700;margin-bottom:20px;text-align:center;letter-spacing:1px;">FULLY ON-CHAIN MMO</div>
              <div style="font-family:'Courier New',monospace;font-size:14px;line-height:2;color:#ffffff;text-align:left;padding:0 12px;text-shadow:0 1px 3px rgba(0,0,0,0.8);">
                <strong style="color:#FFD700;">Duel PVP</strong> combines classic MMO progression with idle game mechanics. Build your empire while you sleep, or actively dominate the arena—the choice is yours.
                <br><br>
                <strong style="color:#4CAF50;">Every game state, transaction, and mechanic lives on the blockchain.</strong>
                <br>
                No centralized servers. No hidden RNG. Trustless, transparent, verifiable by anyone.
              </div>
            </div>

            <!-- Two Paths -->
            <div style="font-family:'Press Start 2P',monospace;font-size:11px;color:#FFD700;margin-bottom:20px;text-align:center;letter-spacing:1px;">
              CHOOSE YOUR PATH:
            </div>

            <div class="campaign-cards-row">
              <!-- Left: Cultivator (green like DeFi) -->
              <div class="campaign-card invest">
                <div class="campaign-card-title">THE CULTIVATOR</div>
                <div style="font-family:'Courier New',monospace;font-size:14px;line-height:1.7;color:#ffffff;text-align:center;margin-bottom:16px;text-shadow:0 2px 4px rgba(0,0,0,0.8);">
                  <strong style="color:#4CAF50;">Low-risk, steady growth.</strong><br><br>
                  Farm resources, control markets, hire warriors to fight for you.<br>
                  Build wealth through strategic resource management.
                </div>
              </div>

              <!-- Right: Warrior (red like Gambling) -->
              <div class="campaign-card gamble">
                <div class="campaign-card-title">THE WARRIOR</div>
                <div style="font-family:'Courier New',monospace;font-size:14px;line-height:1.7;color:#ffffff;text-align:center;margin-bottom:16px;text-shadow:0 2px 4px rgba(0,0,0,0.8);">
                  <strong style="color:#F44336;">High-risk, high-reward.</strong><br><br>
                  Raid dungeons, slay legendary bosses, dominate the PVP arena.<br>
                  Earn through combat prowess and fearless execution.
                </div>
              </div>
            </div>

            <div style="text-align:center;margin-top:20px;">
              <span style="color:#FFD700;font-size:13px;font-family:'Courier New',monospace;">Launch planned 2026 (subject to change)</span>
            </div>
          `;
          glassWrapper.appendChild(aboutSection);

          // Update panel content
          panelContent.innerHTML = `
            <div class="panel-header" style="margin-top:0px;text-align:center;">
              <div class="sys" style="font-size:12px;color:#888;">Campaign has ended<span class="blink">.</span></div>
              <div class="sub-text" style="font-size:11px;color:#666;">Login temporarily disabled</div>
            </div>

            <div class="input-group" style="display:none;">
              <button class="btn-submit" id="connectWalletBtnHome" style="width:100%;">CONNECT WALLET</button>
            </div>
          `;

          // Move panel into wrapper and insert wrapper into page
          glassWrapper.appendChild(panelContent);
          pageContainer.insertBefore(glassWrapper, pageContainer.firstChild);
        } else {
          // Glass wrapper exists, just update panel content
          panelContent.innerHTML = `
            <div class="panel-header" style="margin-top:0px;text-align:center;">
              <div class="sys" style="font-size:12px;color:#888;">Campaign has ended<span class="blink">.</span></div>
              <div class="sub-text" style="font-size:11px;color:#666;">Login temporarily disabled</div>
            </div>

            <div class="input-group" style="display:none;">
              <button class="btn-submit" id="connectWalletBtnHome" style="width:100%;">CONNECT WALLET</button>
            </div>
          `;
        }

      } else if (newContent === 'dashboard') {
        console.log('[dashboard case] Starting dashboard case');
        hideAllContainers();
        console.log('[dashboard case] hideAllContainers called');
        dashboardContent.style.display = 'block';
        console.log('[dashboard case] dashboardContent.style.display set to block');
        console.log('[dashboard case] dashboardContent element:', dashboardContent);
        console.log('[dashboard case] dashboardContent computed display:', window.getComputedStyle(dashboardContent).display);
        pageContainer.classList.remove('center-aligned', 'bottom-aligned');
        // Force refresh GC cache and display when loading dashboard
        gcCache.lastFetch = 0;
        updateDashboardStats();
        // Load user's invite code
        loadUserInviteCode();
        // Also directly update GC display to ensure it shows
        (async () => {
          const gp = await getUserGC();
          const displayGP = gp >= 1000000 ? `${(gp/1000000).toFixed(1)}M` : gp >= 1000 ? `${(gp/1000).toFixed(1)}K` : gp;
          document.getElementById('dashboardGCBalance').textContent = displayGP;
          console.log('[Dashboard] GC display updated:', gp);
          // Update campaign rank display
          updateCampaignRank();
        })();





      } else if (newContent === 'mines') {
        // DISABLED: Mines game temporarily unavailable
        Toast.error('Mines game is temporarily unavailable', 'GAME DISABLED');
        swapContent('dashboard');
        return;


      } else if (newContent === 'leaderboard') {
        console.log('Switching to leaderboard...');
        hideAllContainers();
        leaderboardContent.style.display = 'block';
        pageContainer.classList.remove('center-aligned', 'bottom-aligned');
        console.log('Leaderboard display set to block');
        loadLeaderboard('all');
        console.log('loadLeaderboard called');

      } else if (newContent === 'quests') {
        hideAllContainers();
        questContent.style.display = 'block';
        pageContainer.classList.remove('center-aligned', 'bottom-aligned');
        loadQuests('daily');

      } else if (newContent === 'referrals') {
        hideAllContainers();
        referralsContent.style.display = 'block';
        pageContainer.classList.remove('center-aligned', 'bottom-aligned');
        loadReferralStats();

      } else if (newContent === 'inventory') {
        hideAllContainers();
        inventoryContent.style.display = 'block';
        pageContainer.classList.remove('center-aligned', 'bottom-aligned');
        loadInventory();

      } else if (newContent === 'shop') {
        hideAllContainers();
        shopContent.style.display = 'block';
        pageContainer.classList.remove('center-aligned', 'bottom-aligned');

      } else if (newContent === 'game') {
        hideAllContainers();
        gameContent.style.display = 'block';
        pageContainer.classList.remove('center-aligned', 'bottom-aligned');

      } else if (newContent === 'oven') {
        hideAllContainers();
        ovenContent.style.display = 'block';
        pageContainer.classList.remove('center-aligned', 'bottom-aligned');

      } else if (newContent === 'farm') {
        hideAllContainers();
        farmContent.style.display = 'block';
        pageContainer.classList.remove('center-aligned', 'bottom-aligned');

      }

        // Add fade-in animation to newly visible element
        const newVisible = allContainers.find(el => el.style.display === 'block');
        console.log('[swapContent] After all cases, newVisible:', newVisible?.id || 'NONE FOUND');
        console.log('[swapContent] All container states:', allContainers.map(el => `${el.id}: ${el.style.display}`).join(', '));
        if (newVisible) {
          newVisible.classList.remove('fade-out', 'fade-in-delayed');
          void newVisible.offsetWidth; // Force reflow
          newVisible.classList.add('fade-in');
        } else {
          console.error('[swapContent] ERROR: No visible container found after swap!');
        }

        // Scroll to top AFTER content is fully laid out
        requestAnimationFrame(() => {
          requestAnimationFrame(() => {
            window.scrollTo({ top: 0, behavior: 'instant' });
          });
        });
      }, currentVisible ? 200 : 0); // 200ms matches fade-out animation duration
    }
    
    // Validation functions
    function validateEmail(email) {
      const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      return re.test(email);
    }

    function validateAccessCode(code) {
      // Format: ABCD1234 (4 letters + 4 digits)
      const re = /^[A-Z]{4}[0-9]{4}$/i;
      return re.test(code);
    }

    function showError(elementId, message) {
      const errorEl = document.getElementById(elementId);
      if (errorEl) {
        errorEl.textContent = message;
        errorEl.classList.add('show');
      }
    }

    function clearError(elementId) {
      const errorEl = document.getElementById(elementId);
      if (errorEl) {
        errorEl.classList.remove('show');
      }
    }

    // Copy text to clipboard
    async function copyToClipboard(text) {
      try {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          await navigator.clipboard.writeText(text);
        } else {
          // Fallback for older browsers
          const textArea = document.createElement('textarea');
          textArea.value = text;
          textArea.style.position = 'fixed';
          textArea.style.left = '-999999px';
          document.body.appendChild(textArea);
          textArea.select();
          document.execCommand('copy');
          document.body.removeChild(textArea);
        }
      } catch (err) {
        console.error('Failed to copy:', err);
        Toast.error('Failed to copy code', 'TRY AGAIN');
      }
    }

    // Event handlers
    async function handleJoin() {
      const codeInput = document.getElementById('code');
      const code = codeInput.value.trim().toUpperCase();

      clearError('codeError');

      if (!code) {
        showError('codeError', 'Please enter an access code');
        return;
      }

      // Validate code format (ABCD1234)
      if (!validateAccessCode(code)) {
        showError('codeError', 'Invalid code format (expected: ABCD1234)');
        return;
      }

      // Validate code exists in database using secure RPC
      Loading.show('Validating access code...');

      try {
        const { data: validationResult, error: validationError } = await supabase
          .rpc('validate_invite_code', { p_code: code });

        if (validationError) {
          Loading.hide();
          console.error('Code validation error:', validationError);
          showError('codeError', 'Failed to validate code');
          return;
        }

        if (!validationResult.valid) {
          Loading.hide();
          showError('codeError', validationResult.error || 'Invalid invite code');
          return;
        }

        // Code is valid, proceed to wallet connect
        Loading.hide();
        swapContent('walletConnect', code);
      } catch (err) {
        Loading.hide();
        console.error('Code validation error:', err);
        showError('codeError', 'Failed to validate code');
      }
    }

    async function handleWalletConnectForRegistration() {
      try {
        Loading.show('Connecting wallet...');

        // Connect wallet using Web3Modal
        const walletAddress = await getWalletAddress();
        console.log('Wallet connected:', walletAddress);

        // Check if wallet already registered using RPC function (bypasses RLS)
        console.log('Checking if wallet registered...');
        const { data: checkData, error: checkError } = await supabase.rpc('login_with_wallet', {
          p_wallet_address: walletAddress.toLowerCase()
        });
        console.log('login_with_wallet check:', { checkData, checkError });

        if (checkError) {
          Loading.hide();
          console.error('login_with_wallet error:', checkError);
          Modal.alert('Failed to check wallet: ' + checkError.message, 'Error');
          return;
        }

        if (checkData && checkData.success) {
          Loading.hide();
          Modal.alert('This wallet is already registered. Please login instead.', 'Wallet Already Registered');
          return;
        }

        // Reserve the invite code for 5 minutes
        console.log('Reserving invite code:', tempRegistrationData.inviteCode);
        const { data: reserveResult, error: reserveError } = await supabase
          .rpc('reserve_invite_code', {
            p_code: tempRegistrationData.inviteCode,
            p_wallet_address: walletAddress.toLowerCase()
          });
        console.log('reserve_invite_code result:', { reserveResult, reserveError });

        if (reserveError) {
          Loading.hide();
          console.error('reserve_invite_code error:', reserveError);
          Modal.alert('Failed to reserve code: ' + reserveError.message, 'Code Error');
          return;
        }

        if (!reserveResult?.success) {
          Loading.hide();
          const errorMsg = reserveResult?.error || 'Failed to reserve code';
          console.error('Code reservation failed:', errorMsg);
          Modal.alert(errorMsg, 'Code Error');
          return;
        }

        // Request signature to verify ownership
        const message = `Sign to register on Duel PVP\nWallet: ${walletAddress}\nCode: ${tempRegistrationData.inviteCode}\nTimestamp: ${Date.now()}`;

        console.log('Requesting signature...');
        const signature = await signMessage(message);
        console.log('Signature received');

        // Store wallet and signature
        tempRegistrationData.walletAddress = walletAddress;
        tempRegistrationData.signature = signature;

        Loading.hide();
        Toast.success('Wallet verified!', 'SUCCESS');

        // Proceed to terms acceptance
        swapContent('termsAcceptance');

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

    async function handleLogin() {
      clearError('emailError');
      clearError('passError');

      const email = document.getElementById('loginEmail').value.trim();
      const password = document.getElementById('loginPass').value.trim();

      // Validate input
      if (!email) {
        showError('emailError', 'Email is required');
        return;
      }

      if (!password) {
        showError('passError', 'Password is required');
        return;
      }

      // Attempt Supabase authentication
      Loading.show('Signing in...');

      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
        email: email,
        password: password
      });

      if (authError) {
        Loading.hide();
        showError('passError', 'Invalid email or password');
        console.error('Login error:', authError);
        return;
      }

      // Get user data from database
      const { data: userData, error: userError } = await supabase
        .from('users')
        .select('*')
        .eq('email', email)
        .single();

      Loading.hide();

      if (userError || !userData) {
        showError('passError', 'User data not found');
        console.error('User lookup error:', userError);
        return;
      }

      // Store user info in localStorage
      localStorage.setItem('duelpvp_user_id', userData.id);
      localStorage.setItem('duelpvp_email', userData.email);
      localStorage.setItem('duelpvp_display_name', userData.display_name);
      localStorage.setItem('duelpvp_warrior', userData.display_name);

      // Set username in dashboard
      document.getElementById('userName').textContent = userData.display_name.toUpperCase();

      // Initialize GC cache
      await initializeGCCache();
      const gp = await getUserGC();

      Toast.success(`Welcome back, ${userData.display_name}!`, `${gp} GC`);
      swapContent('dashboard');
    }

    // Helper functions for inline error messages
    function showError(elementId, message) {
      const errorElement = document.getElementById(elementId);
      if (errorElement) {
        errorElement.textContent = message;
        errorElement.classList.add('show');
      }
    }

    function clearError(elementId) {
      const errorElement = document.getElementById(elementId);
      if (errorElement) {
        errorElement.textContent = '';
        errorElement.classList.remove('show');
      }
    }

    function clearAllErrors() {
      ['emailError', 'passError', 'passConfirmError', 'codeError', 'warriorNameError'].forEach(clearError);
    }

    async function handleRegister() {
      const email = document.getElementById('registerEmail').value.trim();
      const pass = document.getElementById('registerPass').value.trim();
      const passConfirm = document.getElementById('registerPassConfirm').value.trim();
      const code = document.getElementById('registerCode').value.trim().toUpperCase();

      // Clear all previous errors
      clearAllErrors();

      let hasError = false;

      if (!email) {
        showError('emailError', 'Email is required');
        hasError = true;
      } else if (!validateEmail(email)) {
        showError('emailError', 'Please enter a valid email address');
        hasError = true;
      }

      if (!pass) {
        showError('passError', 'Password is required');
        hasError = true;
      } else if (pass.length < 8) {
        showError('passError', 'Password must be at least 8 characters');
        hasError = true;
      }

      if (!passConfirm) {
        showError('passConfirmError', 'Please confirm your password');
        hasError = true;
      } else if (pass !== passConfirm) {
        showError('passConfirmError', 'Passwords do not match');
        hasError = true;
      }

      if (!code) {
        showError('codeError', 'Access code is required');
        hasError = true;
      }

      if (hasError) return;

      // Check if invite code exists and is unused
      Loading.show('Validating invite code...');

      try {
        const { data: codeData, error: codeError } = await supabase
          .from('codes')
          .select('code, used_by')
          .eq('code', code.toUpperCase().trim())
          .single();

        Loading.hide();

        if (codeError || !codeData) {
          showError('codeError', 'Invalid invite code');
          return;
        }

        if (codeData.used_by) {
          showError('codeError', 'Code already used');
          return;
        }
      } catch (err) {
        Loading.hide();
        console.error('Code validation error:', err);
        showError('codeError', 'Failed to validate code');
        return;
      }

      // Check if email already registered
      const { data: existingUser } = await supabase
        .from('users')
        .select('id')
        .eq('email', email)
        .single();

      if (existingUser) {
        showError('emailError', 'Email already registered');
        return;
      }

      // Store data temporarily and show warrior naming screen
      tempRegistrationData.email = email;
      tempRegistrationData.password = pass;
      tempRegistrationData.inviteCode = code;
      swapContent('nameWarrior');
    }

    function handleTermsAcceptance() {
      const termsCheckbox = document.getElementById('termsCheckbox');

      clearError('termsError');

      if (!termsCheckbox.checked) {
        showError('termsError', 'You must accept the Terms of Service to continue');
        return;
      }

      // Store terms acceptance
      tempRegistrationData.termsAccepted = true;

      // Proceed to warrior naming
      swapContent('nameWarrior');
    }

    async function handleNameWarrior() {
      const warriorName = document.getElementById('warriorName').value.trim();
      const referralCode = document.getElementById('referralCode').value.trim() || null;

      // Clear previous errors
      clearError('warriorNameError');
      clearError('referralCodeError');

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
        console.log('Calling register_user_with_wallet with:', {
          wallet: tempRegistrationData.walletAddress,
          name: warriorName,
          code: referralCode
        });

        const { data, error } = await supabase.rpc('register_user_with_wallet', {
          p_wallet_address: tempRegistrationData.walletAddress,
          p_display_name: warriorName,
          p_invite_code: referralCode
        });

        console.log('register_user_with_wallet response:', { data, error });

        if (error || !data || !data.success) {
          Loading.hide();
          console.error('Registration failed:', { error, data });
          const errorMsg = data?.error || 'Registration failed';

          if (errorMsg.includes('Display name already taken')) {
            showError('warriorNameError', 'Display name already taken');
          } else if (errorMsg.includes('Wallet already registered')) {
            Modal.alert('This wallet is already registered', 'Registration Failed');
          } else if (errorMsg.includes('Invalid invite code') || errorMsg.includes('username not found')) {
            showError('referralCodeError', 'Invalid referral code - username not found');
          } else if (errorMsg.includes('Cannot use your own username')) {
            showError('referralCodeError', 'Cannot use your own username as referral code');
          } else {
            Modal.alert(errorMsg, 'Error');
          }
          return;
        }

        const userId = data.user_id;

        // Create anonymous Supabase Auth session
        console.log('Creating anonymous auth for new user...');
        const authResult = await supabase.auth.signInAnonymously({
          options: {
            data: {
              wallet_address: tempRegistrationData.walletAddress,
              display_name: warriorName,
              user_id: userId
            }
          }
        });
        console.log('Registration auth result:', authResult);

        // Explicitly set the session to ensure client uses it immediately for all requests
        if (authResult.data?.session) {
          await supabase.auth.setSession({
            access_token: authResult.data.session.access_token,
            refresh_token: authResult.data.session.refresh_token
          });
          console.log('Registration session explicitly set on Supabase client');
        }

        if (authResult.error) {
          console.error('Failed to create auth session:', authResult.error);
          Loading.hide();
          Modal.alert('Account created but auth session failed: ' + authResult.error.message + '\n\nPlease try logging in with your wallet.', 'Warning');
          swapContent('home');
          return;
        }

        // Link anonymous auth user to new user record
        if (authResult.data?.user) {
          console.log('Linking new user to auth...');
          const linkResult = await supabase.rpc('link_auth_to_user', {
            p_user_id: userId
          });
          console.log('Link result:', linkResult);
        }

        // Verify session is active
        console.log('Verifying registration session...');
        const { data: { session: verifySession } } = await supabase.auth.getSession();
        console.log('Registration session:', verifySession ? 'Active' : 'None');

        if (!verifySession) {
          Loading.hide();
          Modal.alert('Registration complete but session failed. Please login with your wallet.', 'Warning');
          swapContent('home');
          return;
        }

        // Create session (Blur-style)
        createSession(userId, tempRegistrationData.walletAddress, warriorName);
        finishWalletConnection(); // Allow wallet event handlers to reload page now

        // Set username in dashboard
        document.getElementById('userName').textContent = warriorName.toUpperCase();

        // Initialize GC cache and update display
        await initializeGCCache();
        const gp = await getUserGC();
        const displayGC = gp >= 1000000 ? `${(gp/1000000).toFixed(1)}M` : gp >= 1000 ? `${(gp/1000).toFixed(1)}K` : gp;
        document.getElementById('dashboardGCBalance').textContent = displayGC;

        Loading.hide();
        Toast.success(`Welcome, ${warriorName}!`, `${gp} GC`);
        swapContent('dashboard');

        // Clear temp data
        tempRegistrationData = {
          walletAddress: '',
          inviteCode: '',
          signature: '',
          termsAccepted: false
        };
      } catch (e) {
        Loading.hide();
        console.error('Registration error:', e);
        Modal.alert('Error: ' + e.message + '. Check browser console (F12) for details.', 'Registration Failed');
      }
    }

    async function handleLogout() {
      const confirmed = await Modal.confirm('Are you sure you want to logout?', 'Confirm Logout');
      if (!confirmed) return;

      // Sign out from Supabase Auth
      await supabase.auth.signOut();

      // Clear custom session (legacy support)
      clearSession();

      // Clear GC cache
      gcCache.balance = 0;
      gcCache.lastFetch = 0;

      // Reset UI
      dashboardContent.style.display = 'none';
      panelContent.style.display = 'block';
      swapContent('home');

      Toast.info('Logged out successfully', 'GOODBYE');
    }

    // Wallet connection functions
    async function handleConnectWallet() {
      try {
        Loading.show('Connecting wallet...');

        // Connect wallet using Web3Modal
        const walletAddress = await getWalletAddress();

        // Request signature to verify ownership (doesn't touch assets)
        const message = `Verify wallet ownership for Duel PVP\nWallet: ${walletAddress}\nTimestamp: ${Date.now()}`;

        const signature = await signMessage(message);

        // Store wallet address linked to current email
        const email = localStorage.getItem('duelpvp_email');
        const userId = localStorage.getItem('duelpvp_user_id');

        if (email && userId) {
          // Save to localStorage
          localStorage.setItem(`duelpvp_wallet_${email}`, walletAddress);
          localStorage.setItem(`duelpvp_wallet_verified_${email}`, signature);
          localStorage.setItem(`duelpvp_email_${walletAddress.toLowerCase()}`, email);

          // Save to Supabase database
          const { error: updateError } = await supabase
            .from('users')
            .update({ wallet_address: walletAddress })
            .eq('id', userId);

          if (updateError) {
            console.error('Failed to save wallet to database:', updateError);
            Loading.hide();
            Toast.warning('Wallet connected locally but not saved to database', 'PARTIAL SUCCESS');
            updateWalletDisplay(walletAddress);
          } else {
            updateWalletDisplay(walletAddress);
            Loading.hide();
            Toast.success(`Wallet ${walletAddress.substring(0, 6)}...${walletAddress.substring(38)} linked to your account`, 'WALLET CONNECTED');
          }
        } else {
          Loading.hide();
          Modal.alert('No email found. Please login first.', 'Login Required');
        }
      } catch (error) {
        Loading.hide();
        console.error('Wallet connection error:', error);
        if (error.code === 4001) {
          Toast.warning('You cancelled the wallet connection request', 'Connection Cancelled');
        } else {
          Modal.alert('Failed to connect wallet: ' + error.message, 'Connection Error');
        }
      }
    }

    function updateWalletDisplay(address = null) {
      // Wallet connection card removed - wallet is now required for registration
      // This function is kept for compatibility but does nothing
      return;
    }

    function handleDisconnectWallet() {
      const email = localStorage.getItem('duelpvp_email');
      if (email) {
        const wallet = localStorage.getItem(`duelpvp_wallet_${email}`);
        if (wallet) {
          localStorage.removeItem(`duelpvp_wallet_${email}`);
          localStorage.removeItem(`duelpvp_wallet_verified_${email}`);
          localStorage.removeItem(`duelpvp_email_${wallet.toLowerCase()}`);
        }
        updateWalletDisplay();
        Toast.info('Wallet disconnected from your account', 'DISCONNECTED');
      }
    }

    // =====================================================
    // SESSION MANAGEMENT (Blur-style)
    // =====================================================

    const SESSION_KEY = 'duelpvp.auth';
    const SESSION_DURATION = 30 * 24 * 60 * 60 * 1000; // 30 days

    function createSession(userId, walletAddress, displayName) {
      const session = {
        version: "1",
        userId: userId,
        walletAddress: walletAddress.toLowerCase(),
        displayName: displayName,
        issuedAt: Date.now(),
        expiresAt: Date.now() + SESSION_DURATION
      };

      localStorage.setItem(SESSION_KEY, JSON.stringify(session));
      // Also store userId directly for backward compatibility
      localStorage.setItem('duelpvp_user_id', userId);

      // Also cache GC for navbar (Blur-style)
      const gcCacheKey = `duelpvp.cache.gc`;
      localStorage.setItem(gcCacheKey, JSON.stringify({
        [walletAddress.toLowerCase()]: 0 // Will be updated by initializeGCCache
      }));

      console.log('Session created for', displayName);
    }

    function getSession() {
      try {
        const sessionData = localStorage.getItem(SESSION_KEY);
        if (!sessionData) return null;
        return JSON.parse(sessionData);
      } catch (e) {
        console.error('Failed to parse session:', e);
        return null;
      }
    }

    function clearSession() {
      // Clear all duelpvp.* keys (Blur-style namespacing)
      Object.keys(localStorage).forEach(key => {
        if (key.startsWith('duelpvp.') || key.startsWith('duelpvp_')) {
          localStorage.removeItem(key);
        }
      });
      console.log('Session cleared');
    }

    function isSessionValid(session) {
      if (!session) return false;
      if (!session.userId || !session.walletAddress) return false;
      if (Date.now() > session.expiresAt) {
        console.log('Session expired');
        return false;
      }
      return true;
    }

    // Helper to get current user ID from session
    function getCurrentUserId() {
      const session = getSession();
      if (session?.userId) return session.userId;

      // Backwards compatibility - check old localStorage key
      return localStorage.getItem('duelpvp_user_id') || null;
    }

    // Helper to get current wallet address from session
    function getCurrentWalletAddress() {
      const session = getSession();
      if (session?.walletAddress) return session.walletAddress;

      // Backwards compatibility - check old localStorage key
      return localStorage.getItem('duelpvp_wallet') || null;
    }

    async function checkWalletConnection(expectedAddress) {
      try {
        if (!window.ethereum) return false;

        const accounts = await window.ethereum.request({ method: 'eth_accounts' });
        if (accounts.length === 0) return false;

        const connectedAddresses = accounts.map(a => a.toLowerCase());
        return connectedAddresses.includes(expectedAddress.toLowerCase());
      } catch (e) {
        console.error('Failed to check wallet connection:', e);
        return false;
      }
    }

    async function initializeApp() {
      console.log('Initializing app...');

      // Check for existing Supabase auth session first
      const { data: { session: supabaseSession } } = await supabase.auth.getSession();
      console.log('Supabase session:', supabaseSession ? 'Found' : 'None');

      const session = getSession();

      if (!session) {
        console.log('No localStorage session found, showing home screen');
        return; // Show home screen by default
      }

      if (!isSessionValid(session)) {
        console.log('Session invalid or expired, clearing');
        clearSession();
        await supabase.auth.signOut();
        return; // Show home screen
      }

      // Blur-style: Trust valid session without requiring wallet reconnection
      // Wallet will be reconnected when needed for transactions
      console.log('Valid session found, skipping wallet check for auto-login');

      // Verify user still exists in database using RPC (bypasses RLS)
      const { data: loginData, error } = await supabase.rpc('login_with_wallet', {
        p_wallet_address: session.walletAddress
      });

      if (error || !loginData || !loginData.success) {
        console.log('User not found in database, clearing session');
        clearSession();
        await supabase.auth.signOut();
        return;
      }

      // Extract user data from RPC response
      const userData = {
        id: loginData.user_id,
        display_name: loginData.display_name,
        gc_balance: loginData.gc_balance,
        auth_user_id: loginData.auth_user_id
      };

      // Restore Supabase auth session if missing - create new anonymous session
      if (!supabaseSession) {
        console.log('No Supabase session, creating new anonymous session for auto-login');
        const authResult = await supabase.auth.signInAnonymously({
          options: {
            data: {
              wallet_address: session.walletAddress,
              display_name: userData.display_name,
              user_id: userData.id
            }
          }
        });

        if (authResult.error) {
          console.error('Failed to create auth session:', authResult.error);
          clearSession();
          Toast.info('Session expired. Please login again.', 'SESSION EXPIRED');
          return;
        }

        // Set the session explicitly
        if (authResult.data?.session) {
          await supabase.auth.setSession({
            access_token: authResult.data.session.access_token,
            refresh_token: authResult.data.session.refresh_token
          });
        }
      }

      // Verify Supabase session matches user
      if (supabaseSession && userData.auth_user_id && supabaseSession.user.id !== userData.auth_user_id) {
        console.log('Supabase session mismatch, clearing');
        clearSession();
        await supabase.auth.signOut();
        return;
      }

      // Session is valid! Auto-login
      console.log('Valid session found, auto-logging in as', session.displayName);

      // Set UI
      document.getElementById('userName').textContent = session.displayName.toUpperCase();

      // Initialize GC cache and update display
      await initializeGCCache();
      const gp = await getUserGC();
      const displayGC = gp >= 1000000 ? `${(gp/1000000).toFixed(1)}M` : gp >= 1000 ? `${(gp/1000).toFixed(1)}K` : gp;
      document.getElementById('dashboardGCBalance').textContent = displayGC;

      // Auto-redirect to dashboard
      swapContent('dashboard');
      Toast.success(`Welcome back, ${session.displayName}!`, `${gp} GC`);
    }

    // Unified wallet connect - handles both login and registration
    async function handleUnifiedWalletConnect() {
      try {
        Loading.show('Connecting to wallet...');

        // Connect wallet using Web3Modal
        const walletAddress = (await getWalletAddress()).toLowerCase();

        // Check if wallet exists in database using RPC function (bypasses RLS)
        const { data: loginData, error: loginError } = await supabase.rpc('login_with_wallet', {
          p_wallet_address: walletAddress
        });

        console.log('login_with_wallet response:', { loginData, loginError });

        // If wallet is not registered, go to naming screen
        if (loginError || !loginData || !loginData.success) {
          console.log('Wallet not registered, proceeding to registration...');

          // Store wallet address for registration
          tempRegistrationData.walletAddress = walletAddress;
          // Only clear invite code if it wasn't set from URL parameter
          if (!tempRegistrationData.inviteCode) {
            tempRegistrationData.inviteCode = null; // No invite code needed
          }

          Loading.hide();
          Toast.success('Wallet connected!', 'SUCCESS');

          // Go directly to warrior naming screen
          swapContent('nameWarrior');
          return;
        }

        // Wallet is registered - proceed with login
        console.log('Wallet registered, logging in...');

        // Extract user data from RPC response
        const userData = {
          id: loginData.user_id,
          display_name: loginData.display_name,
          gc_balance: loginData.gc_balance,
          auth_user_id: loginData.auth_user_id
        };

        // Verify ownership with signature
        const message = `Sign in to Duel PVP\nWallet: ${walletAddress}\nTimestamp: ${Date.now()}`;

        const signature = await signMessage(message);

        // Create Supabase Auth session using anonymous authentication
        Loading.show('Creating secure session...');

        // Check if user already has an auth session linked
        let authResult;
        if (userData.auth_user_id) {
          // Try to get existing session (may have been created before)
          const { data: { session } } = await supabase.auth.getSession();
          if (session && session.user.id === userData.auth_user_id) {
            authResult = { data: { user: session.user }, error: null };
          }
        }

        // If no existing session, create new anonymous auth session
        if (!authResult || authResult.error) {
          console.log('Creating new anonymous auth session...');
          authResult = await supabase.auth.signInAnonymously({
            options: {
              data: {
                wallet_address: walletAddress,
                display_name: userData.display_name,
                user_id: userData.id
              }
            }
          });
          console.log('Anonymous auth result:', authResult);

          // Explicitly set the session to ensure client uses it immediately for all requests
          if (authResult.data?.session) {
            await supabase.auth.setSession({
              access_token: authResult.data.session.access_token,
              refresh_token: authResult.data.session.refresh_token
            });
            console.log('Session explicitly set on Supabase client');
          }

          // Link anonymous auth user to existing user record
          if (authResult.data?.user) {
            console.log('Linking auth user to database user...');
            const linkResult = await supabase.rpc('link_auth_to_user', {
              p_user_id: userData.id
            });
            console.log('Link result:', linkResult);
          }
        }

        if (authResult.error) {
          console.error('Auth session error:', authResult.error);
          Loading.hide();
          Modal.alert('Failed to create auth session: ' + authResult.error.message + '\n\nPlease ensure anonymous authentication is enabled in Supabase dashboard.', 'Authentication Error');
          return;
        }

        if (!authResult.data?.user) {
          console.error('No auth user created');
          Loading.hide();
          Modal.alert('Failed to create auth session. Please check browser console.', 'Authentication Error');
          return;
        }

        // Verify session is active and client is using it
        console.log('Verifying session is active...');
        const { data: { session: verifySession } } = await supabase.auth.getSession();
        console.log('Session verification:', verifySession ? 'Active' : 'None');

        if (!verifySession) {
          console.error('Session not active after creation');
          Loading.hide();
          Modal.alert('Session creation failed. Please try again.', 'Authentication Error');
          return;
        }

        // Store user info in localStorage (legacy support)
        createSession(userData.id, walletAddress, userData.display_name);
        finishWalletConnection(); // Allow wallet event handlers to reload page now

        document.getElementById('userName').textContent = userData.display_name.toUpperCase();

        // Check NFT holder status and auto-complete quests
        await checkNFTHolderQuests(walletAddress);

        // Initialize GC cache and update display
        await initializeGCCache();
        const gp = await getUserGC();
        const displayGC = gp >= 1000000 ? `${(gp/1000000).toFixed(1)}M` : gp >= 1000 ? `${(gp/1000).toFixed(1)}K` : gp;
        document.getElementById('dashboardGCBalance').textContent = displayGC;

        Loading.hide();
        Toast.success(`Welcome back, ${userData.display_name}!`, `${gp} GC`);
        swapContent('dashboard');

      } catch (error) {
        Loading.hide();
        console.error('Wallet connect error:', error);
        if (error.code === 4001) {
          Toast.warning('You cancelled the wallet connection', 'Connection Cancelled');
        } else {
          Modal.alert('Failed to connect wallet: ' + error.message, 'Connection Error');
        }
      }
    }

    async function handleWalletLogin() {
      try {
        Loading.show('Connecting to wallet...');

        // Connect wallet using Web3Modal
        const walletAddress = (await getWalletAddress()).toLowerCase();

        // Check if wallet exists in database using RPC function (bypasses RLS)
        const { data: loginData, error: loginError } = await supabase.rpc('login_with_wallet', {
          p_wallet_address: walletAddress
        });

        console.log('login_with_wallet response:', { loginData, loginError });

        if (loginError || !loginData || !loginData.success) {
          Loading.hide();
          Modal.alert('This wallet is not registered. Please sign up with an invite code first.', 'Wallet Not Found');
          return;
        }

        // Extract user data from RPC response
        const userData = {
          id: loginData.user_id,
          display_name: loginData.display_name,
          gc_balance: loginData.gc_balance,
          auth_user_id: loginData.auth_user_id
        };

        // Verify ownership with signature
        const message = `Sign in to Duel PVP\nWallet: ${walletAddress}\nTimestamp: ${Date.now()}`;

        const signature = await signMessage(message);

        // Create Supabase Auth session using anonymous authentication
        Loading.show('Creating secure session...');

        // Check if user already has an auth session linked
        let authResult;
        if (userData.auth_user_id) {
          // Try to get existing session (may have been created before)
          const { data: { session } } = await supabase.auth.getSession();
          if (session && session.user.id === userData.auth_user_id) {
            authResult = { data: { user: session.user }, error: null };
          }
        }

        // If no existing session, create new anonymous auth session
        if (!authResult || authResult.error) {
          console.log('Creating new anonymous auth session...');
          authResult = await supabase.auth.signInAnonymously({
            options: {
              data: {
                wallet_address: walletAddress,
                display_name: userData.display_name,
                user_id: userData.id
              }
            }
          });
          console.log('Anonymous auth result:', authResult);

          // Explicitly set the session to ensure client uses it immediately for all requests
          if (authResult.data?.session) {
            await supabase.auth.setSession({
              access_token: authResult.data.session.access_token,
              refresh_token: authResult.data.session.refresh_token
            });
            console.log('Session explicitly set on Supabase client');
          }

          // Link anonymous auth user to existing user record
          if (authResult.data?.user) {
            console.log('Linking auth user to database user...');
            const linkResult = await supabase.rpc('link_auth_to_user', {
              p_user_id: userData.id
            });
            console.log('Link result:', linkResult);
          }
        }

        if (authResult.error) {
          console.error('Auth session error:', authResult.error);
          Loading.hide();
          Modal.alert('Failed to create auth session: ' + authResult.error.message + '\n\nPlease ensure anonymous authentication is enabled in Supabase dashboard.', 'Authentication Error');
          return;
        }

        if (!authResult.data?.user) {
          console.error('No auth user created');
          Loading.hide();
          Modal.alert('Failed to create auth session. Please check browser console.', 'Authentication Error');
          return;
        }

        // Verify session is active and client is using it
        console.log('Verifying session is active...');
        const { data: { session: verifySession } } = await supabase.auth.getSession();
        console.log('Session verification:', verifySession ? 'Active' : 'None');

        if (!verifySession) {
          console.error('Session not active after creation');
          Loading.hide();
          Modal.alert('Session creation failed. Please try again.', 'Authentication Error');
          return;
        }

        // Store user info in localStorage (legacy support)
        createSession(userData.id, walletAddress, userData.display_name);
        finishWalletConnection(); // Allow wallet event handlers to reload page now

        document.getElementById('userName').textContent = userData.display_name.toUpperCase();

        // Check NFT holder status and auto-complete quests
        await checkNFTHolderQuests(walletAddress);

        // Initialize GC cache and update display
        await initializeGCCache();
        const gp = await getUserGC();
        const displayGC = gp >= 1000000 ? `${(gp/1000000).toFixed(1)}M` : gp >= 1000 ? `${(gp/1000).toFixed(1)}K` : gp;
        document.getElementById('dashboardGCBalance').textContent = displayGC;

        Loading.hide();
        Toast.success(`Welcome back, ${userData.display_name}!`, `${gp} GC`);
        swapContent('dashboard');

      } catch (error) {
        Loading.hide();
        console.error('Wallet login error:', error);
        if (error.code === 4001) {
          Toast.warning('You cancelled the signature request', 'Signature Cancelled');
        } else {
          Modal.alert('Failed to login with wallet: ' + error.message, 'Login Failed');
        }
      }
    }

    // Dashboard stats update
    async function updateDashboardStats() {
      try {
        // Get user ID from session or old localStorage format
        const session = getSession();
        const userId = session?.userId || localStorage.getItem('duelpvp_user_id');

        if (!userId) return;

        // Get user's total games played (scores table may not exist yet)
        let userScores = [];
        const { data: scoresData, error: scoresError } = await supabase
          .from('scores')
          .select('time_ms, created_at')
          .eq('user_id', userId)
          .order('created_at', { ascending: false });

        if (scoresError) {
          // Scores table doesn't exist yet - that's okay, continue with other stats
          console.log('Scores table not available:', scoresError.message);
        } else {
          userScores = scoresData || [];
        }

        // Get user's GC from users table
        const { data: userData, error: userError } = await supabase
          .from('users')
          .select('gc_balance, win_streak, total_wins')
          .eq('id', userId)
          .single();

        if (userError) {
          console.error('Failed to load user data:', userError);
        }

        // Calculate rank using RPC function (bypasses RLS)
        let userRank = 0;
        const userGC = userData?.gc_balance ?? 0;

        // Use get_user_rank RPC if available, otherwise try direct count
        const { data: rankData, error: rankError } = await supabase
          .rpc('get_user_rank', { p_user_id: userId });

        console.log('Rank calculation:', { userGC, rankData, rankError });

        if (!rankError && rankData && rankData[0]?.rank) {
          userRank = rankData[0].rank;
        } else {
          // Fallback: try direct count (may fail with RLS)
          const { count } = await supabase
            .from('users')
            .select('*', { count: 'exact', head: true })
            .gt('gc_balance', userGC);

          if (count !== null) {
            userRank = count + 1;
          }
        }

        // Calculate stats
        const totalWins = userData?.total_wins || userScores?.length || 0;
        const streak = userData?.win_streak || 0;
        const totalGP = userData?.gc_balance || 0;

        // Update UI
        document.getElementById('dashboardRank').textContent = userRank > 0 ? `#${userRank}` : '--';

        // Update GC using secure getUserGC function (supports both database and localStorage)
        const displayGP = await getUserGC();
        document.getElementById('dashboardGCBalance').textContent = displayGP >= 1000000 ? `${(displayGP/1000000).toFixed(1)}M` : displayGP >= 1000 ? `${(displayGP/1000).toFixed(1)}K` : displayGP;

      } catch (e) {
        console.error('Failed to update dashboard stats:', e);
      }

      // Update wallet display
      updateWalletDisplay();

      // Load dashboard inventory
      loadDashboardInventory();
    }

    async function loadDashboardInventory() {
      const userId = localStorage.getItem('duelpvp_user_id');
      const email = localStorage.getItem('duelpvp_email');
      const dashboardItemsGrid = document.getElementById('dashboardItemsGrid');

      if (!dashboardItemsGrid) return;

      // Get inventory from localStorage (for now - can be migrated to Supabase later)
      const inventory = JSON.parse(localStorage.getItem(`duelpvp_inventory_${email}`) || '[]');

      // Get user's invite codes using RPC function
      let inviteCodes = [];
      if (userId) {
        const { data } = await supabase
          .rpc('get_user_invite_codes', { p_user_id: userId });

        if (data && data.length > 0) {
          inviteCodes = data.map(c => ({
            code: c.code,
            used: c.used,
            used_at: c.used_at
          }));
        }
      }

      // Combine inventory items and codes
      const allItems = [];

      // Add invite codes first (show up to 4)
      inviteCodes.slice(0, 4).forEach(code => {
        allItems.push({
          type: 'invite_code',
          icon: `<img src="duelpvp-logo.svg" alt="Invite Code" style="width:24px;height:24px;display:inline-block;vertical-align:middle;">`,
          name: code.used_by ? 'USED CODE' : 'INVITE CODE',
          desc: code.used_by
            ? `This code was used on ${new Date(code.used_at).toLocaleDateString()}`
            : 'Share this code with friends to invite them to the arena!',
          code: code.code,
          itemType: 'Invite Code',
          used: !!code.used_by
        });
      });

      // Add shop items from inventory
      inventory.forEach(item => {
        const shopItem = SHOP_ITEMS.find(si => si.id === item.id);
        if (shopItem) {
          allItems.push({
            type: 'shop_item',
            icon: shopItem.icon,
            name: shopItem.name,
            desc: shopItem.desc,
            itemType: shopItem.type,
            count: item.count || 1
          });
        }
      });

      // Fill remaining slots with empty slots (show 8 slots total)
      const slotsToShow = 8;
      while (allItems.length < slotsToShow) {
        allItems.push({ type: 'empty' });
      }

      // Render items
      dashboardItemsGrid.innerHTML = '';
      allItems.slice(0, slotsToShow).forEach(item => {
        const slot = document.createElement('div');
        slot.className = item.type === 'empty' ? 'dashboard-item-slot empty' : 'dashboard-item-slot';

        if (item.type === 'empty') {
          slot.innerHTML = `
            <div class="dashboard-item-icon">—</div>
          `;
        } else {
          slot.innerHTML = `
            <div class="dashboard-item-icon">${item.icon}</div>
            <div class="dashboard-item-name">${item.name}</div>
            ${item.count > 1 ? `<div class="dashboard-item-count">${item.count}</div>` : ''}
            <div class="dashboard-item-tooltip">
              <div class="tooltip-name">${item.name}</div>
              <div class="tooltip-desc">${item.desc}</div>
              <div class="tooltip-type">${item.itemType || 'Item'}</div>
              ${item.code ? `<div class="tooltip-desc" style="margin-top:4px;color:var(--gold);font-family:'Press Start 2P';font-size:9px;">${item.code}</div>` : ''}
            </div>
          `;

          // Add click-to-copy for unused invite codes
          if (item.type === 'invite_code' && !item.used) {
            slot.style.cursor = 'pointer';
            slot.addEventListener('click', () => {
              copyToClipboard(item.code);
              Toast.success(`Code ${item.code} copied!`, 'SHARE WITH FRIENDS');
            });
          }
        }

        dashboardItemsGrid.appendChild(slot);
      });
    }

    // Leaderboard functions
    async function loadLeaderboard(filter = 'all') {
      console.log('loadLeaderboard called');
      try {
        const userId = localStorage.getItem('duelpvp_user_id');

        Loading.show('Loading leaderboard...');

        // Get leaderboard using secure RPC function
        const { data: leaderboard, error } = await supabase
          .rpc('get_leaderboard', { p_limit: 100 });

        Loading.hide();

        if (error) {
          console.error('Leaderboard error:', error);
          throw error;
        }

        console.log('Loaded leaderboard:', leaderboard?.length || 0, 'entries');

        // Show user's rank if they're logged in
        if (userId) {
          const userEntry = leaderboard?.find(entry => entry.display_name === localStorage.getItem('duelpvp_display_name'));
          if (userEntry) {
            document.getElementById('yourBestSection').style.display = 'block';
            document.getElementById('yourBestTime').textContent = `#${userEntry.rank} | ${userEntry.gc_balance?.toLocaleString() || 0} GC`;
          } else {
            // User is not in top 100, get their actual rank
            const { data: userRankData } = await supabase
              .rpc('get_user_rank', { p_user_id: userId });

            if (userRankData && userRankData.rank) {
              document.getElementById('yourBestSection').style.display = 'block';
              document.getElementById('yourBestTime').textContent = `#${userRankData.rank} | ${userRankData.user_gc_balance?.toLocaleString() || 0} GC`;
            } else {
              document.getElementById('yourBestSection').style.display = 'none';
            }
          }
        } else {
          document.getElementById('yourBestSection').style.display = 'none';
        }

        // Render table
        renderLeaderboardTable(leaderboard || [], userId);

      } catch (e) {
        Loading.hide();
        console.error('Failed to load leaderboard:', e);
        document.getElementById('leaderboardTableBody').innerHTML = '<div class="no-data">Error loading leaderboard</div>';
      }
    }

    function renderLeaderboardTable(leaderboard, currentUserId) {
      const tbody = document.getElementById('leaderboardTableBody');
      tbody.innerHTML = '';

      if (leaderboard.length === 0) {
        tbody.innerHTML = '<div class="no-data">No warriors yet. Be the first!</div>';
        return;
      }

      leaderboard.forEach((entry) => {
        const rank = entry.rank || '?';
        const playerName = entry.display_name || 'Unknown';
        const gpBalance = entry.gc_balance?.toLocaleString() || '0';
        const walletShort = entry.wallet_address ?
          `${entry.wallet_address.substring(0, 6)}...${entry.wallet_address.substring(entry.wallet_address.length - 4)}` :
          'No wallet';
        const isCurrentUser = entry.id === currentUserId;

        // Highlight top 3 differently
        let rankBadgeClass = 'rank-badge';
        if (rank === 1) rankBadgeClass += ' rank-gold';
        else if (rank === 2) rankBadgeClass += ' rank-silver';
        else if (rank === 3) rankBadgeClass += ' rank-bronze';

        const row = document.createElement('div');
        row.className = isCurrentUser ? 'table-row user-row' : 'table-row';
        row.innerHTML = `
          <div class="${rankBadgeClass}">#${rank}</div>
          <div class="player-name">${playerName.toUpperCase()}${isCurrentUser ? ' (YOU)' : ''}</div>
          <div class="reaction-time" style="color:var(--gold);font-weight:700;">${gpBalance} GC</div>
          <div class="entry-date" style="font-family:monospace;font-size:11px;">${walletShort}</div>
        `;
        tbody.appendChild(row);
      });
    }

    // Game functions
    function initChart() {
      const canvas = document.getElementById('chartCanvas');
      const ctx = canvas.getContext('2d');
      canvas.width = canvas.offsetWidth;
      canvas.height = canvas.offsetHeight;
      drawChart(ctx, false);
    }
    
    function drawChart(ctx, chartData = null) {
      const canvas = ctx.canvas;
      const w = canvas.width;
      const h = canvas.height;

      // Clear canvas
      ctx.clearRect(0, 0, w, h);

      // Draw grid
      ctx.strokeStyle = 'rgba(255,214,77,0.1)';
      ctx.lineWidth = 1;
      ctx.setLineDash([2, 4]);

      // Horizontal lines
      for (let i = 0; i < 5; i++) {
        ctx.beginPath();
        ctx.moveTo(0, (h / 5) * i);
        ctx.lineTo(w, (h / 5) * i);
        ctx.stroke();
      }

      // Vertical lines
      for (let i = 0; i < 10; i++) {
        ctx.beginPath();
        ctx.moveTo((w / 10) * i, 0);
        ctx.lineTo((w / 10) * i, h);
        ctx.stroke();
      }

      ctx.setLineDash([]);

      // If no chartData provided, draw empty/static chart
      if (!chartData) {
        const points = [];
        let currentPrice = 40000;
        const numPoints = 50;

        for (let i = 0; i < numPoints; i++) {
          const change = (Math.random() - 0.48) * 300;
          currentPrice += change;
          points.push({
            x: (w / numPoints) * i,
            y: h - (currentPrice - 38000) / 50
          });
        }

        ctx.strokeStyle = '#4CAF50';
        ctx.lineWidth = 3;
        ctx.beginPath();
        points.forEach((point, i) => {
          if (i === 0) ctx.moveTo(point.x, point.y);
          else ctx.lineTo(point.x, point.y);
        });
        ctx.stroke();
        return;
      }

      // Draw animated chart
      const isRed = chartData.hasCrashed;
      const points = chartData.points;

      // Draw line
      ctx.strokeStyle = isRed ? '#F44336' : '#4CAF50';
      ctx.lineWidth = 3;
      ctx.beginPath();
      points.forEach((point, i) => {
        if (i === 0) ctx.moveTo(point.x, point.y);
        else ctx.lineTo(point.x, point.y);
      });
      ctx.stroke();

      // Draw fill
      ctx.fillStyle = isRed ? 'rgba(244,67,54,0.1)' : 'rgba(76,175,80,0.1)';
      ctx.beginPath();
      ctx.moveTo(points[0].x, points[0].y);
      points.forEach(point => ctx.lineTo(point.x, point.y));
      ctx.lineTo(points[points.length - 1].x, h);
      ctx.lineTo(points[0].x, h);
      ctx.closePath();
      ctx.fill();
    }
    
    function startGame() {
      const chartContainer = document.getElementById('chartContainer');
      const sellButton = document.getElementById('sellButton');
      const gameStatus = document.getElementById('gameStatus');
      const canvas = document.getElementById('chartCanvas');
      const ctx = canvas.getContext('2d');
      const w = canvas.width;
      const h = canvas.height;

      // Reset state
      chartContainer.className = 'chart-container green';
      sellButton.disabled = false; // Enable immediately
      gameStatus.textContent = 'Watch for the dump...';
      gameStatus.className = 'game-status status-ready';
      drawChart(ctx, null);

      // Game parameters - HIGHLY RANDOMIZED FOR VARIETY
      // Random duration with weighted distribution (favors longer but allows early crashes)
      const durationRoll = Math.random();
      let totalDuration;
      if (durationRoll < 0.15) {
        // 15% chance: Early crash (1-2.5 seconds)
        totalDuration = 1000 + Math.random() * 1500;
      } else if (durationRoll < 0.85) {
        // 70% chance: Normal/Long (2.5-6 seconds) - more exciting
        totalDuration = 2500 + Math.random() * 3500;
      } else {
        // 15% chance: Very long (6-9 seconds) - maximum suspense
        totalDuration = 6000 + Math.random() * 3000;
      }

      // Peak time is more variable: sometimes early (20%), sometimes very late (90%)
      const peakTime = totalDuration * (0.2 + Math.random() * 0.7); // Peak at 20%-90% of duration
      const startPrice = 38000 + Math.random() * 4000; // Random start 38k-42k
      const peakPrice = startPrice + 6000 + Math.random() * 8000; // Rise 6000-14000
      const crashPrice = startPrice - (2000 + Math.random() * 3000); // Random crash depth
      const riseShape = 0.5 + Math.random() * 0.8; // Random rise curve (0.5-1.3)
      const crashShape = 1.5 + Math.random() * 1.5; // Random crash steepness (1.5-3.0)

      gameState.isPlaying = true;
      gameState.hasCrashed = false;
      gameState.peakReached = false;
      gameState.startTime = performance.now();
      gameState.peakTime = gameState.startTime + peakTime;
      gameState.endTime = gameState.startTime + totalDuration;

      const numPoints = 80;

      function animateChart() {
        if (!gameState.isPlaying && !gameState.hasCrashed) return;

        const now = performance.now();
        const elapsed = now - gameState.startTime;
        const progress = Math.min(elapsed / totalDuration, 1);

        // Calculate current price based on phase
        let currentPrice;
        const pointsToShow = Math.floor(progress * numPoints);

        if (elapsed < peakTime) {
          // Rising phase - random curve shape
          const riseProgress = elapsed / peakTime;
          currentPrice = startPrice + (peakPrice - startPrice) * Math.pow(riseProgress, riseShape);
        } else {
          // Crashing phase - random steepness
          if (!gameState.peakReached) {
            gameState.peakReached = true;
            chartContainer.className = 'chart-container red';
            gameStatus.textContent = 'CRASH!';
            gameStatus.className = 'game-status status-go';
          }
          gameState.hasCrashed = true;
          const crashProgress = (elapsed - peakTime) / (totalDuration - peakTime);
          currentPrice = peakPrice - (peakPrice - crashPrice) * Math.pow(crashProgress, crashShape);
        }

        // Generate smooth points
        const points = [];
        for (let i = 0; i <= pointsToShow; i++) {
          const t = i / numPoints;
          const pointElapsed = t * totalDuration;
          let price;

          if (pointElapsed < peakTime) {
            const riseProgress = pointElapsed / peakTime;
            price = startPrice + (peakPrice - startPrice) * Math.pow(riseProgress, riseShape);
          } else {
            const crashProgress = (pointElapsed - peakTime) / (totalDuration - peakTime);
            price = peakPrice - (peakPrice - crashPrice) * Math.pow(crashProgress, crashShape);
          }

          points.push({
            x: (w / numPoints) * i,
            y: h - ((price - 34000) / 110)
          });
        }

        // Draw chart
        drawChart(ctx, {
          points: points,
          hasCrashed: gameState.hasCrashed
        });

        // Continue animation or end
        if (progress < 1) {
          gameState.chartAnimation = requestAnimationFrame(animateChart);
        } else {
          // Auto-sell if didn't click
          if (gameState.isPlaying) {
            handleSell();
          }
        }
      }

      animateChart();
    }
    
    async function handleSell() {
      if (!gameState.isPlaying) return;

      const now = performance.now();
      const sellButton = document.getElementById('sellButton');
      const gameStatus = document.getElementById('gameStatus');

      // Check if clicked before peak - TOO EARLY
      if (now < gameState.peakTime) {
        gameState.isPlaying = false;
        gameState.attempts.push(-1); // -1 indicates early click

        sellButton.disabled = true;
        gameStatus.textContent = 'TOO EARLY! Wait for the dump!';
        gameStatus.className = 'game-status status-go';

        // Cancel animation
        if (gameState.chartAnimation) {
          cancelAnimationFrame(gameState.chartAnimation);
        }

        // Update best time display
        updateBestTimeDisplay();
        updateResultsGrid();
        return;
      }

      // Clicked after peak - calculate reaction time
      const reactionTime = now - gameState.peakTime;
      gameState.attempts.push(reactionTime);
      gameState.isPlaying = false;

      // Update best time
      if (gameState.bestTime === null || reactionTime < gameState.bestTime) {
        gameState.bestTime = reactionTime;
      }

      // Award GC for fast reactions
      if (reactionTime < 1000) {
        await updateUserGC(300, 'reaction');
        Toast.success('Fast hands! +300 GC', 'PROFIT');
        gameStatus.textContent = `${reactionTime.toFixed(0)}ms - +300 GC!`;
        gameStatus.className = 'game-status';
        gameStatus.style.color = '#4CAF50';
      } else {
        gameStatus.textContent = `${reactionTime.toFixed(0)}ms - Too slow!`;
        gameStatus.className = 'game-status';
        gameStatus.style.color = '#a0a8b0';
      }

      // Update UI
      sellButton.disabled = true;

      // Cancel animation
      if (gameState.chartAnimation) {
        cancelAnimationFrame(gameState.chartAnimation);
      }

      // Update displays
      updateBestTimeDisplay();
      updateResultsGrid();
    }

    function updateBestTimeDisplay() {
      const bestTimeEl = document.getElementById('attemptsLeft');
      if (gameState.bestTime) {
        bestTimeEl.textContent = `${gameState.bestTime.toFixed(0)} ms`;
        bestTimeEl.style.color = gameState.bestTime < 1000 ? '#4CAF50' : '#a0a8b0';
      } else {
        bestTimeEl.textContent = '-- ms';
        bestTimeEl.style.color = '#a0a8b0';
      }
    }

    function updateResultsGrid() {
      const grid = document.getElementById('resultsGrid');
      grid.innerHTML = '';

      // Show last 5 attempts
      const recentAttempts = gameState.attempts.slice(-5);
      const validAttempts = recentAttempts.filter(t => t >= 0);
      const bestTime = validAttempts.length > 0 ? Math.min(...validAttempts) : null;

      recentAttempts.forEach((time, index) => {
        const actualIndex = gameState.attempts.length - recentAttempts.length + index;
        const card = document.createElement('div');
        const isBest = time >= 0 && time === bestTime;
        card.className = isBest ? 'result-card best' : 'result-card';

        if (time === -1) {
          // Too early
          card.innerHTML = `
            <div class="result-attempt">TRY ${actualIndex + 1}</div>
            <div class="result-time" style="color:#F44336">TOO EARLY</div>
          `;
        } else {
          const gpEarned = time < 1000 ? '+300 GC' : '0 GC';
          const color = time < 1000 ? '#4CAF50' : '#a0a8b0';
          card.innerHTML = `
            <div class="result-attempt">TRY ${actualIndex + 1}</div>
            <div class="result-time">${time.toFixed(0)}ms</div>
            <div class="result-time" style="color:${color};font-size:11px;">${gpEarned}</div>
          `;
        }
        grid.appendChild(card);
      });
    }

    async function saveScoreToSupabase(userId, timeMs) {
      try {
        // Save score to database
        const { error: scoreError } = await supabase
          .from('scores')
          .insert({
            user_id: userId,
            time_ms: Math.round(timeMs),
            game_type: 'reaction'
          });

        if (scoreError) {
          console.error('Failed to save score:', scoreError);
          Toast.error('Failed to save score', 'ERROR');
          return;
        }

        // Update quest progress
        await updateQuestProgress('daily_play_3');
        await updateQuestProgress('weekly_play_20');

        // Check for fast time quests (close to peak)
        if (timeMs < 300) {
          await updateQuestProgress('daily_fast_time');
        }
        if (timeMs < 200) {
          await updateQuestProgress('weekly_sub_250');
        }

        // Auto-complete login quest on first game
        await updateQuestProgress('daily_login');

        Toast.success('Score saved!', 'SUCCESS');

      } catch (e) {
        console.error('Error saving score:', e);
      }
    }

    function endGame() {
      const validAttempts = gameState.attempts.filter(t => t >= 0);
      const bestTime = validAttempts.length > 0 ? Math.min(...validAttempts) : null;

      if (bestTime !== null) {
        document.getElementById('gameStatus').textContent = `Game Over! Best: +${bestTime.toFixed(0)}ms`;
      } else {
        document.getElementById('gameStatus').textContent = `Game Over! All attempts disqualified`;
      }

      // Save score to Supabase
      if (bestTime !== null) {
        const userId = localStorage.getItem('duelpvp_user_id');

        if (userId) {
          saveScoreToSupabase(userId, bestTime);
        }
      }
    }
    
    function resetGame() {
      gameState = {
        attempts: [],
        bestTime: null,
        isPlaying: false,
        startTime: null,
        reactionTimer: null,
        chartAnimation: null
      };

      // Clear any running timers
      if (gameState.reactionTimer) clearTimeout(gameState.reactionTimer);
      if (gameState.chartAnimation) cancelAnimationFrame(gameState.chartAnimation);

      // Reset UI
      document.getElementById('chartContainer').className = 'chart-container';
      document.getElementById('sellButton').disabled = true;
      document.getElementById('gameStatus').textContent = 'Click START TRADE to begin';
      document.getElementById('gameStatus').style.color = '#a0a8b0';
      updateBestTimeDisplay();
      document.getElementById('resultsGrid').innerHTML = '';
      
      const canvas = document.getElementById('chartCanvas');
      const ctx = canvas.getContext('2d');
      drawChart(ctx, false);
    }

    // Crash Game Logic
    let crashGameState = {
      phase: 'waiting', // waiting, betting, flying, crashed
      currentMultiplier: 1.00,
      crashPoint: 0,
      seed: '',
      hash: '',
      betAmount: 0,
      autoCashout: 0,
      hashedIn: false,
      startTime: 0,
      countdown: 3, // Reduced from 5 to 3 seconds between rounds
      history: []
    };

    async function initCrashGame() {
      // Load history from localStorage
      const savedHistory = localStorage.getItem('crash_history');
      if (savedHistory) {
        crashGameState.history = JSON.parse(savedHistory);
        updateCrashHistory();
      }

      // Update GC display
      updateCrashGCDisplay();

      // Setup canvas
      const canvas = document.getElementById('crashTrailCanvas');
      canvas.width = canvas.offsetWidth;
      canvas.height = canvas.offsetHeight;

      // Event listeners
      document.getElementById('crashPlaceBetBtn').addEventListener('click', placeCrashBet);
      document.getElementById('crashCashoutBtn').addEventListener('click', crashCashout);

      // Start game loop
      startCrashRound();
    }

    async function updateCrashGCDisplay() {
      const gp = await getUserGC();
      document.getElementById('crashGCDisplay').textContent = gp;
      document.getElementById('crashCurrentBet').textContent = crashGameState.betAmount;

      if (crashGameState.betAmount > 0 && crashGameState.phase === 'flying') {
        const potential = Math.floor(crashGameState.betAmount * crashGameState.currentMultiplier);
        document.getElementById('crashPotentialWin').textContent = potential;
      } else {
        document.getElementById('crashPotentialWin').textContent = '0';
      }
    }

    function generateCrashPoint() {
      // Generate provably fair crash point
      const seed = Math.random().toString(36).substring(2) + Date.now().toString(36);
      const hash = SHA256(seed);

      // Convert hash to crash point (simplified version)
      const hexValue = hash.substring(0, 8);
      const intValue = parseInt(hexValue, 16);

      // Formula: 10% PLAYER EDGE (110% RTP) - players win over time!
      const result = (1.10 * Math.pow(2, 32)) / (Math.pow(2, 32) - intValue);
      const crashPoint = Math.max(1.00, Math.min(100, result));

      return { seed, hash, crashPoint };
    }

    // Simple SHA-256 implementation
    function SHA256(str) {
      return Array.from(str).reduce((hash, char) => {
        return ((hash << 5) - hash) + char.charCodeAt(0) | 0;
      }, 0).toString(16).padStart(8, '0').repeat(8);
    }

    async function startCrashRound() {
      // Reset state
      crashGameState.phase = 'waiting';
      crashGameState.currentMultiplier = 1.00;
      crashGameState.hashedIn = false;
      crashGameState.betAmount = 0; // Reset bet for new round
      crashGameState.countdown = 3; // Reduced from 5 to 3 seconds

      // Generate crash point for next round
      const { seed, hash, crashPoint } = generateCrashPoint();
      crashGameState.seed = seed;
      crashGameState.hash = hash;
      crashGameState.crashPoint = crashPoint;

      console.log('[Crash Game] New round started. Crash point:', crashPoint);

      // Display hash
      document.getElementById('crashHash').textContent = hash.substring(0, 32) + '...';
      document.getElementById('crashStatusText').textContent = 'Waiting for bets...';
      document.getElementById('crashMultiplierValue').textContent = '1.00x';

      // Enable bet button
      document.getElementById('crashPlaceBetBtn').disabled = false;
      document.getElementById('crashPlaceBetBtn').textContent = 'PLACE BET';

      // Update GC display
      updateCrashGCDisplay();

      // Countdown phase
      const countdownInterval = setInterval(() => {
        crashGameState.countdown--;
        const countdownEl = document.getElementById('crashCountdown');
        if (countdownEl) {
          countdownEl.textContent = crashGameState.countdown;
        }
        document.getElementById('crashGameStatus').innerHTML = `Next round starts in <span id="crashCountdown">${crashGameState.countdown}</span>s`;

        if (crashGameState.countdown <= 0) {
          clearInterval(countdownInterval);
          startFlying();
        }
      }, 1000);
    }

    function startFlying() {
      crashGameState.phase = 'flying';
      crashGameState.startTime = Date.now();

      document.getElementById('crashStatusText').textContent = 'Flying!';
      document.getElementById('crashGameStatus').textContent = 'Cash out before it crashes!';
      document.getElementById('crashPlaceBetBtn').disabled = true;

      const rocket = document.getElementById('crashRocket');
      const multiplierEl = document.getElementById('crashMultiplierValue');

      rocket.classList.add('flying');
      multiplierEl.classList.add('flying');

      // Enable cashout if player has bet
      if (crashGameState.betAmount > 0) {
        document.getElementById('crashCashoutBtn').disabled = false;
      }

      flyingLoop();
    }

    function flyingLoop() {
      if (crashGameState.phase !== 'flying') return;

      const elapsed = (Date.now() - crashGameState.startTime) / 1000;
      crashGameState.currentMultiplier = 1 + (elapsed * 0.3); // Increases 0.3x per second

      // Update display
      document.getElementById('crashMultiplierValue').textContent = crashGameState.currentMultiplier.toFixed(2) + 'x';
      updateCrashGCDisplay();

      // Move rocket up
      const rocket = document.getElementById('crashRocket');
      const progress = Math.min(0.9, elapsed / 10); // 10 seconds to reach top
      const bottom = 20 + (progress * 300); // Move from bottom:20px to bottom:320px
      rocket.style.bottom = bottom + 'px';

      // Draw trail
      drawCrashTrail();

      // Check for crash
      if (crashGameState.currentMultiplier >= crashGameState.crashPoint) {
        crash();
        return;
      }

      // Check auto-cashout
      if (crashGameState.autoCashout > 0 && crashGameState.currentMultiplier >= crashGameState.autoCashout && crashGameState.betAmount > 0) {
        crashCashout();
        return;
      }

      requestAnimationFrame(flyingLoop);
    }

    function drawCrashTrail() {
      const canvas = document.getElementById('crashTrailCanvas');
      const ctx = canvas.getContext('2d');

      const rocket = document.getElementById('crashRocket');
      const rocketRect = rocket.getBoundingClientRect();
      const containerRect = canvas.getBoundingClientRect();

      const x = rocketRect.left - containerRect.left + (rocketRect.width / 2);
      const y = rocketRect.top - containerRect.top + (rocketRect.height / 2);

      // Add glow trail
      ctx.fillStyle = `rgba(255, 214, 77, ${0.1 + Math.random() * 0.1})`;
      ctx.beginPath();
      ctx.arc(x, y + 20, 5 + Math.random() * 3, 0, Math.PI * 2);
      ctx.fill();

      // Fade existing trail
      ctx.fillStyle = 'rgba(16, 20, 24, 0.05)';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
    }

    function crash() {
      crashGameState.phase = 'crashed';

      const rocket = document.getElementById('crashRocket');
      const container = document.getElementById('crashRocketContainer');
      const multiplierEl = document.getElementById('crashMultiplierValue');

      rocket.classList.remove('flying');
      multiplierEl.classList.remove('flying');
      container.classList.add('crashed');

      document.getElementById('crashStatusText').textContent = 'CRASHED!';
      document.getElementById('crashStatusText').style.color = '#F44336';
      document.getElementById('crashMultiplierValue').textContent = crashGameState.crashPoint.toFixed(2) + 'x';
      document.getElementById('crashGameStatus').textContent = `Crashed at ${crashGameState.crashPoint.toFixed(2)}x`;
      document.getElementById('crashCashoutBtn').disabled = true;

      // If player had bet and didn't cash out, they lose
      if (crashGameState.betAmount > 0) {
        Toast.error(`Lost ${crashGameState.betAmount} GC at ${crashGameState.crashPoint.toFixed(2)}x`, 'CRASHED');
        crashGameState.betAmount = 0;
        updateCrashGCDisplay();
        updateDashboardStats();
      }

      // Add to history
      addToCrashHistory(crashGameState.crashPoint);

      console.log('[Crash Game] Crashed at', crashGameState.crashPoint.toFixed(2) + 'x', '- restarting in 2 seconds...');

      // Reset rocket position and start new round
      setTimeout(() => {
        console.log('[Crash Game] Starting new round...');
        rocket.style.bottom = '20px';
        container.classList.remove('crashed');
        document.getElementById('crashStatusText').style.color = '#a0a8b0';

        // Clear canvas
        const canvas = document.getElementById('crashTrailCanvas');
        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, canvas.width, canvas.height);

        // Start new round
        startCrashRound();
      }, 2000); // Reduced from 3000ms to 2000ms
    }

    async function placeCrashBet() {
      if (crashGameState.phase !== 'waiting') {
        Toast.error('Wait for next round', 'TOO LATE');
        return;
      }

      const betInput = document.getElementById('crashBetAmount');
      const betAmount = parseInt(betInput.value);
      const autoCashoutInput = document.getElementById('crashAutoCashout');
      const autoCashout = parseFloat(autoCashoutInput.value) || 0;

      const gp = await getUserGC();

      if (isNaN(betAmount) || betAmount < 10) {
        Toast.error('Minimum bet is 10 GC', 'INVALID BET');
        return;
      }

      if (betAmount > 10000) {
        Toast.error('Maximum bet is 10,000 GC', 'INVALID BET');
        return;
      }

      if (betAmount > gp) {
        Toast.error('Insufficient GC', 'INSUFFICIENT FUNDS');
        return;
      }

      // Deduct bet from balance
      await updateUserGC(-betAmount, 'crash');
      crashGameState.betAmount = betAmount;
      crashGameState.autoCashout = autoCashout;
      crashGameState.hashedIn = true;

      updateCrashGCDisplay();
      updateDashboardStats();

      Toast.success(`Bet placed: ${betAmount} GC`, 'BET PLACED');
      document.getElementById('crashPlaceBetBtn').disabled = true;
      document.getElementById('crashPlaceBetBtn').textContent = 'BET PLACED';
    }

    async function crashCashout() {
      if (crashGameState.phase !== 'flying' || crashGameState.betAmount <= 0) {
        return;
      }

      const winAmount = Math.floor(crashGameState.betAmount * crashGameState.currentMultiplier);
      const profit = winAmount - crashGameState.betAmount;

      // Add winnings to balance
      await updateUserGC(winAmount, 'crash');

      Toast.success(`Cashed out at ${crashGameState.currentMultiplier.toFixed(2)}x! Won ${winAmount} GC (+${profit})`, 'CASHED OUT');

      crashGameState.betAmount = 0;
      updateCrashGCDisplay();
      updateDashboardStats();

      document.getElementById('crashCashoutBtn').disabled = true;
    }

    function addToCrashHistory(crashPoint) {
      crashGameState.history.unshift(crashPoint);
      if (crashGameState.history.length > 20) {
        crashGameState.history = crashGameState.history.slice(0, 20);
      }
      localStorage.setItem('crash_history', JSON.stringify(crashGameState.history));
      updateCrashHistory();
    }

    function updateCrashHistory() {
      const historyList = document.getElementById('crashHistoryList');
      historyList.innerHTML = '';

      crashGameState.history.forEach(point => {
        const item = document.createElement('div');
        item.className = 'crash-history-item';

        if (point < 2) {
          item.classList.add('crashed-low');
        } else if (point < 5) {
          item.classList.add('crashed-med');
        } else {
          item.classList.add('crashed-high');
        }

        item.textContent = point.toFixed(2) + 'x';
        historyList.appendChild(item);
      });
    }

    // ========== QUEST SYSTEM - REBUILT FROM SCRATCH ==========

    // Quest definitions
    const QUESTS = {
      daily: [
        {id: 'first_login', name: 'First Steps', desc: 'Log in for the first time', target: 1, reward: 500, icon: '🗡️', type: 'regular'},
        {id: 'retweet_jan_2025', name: 'Retweet & Earn', desc: 'Retweet our latest post on X', target: 1, reward: 1000, icon: '🔄', type: 'manual'},
        {id: 'retweet_dec_2024', name: 'Spread the Word', desc: 'Retweet our discord announcement', target: 1, reward: 1000, icon: '🔄', type: 'manual'},
        {id: 'twitter_follow', name: 'Follow Us', desc: 'Follow @Duelpvp on X', target: 1, reward: 500, icon: '➕', type: 'manual'}
      ],
      weekly: [],
      special: []
    };

    // Tab switching
    function switchQuestTab(tab, questType) {
      document.querySelectorAll('.quest-tab').forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      loadQuests(questType);
    }

    // Main quest loader - uses server-side quest system
    async function loadQuests(type) {
      const questGrid = document.getElementById('questGrid');
      const comingSoonOverlay = document.getElementById('comingSoonOverlay');

      if (!questGrid) {
        console.error('Quest grid not found');
        return;
      }

      // Get user ID
      const session = getSession();
      const userId = session?.userId || localStorage.getItem('duelpvp_user_id');

      if (!userId) {
        questGrid.innerHTML = '<div class="no-data">Please log in to view quests</div>';
        return;
      }

      // Handle locked tabs
      if (type === 'weekly' || type === 'special') {
        questGrid.classList.add('locked');
        if (comingSoonOverlay) comingSoonOverlay.style.display = 'flex';
        questGrid.innerHTML = '<div class="no-data">Coming Soon</div>';
        return;
      } else {
        questGrid.classList.remove('locked');
        if (comingSoonOverlay) comingSoonOverlay.style.display = 'none';
        questGrid.style.opacity = '1';
        questGrid.style.filter = 'none';
        questGrid.style.pointerEvents = 'auto';
      }

      // Show loading
      questGrid.innerHTML = '<div class="no-data">Loading quests...</div>';

      try {
        // Fetch quests from server-side RPC
        const { data: questData, error: questError } = await supabase
          .rpc('get_user_quests', { p_user_id: userId });

        if (questError) {
          console.error('Quest load error:', questError);
          questGrid.innerHTML = '<div class="no-data">Error loading quests</div>';
          return;
        }

        // Filter quests based on tab type
        let questList = questData || [];
        if (type === 'completed') {
          questList = questList.filter(q => q.is_claimed);
        } else {
          // Show unclaimed quests
          questList = questList.filter(q => !q.is_claimed);
        }

        // Clear and render
        questGrid.innerHTML = '';

        if (questList.length === 0) {
          questGrid.innerHTML = '<div class="no-data">No quests available</div>';
          return;
        }

        // Quest icons - use logo for invite codes
        const questIcons = {
          'first_steps': '🎯',
          'invite_3_friends': '<img src="duelpvp-logo.svg" alt="Invite" style="width:20px;height:20px;vertical-align:middle;">',
          'fluffle_holder': '🐰',
          'bunnz_holder': '🔥',
          'megalio_holder': '🦁',
          'like_retweet': '❤️',
          'retweet_jan_2025': '🔄',
          'twitter_follow': '➕',
          'post_wallet': '💳'
        };

        // Render each quest
        questList.forEach(quest => {
          const isComplete = quest.is_completed;
          const isClaimed = quest.is_claimed;
          const icon = questIcons[quest.id] || '⭐';

          const card = document.createElement('div');
          card.className = 'quest-card' + (isComplete ? ' completed' : '') + (isComplete && !isClaimed ? ' claimable' : '');
          card.style.opacity = '1';
          card.style.visibility = 'visible';
          card.style.display = 'block';

          let html;

          // Simplified display for claimed quests
          if (isClaimed) {
            html = `
              <div class="quest-name"><span class="quest-icon">${icon}</span> ${quest.name}</div>
              <div style="text-align:center;padding:16px 0;color:#4CAF50;font-family:'Press Start 2P',monospace;font-size:12px;">
                +${quest.gc_reward} GC CLAIMED
              </div>
            `;
          } else {
            // Full display for unclaimed quests
            html = `
              <div class="quest-name"><span class="quest-icon">${icon}</span> ${quest.name}</div>
              <div class="quest-desc">${quest.description}</div>
              <div class="quest-progress">
            `;

            // Progress bar
            const pct = Math.min(100, (quest.progress / quest.target_count) * 100);
            html += `
              <div class="progress-bar"><div class="progress-fill" style="width:${pct}%"></div></div>
              <div class="progress-text">${quest.progress} / ${quest.target_count}</div>
            `;

            // Action button
            if (quest.id === 'daily_login') {
              // Daily login quest - always show claim button (can be claimed once per day)
              html += `<button class="action-btn btn-primary" style="width:100%;margin-top:8px;" onclick="claimDailyLogin()">CLAIM ${quest.gc_reward} GC</button>`;
            } else if (isComplete) {
              html += `<button class="action-btn btn-primary" style="width:100%;margin-top:8px;" onclick="claimQuestReward('${quest.id}')">CLAIM ${quest.gc_reward} GC</button>`;
            } else if (quest.id === 'invite_3_friends') {
              html += `<button class="action-btn btn-secondary" style="width:100%;margin-top:8px;" onclick="showInventory()">VIEW INVITE CODES</button>`;
            } else if (quest.id === 'like_retweet') {
              html += `<button class="action-btn btn-secondary" style="width:100%;margin-top:8px;" onclick="openLikeRetweetQuest()">START QUEST</button>`;
            } else if (quest.id === 'retweet_jan_2025') {
              html += `<button class="action-btn btn-secondary" style="width:100%;margin-top:8px;" onclick="openRetweetJan2025Quest()">START QUEST</button>`;
            } else if (quest.id === 'retweet_dec_2024') {
              html += `<button class="action-btn btn-secondary" style="width:100%;margin-top:8px;" onclick="openRetweetDec2024Quest()">START QUEST</button>`;
            } else if (quest.id === 'twitter_follow') {
              html += `<button class="action-btn btn-secondary" style="width:100%;margin-top:8px;" onclick="openTwitterFollowQuest()">START QUEST</button>`;
            } else if (quest.id === 'post_wallet') {
              html += `<button class="action-btn btn-secondary" style="width:100%;margin-top:8px;" onclick="openPostWalletQuest()">START QUEST</button>`;
            }

            html += `</div>`;
            html += `<div class="quest-reward">${quest.gc_reward} GC</div>`;
          }

          card.innerHTML = html;
          questGrid.appendChild(card);
        });

      } catch (err) {
        console.error('Quest system error:', err);
        questGrid.innerHTML = '<div class="no-data">Error loading quests</div>';
      }
    }

    // Claim daily login reward
    async function claimDailyLogin() {
      const session = getSession();
      const userId = session?.userId || localStorage.getItem('duelpvp_user_id');

      Loading.show('Claiming daily reward...');

      try {
        const { data, error } = await supabase.rpc('claim_daily_login', {
          p_user_id: userId
        });

        Loading.hide();

        if (error || !data?.success) {
          console.error('Daily login claim error:', error || data?.error);
          Toast.error(data?.error || 'Failed to claim daily reward', 'ERROR');
          return;
        }

        // Clear GC cache and update display
        gcCache.lastFetch = 0;
        const newGP = await getUserGC();
        updateGCDisplay(newGP, data.reward);

        Toast.success(`+${data.reward} GC earned!`, 'DAILY REWARD CLAIMED');

        // Reload current tab
        const activeTab = document.querySelector('.quest-tab.active');
        const tabType = activeTab ? activeTab.getAttribute('data-quest-tab') : 'daily';
        loadQuests(tabType);

      } catch (err) {
        Loading.hide();
        console.error('Daily login claim error:', err);
        Toast.error('An error occurred', 'ERROR');
      }
    }

    // Claim quest reward
    async function claimQuestReward(questId) {
      const session = getSession();
      const userId = session?.userId || localStorage.getItem('duelpvp_user_id');

      Loading.show('Claiming reward...');

      try {
        const { data, error } = await supabase.rpc('claim_quest_reward', {
          p_quest_id: questId,
          p_user_id: userId
        });

        Loading.hide();

        if (error || !data?.success) {
          console.error('Claim error:', error || data?.error);
          Toast.error(data?.error || 'Failed to claim reward', 'ERROR');
          return;
        }

        // Clear GC cache and update display
        gcCache.lastFetch = 0;
        const newGP = await getUserGC();
        updateGCDisplay(newGP, data.reward);

        Toast.success(`+${data.reward} GC earned!`, 'QUEST COMPLETED');

        // Reload current tab
        const activeTab = document.querySelector('.quest-tab.active');
        const tabType = activeTab ? activeTab.getAttribute('data-quest-tab') : 'daily';
        loadQuests(tabType);

      } catch (err) {
        Loading.hide();
        console.error('Claim error:', err);
        Toast.error('An error occurred', 'ERROR');
      }
    }

    // Check NFT holder status on login
    async function checkNFTHolderQuests(walletAddress) {
      try {
        const { error } = await supabase.rpc('check_nft_holder_quests', {
          p_wallet_address: walletAddress.toLowerCase()
        });
        if (error) console.error('NFT check error:', error);
      } catch (err) {
        console.error('NFT check failed:', err);
      }
    }

    // Update quest progress
    async function updateQuestProgress(questId, amount = 1) {
      const session = getSession();
      const userId = session?.userId || localStorage.getItem('duelpvp_user_id');

      try {
        const { error } = await supabase.rpc('update_quest_progress', {
          p_quest_id: questId,
          p_increment: amount,
          p_user_id: userId
        });
        if (error) console.error('Progress update error:', error);
      } catch (err) {
        console.error('Progress update failed:', err);
      }
    }

    // X post sharing quest
    async function openSharePostQuest() {
      // Open the specific X post to retweet
      const postUrl = 'https://x.com/Duelpvp/status/1991226071639798202';
      window.open(postUrl, '_blank');

      // Show modal to submit retweet link
      const modalHtml = `
        <div style="text-align:center;">
          <p style="margin-bottom:16px;color:#e6ecf1;font-size:12px;">
            1. Retweet our post on X<br>
            2. Copy the link to your retweet<br>
            3. Paste it below to complete the quest
          </p>
          <input type="text" id="retweetLinkInput" placeholder="Paste your retweet link here..."
            style="width:100%;padding:12px;background:rgba(0,0,0,.4);border:2px solid rgba(255,214,77,.3);border-radius:8px;color:#e6ecf1;font-family:monospace;font-size:12px;margin-bottom:16px;">
          <div style="background:rgba(255,193,7,.1);border:1px solid rgba(255,193,7,.3);border-radius:8px;padding:12px;margin-bottom:16px;">
            <p style="color:#ffc107;font-size:10px;margin:0;">
              Note: Your submission will be manually verified. GC will be granted immediately but may be revoked if the retweet is not valid.
            </p>
          </div>
        </div>
      `;

      const confirmed = await Modal.show({ html: modalHtml, title: 'Retweet Quest', type: 'confirm' });
      if (!confirmed) return;

      const retweetLink = document.getElementById('retweetLinkInput')?.value?.trim();
      if (!retweetLink) {
        Toast.error('Please paste your retweet link', 'ERROR');
        return;
      }

      // Validate it looks like an X/Twitter link
      if (!retweetLink.includes('x.com/') && !retweetLink.includes('twitter.com/')) {
        Toast.error('Please paste a valid X/Twitter link', 'ERROR');
        return;
      }

      Loading.show('Submitting...');

      try {
        const session = getSession();
        const userId = session?.userId || localStorage.getItem('duelpvp_user_id');

        // Store the submission for manual review
        const { error: submitError } = await supabase
          .from('quest_submissions')
          .insert({
            user_id: userId,
            quest_id: 'share_post',
            submission_data: { retweet_url: retweetLink },
            status: 'pending'
          });

        if (submitError) {
          console.error('Submission error:', submitError);
          // Continue anyway - we'll still grant the GC
        }

        // Update quest progress
        await updateQuestProgress('share_post', 1);

        Loading.hide();
        Toast.success('+500 GC earned! (Subject to verification)', 'QUEST SUBMITTED');

        // Reload quests
        const activeTab = document.querySelector('.quest-tab.active');
        const tabType = activeTab ? activeTab.getAttribute('data-quest-tab') : 'daily';
        loadQuests(tabType);

      } catch (err) {
        Loading.hide();
        console.error('Quest submission error:', err);
        Toast.error('Failed to submit', 'ERROR');
      }
    }

    // Like & Retweet quest (OLD - kept for users who already completed it)
    async function openLikeRetweetQuest() {
      // Open the specific X post to like and retweet
      const postUrl = 'https://x.com/Duelpvp/status/1991226071639798202';
      window.open(postUrl, '_blank');

      // Show modal to submit link
      const modalHtml = `
        <div style="text-align:center;">
          <p style="margin-bottom:16px;color:#e6ecf1;font-size:12px;">
            1. Like and retweet our post on X<br>
            2. Copy the link to your retweet<br>
            3. Paste it below to complete the quest
          </p>
          <input type="text" id="likeRetweetLinkInput" placeholder="Paste your retweet link here..."
            style="width:100%;padding:12px;background:rgba(0,0,0,.4);border:2px solid rgba(255,214,77,.3);border-radius:8px;color:#e6ecf1;font-family:monospace;font-size:12px;margin-bottom:16px;">
          <div style="background:rgba(255,193,7,.1);border:1px solid rgba(255,193,7,.3);border-radius:8px;padding:12px;margin-bottom:16px;">
            <p style="color:#ffc107;font-size:10px;margin:0;">
              Note: Your submission will be manually verified. GC will be granted immediately but may be revoked if the like/retweet is not valid.
            </p>
          </div>
        </div>
      `;

      const confirmed = await Modal.show({ html: modalHtml, title: 'Like & Retweet Quest', type: 'confirm' });
      if (!confirmed) return;

      const likeRetweetLink = document.getElementById('likeRetweetLinkInput')?.value?.trim();
      if (!likeRetweetLink) {
        Toast.error('Please paste your retweet link', 'ERROR');
        return;
      }

      // Validate it looks like an X/Twitter link
      if (!likeRetweetLink.includes('x.com/') && !likeRetweetLink.includes('twitter.com/')) {
        Toast.error('Please paste a valid X/Twitter link', 'ERROR');
        return;
      }

      Loading.show('Submitting...');

      try {
        const session = getSession();
        const userId = session?.userId || localStorage.getItem('duelpvp_user_id');

        // Complete and claim the quest in one call
        const { data, error } = await supabase.rpc('complete_manual_quest', {
          p_quest_id: 'like_retweet',
          p_user_id: userId
        });

        Loading.hide();

        if (error || !data?.success) {
          console.error('Quest error:', error || data?.error);
          Toast.error(data?.error || 'Failed to complete quest', 'ERROR');
        } else {
          // Clear GC cache and update display
          gcCache.lastFetch = 0;
          const newGC = await getUserGC();
          updateGCDisplay(newGC, data.reward);
          Toast.success(`+${data.reward} GC earned!`, 'QUEST COMPLETED');
        }

        // Reload quests
        const activeTab = document.querySelector('.quest-tab.active');
        const tabType = activeTab ? activeTab.getAttribute('data-quest-tab') : 'daily';
        loadQuests(tabType);

      } catch (err) {
        Loading.hide();
        console.error('Quest submission error:', err);
        Toast.error('Failed to submit', 'ERROR');
      }
    }

    // NEW Retweet quest (January 2025)
    async function openRetweetJan2025Quest() {
      // Open the specific X post to retweet
      const postUrl = 'https://x.com/Duelpvp/status/1998705426238509128';
      window.open(postUrl, '_blank');

      // Show modal to submit link
      const modalHtml = `
        <div style="text-align:center;">
          <p style="margin-bottom:16px;color:#e6ecf1;font-size:12px;">
            1. Retweet our post on X<br>
            2. Copy the link to your retweet<br>
            3. Paste it below to complete the quest
          </p>
          <input type="text" id="retweetJan2025LinkInput" placeholder="Paste your retweet link here..."
            style="width:100%;padding:12px;background:rgba(0,0,0,.4);border:2px solid rgba(255,214,77,.3);border-radius:8px;color:#e6ecf1;font-family:monospace;font-size:12px;margin-bottom:16px;">
          <div style="background:rgba(255,193,7,.1);border:1px solid rgba(255,193,7,.3);border-radius:8px;padding:12px;margin-bottom:16px;">
            <p style="color:#ffc107;font-size:10px;margin:0;">
              Note: Your submission will be manually verified. GC will be granted immediately but may be revoked if the retweet is not valid.
            </p>
          </div>
        </div>
      `;

      const confirmed = await Modal.show({ html: modalHtml, title: 'Retweet & Earn Quest', type: 'confirm' });
      if (!confirmed) return;

      const retweetLink = document.getElementById('retweetJan2025LinkInput')?.value?.trim();
      if (!retweetLink) {
        Toast.error('Please paste your retweet link', 'ERROR');
        return;
      }

      // Validate it looks like an X/Twitter link
      if (!retweetLink.includes('x.com/') && !retweetLink.includes('twitter.com/')) {
        Toast.error('Please paste a valid X/Twitter link', 'ERROR');
        return;
      }

      Loading.show('Submitting...');

      try {
        const session = getSession();
        const userId = session?.userId || localStorage.getItem('duelpvp_user_id');

        // Complete and claim the quest in one call
        const { data, error } = await supabase.rpc('complete_manual_quest', {
          p_quest_id: 'retweet_jan_2025',
          p_user_id: userId
        });

        Loading.hide();

        if (error || !data?.success) {
          console.error('Quest error:', error || data?.error);
          Toast.error(data?.error || 'Failed to complete quest', 'ERROR');
        } else {
          // Clear GC cache and update display
          gcCache.lastFetch = 0;
          const newGC = await getUserGC();
          updateGCDisplay(newGC, data.reward);
          Toast.success(`+${data.reward} GC earned!`, 'QUEST COMPLETED');
        }

        // Reload quests
        const activeTab = document.querySelector('.quest-tab.active');
        const tabType = activeTab ? activeTab.getAttribute('data-quest-tab') : 'daily';
        loadQuests(tabType);

      } catch (err) {
        Loading.hide();
        console.error('Quest submission error:', err);
        Toast.error('Failed to submit', 'ERROR');
      }
    }

    // NEW Retweet quest (December 2024)
    async function openRetweetDec2024Quest() {
      // Open the specific X post to retweet
      const postUrl = 'https://x.com/Duelpvp/status/2002139478585192554';
      window.open(postUrl, '_blank');

      // Show modal to submit link
      const modalHtml = `
        <div style="text-align:center;">
          <p style="margin-bottom:16px;color:#e6ecf1;font-size:12px;">
            1. Retweet our post on X<br>
            2. Copy the link to your retweet<br>
            3. Paste it below to complete the quest
          </p>
          <input type="text" id="retweetDec2024LinkInput" placeholder="Paste your retweet link here..."
            style="width:100%;padding:12px;background:rgba(0,0,0,.4);border:2px solid rgba(255,214,77,.3);border-radius:8px;color:#e6ecf1;font-family:monospace;font-size:12px;margin-bottom:16px;">
          <div style="background:rgba(255,193,7,.1);border:1px solid rgba(255,193,7,.3);border-radius:8px;padding:12px;margin-bottom:16px;">
            <p style="color:#ffc107;font-size:10px;margin:0;">
              Note: Your submission will be manually verified. GC will be granted immediately but may be revoked if the retweet is not valid.
            </p>
          </div>
        </div>
      `;

      const confirmed = await Modal.show({ html: modalHtml, title: 'Spread the Word Quest', type: 'confirm' });
      if (!confirmed) return;

      const retweetLink = document.getElementById('retweetDec2024LinkInput')?.value?.trim();
      if (!retweetLink) {
        Toast.error('Please paste your retweet link', 'ERROR');
        return;
      }

      // Validate it looks like an X/Twitter link
      if (!retweetLink.includes('x.com/') && !retweetLink.includes('twitter.com/')) {
        Toast.error('Please paste a valid X/Twitter link', 'ERROR');
        return;
      }

      Loading.show('Submitting...');

      try {
        const session = getSession();
        const userId = session?.userId || localStorage.getItem('duelpvp_user_id');

        // Complete and claim the quest in one call
        const { data, error } = await supabase.rpc('complete_manual_quest', {
          p_quest_id: 'retweet_dec_2024',
          p_user_id: userId
        });

        Loading.hide();

        if (error || !data?.success) {
          console.error('Quest error:', error || data?.error);
          Toast.error(data?.error || 'Failed to complete quest', 'ERROR');
        } else {
          // Clear GC cache and update display
          gcCache.lastFetch = 0;
          const newGC = await getUserGC();
          updateGCDisplay(newGC, data.reward);
          Toast.success(`+${data.reward} GC earned!`, 'QUEST COMPLETED');
        }

        // Reload quests
        const activeTab = document.querySelector('.quest-tab.active');
        const tabType = activeTab ? activeTab.getAttribute('data-quest-tab') : 'daily';
        loadQuests(tabType);

      } catch (err) {
        Loading.hide();
        console.error('Quest submission error:', err);
        Toast.error('Failed to submit', 'ERROR');
      }
    }

    // Twitter Follow quest
    async function openTwitterFollowQuest() {
      // Open the Duelpvp X profile to follow
      const profileUrl = 'https://x.com/Duelpvp';
      window.open(profileUrl, '_blank');

      // Show modal to submit X account link
      const modalHtml = `
        <div style="text-align:center;">
          <p style="margin-bottom:16px;color:#e6ecf1;font-size:12px;">
            1. Follow @Duelpvp on X<br>
            2. Copy the link to your X profile<br>
            3. Paste it below to verify you're following
          </p>
          <input type="text" id="twitterFollowLinkInput" placeholder="Paste your X profile link here..."
            style="width:100%;padding:12px;background:rgba(0,0,0,.4);border:2px solid rgba(255,214,77,.3);border-radius:8px;color:#e6ecf1;font-family:monospace;font-size:12px;margin-bottom:16px;">
          <div style="background:rgba(255,193,7,.1);border:1px solid rgba(255,193,7,.3);border-radius:8px;padding:12px;margin-bottom:16px;">
            <p style="color:#ffc107;font-size:10px;margin:0;">
              Note: Your submission will be manually verified. GC will be granted immediately but may be revoked if you are not following.
            </p>
          </div>
        </div>
      `;

      const confirmed = await Modal.show({ html: modalHtml, title: 'Follow Quest', type: 'confirm' });
      if (!confirmed) return;

      const twitterFollowLink = document.getElementById('twitterFollowLinkInput')?.value?.trim();
      if (!twitterFollowLink) {
        Toast.error('Please paste your X profile link', 'ERROR');
        return;
      }

      // Validate it looks like an X/Twitter link
      if (!twitterFollowLink.includes('x.com/') && !twitterFollowLink.includes('twitter.com/')) {
        Toast.error('Please paste a valid X/Twitter profile link', 'ERROR');
        return;
      }

      Loading.show('Submitting...');

      try {
        const session = getSession();
        const userId = session?.userId || localStorage.getItem('duelpvp_user_id');

        // Complete and claim the quest in one call
        const { data, error } = await supabase.rpc('complete_manual_quest', {
          p_quest_id: 'twitter_follow',
          p_user_id: userId
        });

        Loading.hide();

        if (error || !data?.success) {
          console.error('Quest error:', error || data?.error);
          Toast.error(data?.error || 'Failed to complete quest', 'ERROR');
        } else {
          // Clear GC cache and update display
          gcCache.lastFetch = 0;
          const newGC = await getUserGC();
          updateGCDisplay(newGC, data.reward);
          Toast.success(`+${data.reward} GC earned!`, 'QUEST COMPLETED');
        }

        // Reload quests
        const activeTab = document.querySelector('.quest-tab.active');
        const tabType = activeTab ? activeTab.getAttribute('data-quest-tab') : 'daily';
        loadQuests(tabType);

      } catch (err) {
        Loading.hide();
        console.error('Quest submission error:', err);
        Toast.error('Failed to submit', 'ERROR');
      }
    }

    // Post Wallet quest
    async function openPostWalletQuest() {
      // Open the specific tweet to post wallet under
      const tweetUrl = 'https://x.com/Duelpvp/status/1991529218593943677?s=20';
      window.open(tweetUrl, '_blank');

      // Show modal to submit tweet reply link
      const modalHtml = `
        <div style="text-align:center;">
          <p style="margin-bottom:16px;color:#e6ecf1;font-size:12px;">
            1. Post your EVM wallet address as a reply to our tweet<br>
            2. Copy the link to your reply<br>
            3. Paste it below to complete the quest
          </p>
          <input type="text" id="walletReplyLinkInput" placeholder="Paste your tweet reply link here..."
            style="width:100%;padding:12px;background:rgba(0,0,0,.4);border:2px solid rgba(255,214,77,.3);border-radius:8px;color:#e6ecf1;font-family:monospace;font-size:12px;margin-bottom:16px;">
          <div style="background:rgba(255,193,7,.1);border:1px solid rgba(255,193,7,.3);border-radius:8px;padding:12px;margin-bottom:16px;">
            <p style="color:#ffc107;font-size:10px;margin:0;">
              Note: Your submission will be manually verified. GC will be granted immediately but may be revoked if the wallet address is not posted under the tweet.
            </p>
          </div>
        </div>
      `;

      const confirmed = await Modal.show({ html: modalHtml, title: 'Post Wallet Quest', type: 'confirm' });
      if (!confirmed) return;

      const walletReplyLink = document.getElementById('walletReplyLinkInput')?.value?.trim();
      if (!walletReplyLink) {
        Toast.error('Please paste your tweet reply link', 'ERROR');
        return;
      }

      // Validate it looks like an X/Twitter link
      if (!walletReplyLink.includes('x.com/') && !walletReplyLink.includes('twitter.com/')) {
        Toast.error('Please paste a valid X/Twitter link', 'ERROR');
        return;
      }

      Loading.show('Submitting...');

      try {
        const session = getSession();
        const userId = session?.userId || localStorage.getItem('duelpvp_user_id');

        // Complete and claim the quest in one call
        const { data, error } = await supabase.rpc('complete_manual_quest', {
          p_quest_id: 'post_wallet',
          p_user_id: userId
        });

        Loading.hide();

        if (error || !data?.success) {
          console.error('Quest error:', error || data?.error);
          Toast.error(data?.error || 'Failed to complete quest', 'ERROR');
        } else {
          // Clear GC cache and update display
          gcCache.lastFetch = 0;
          const newGC = await getUserGC();
          updateGCDisplay(newGC, data.reward);
          Toast.success(`+${data.reward} GC earned!`, 'QUEST COMPLETED');
        }

        // Reload quests
        const activeTab = document.querySelector('.quest-tab.active');
        const tabType = activeTab ? activeTab.getAttribute('data-quest-tab') : 'daily';
        loadQuests(tabType);

      } catch (err) {
        Loading.hide();
        console.error('Quest submission error:', err);
        Toast.error('Failed to submit', 'ERROR');
      }
    }

    // Inventory and Shop System
    const SHOP_ITEMS = [
      {id: 'sword_bronze', name: 'Bronze Sword', desc: 'A sturdy starter weapon', price: 1000, icon: '🗡️', type: 'weapon'},
      {id: 'sword_iron', name: 'Iron Sword', desc: 'Sharper than bronze', price: 2500, icon: '⚔️', type: 'weapon'},
      {id: 'sword_steel', name: 'Steel Sword', desc: 'Forged with precision', price: 5000, icon: '🗡️', type: 'weapon'},
      {id: 'armor_leather', name: 'Leather Armor', desc: 'Basic protection', price: 1500, icon: '🛡️', type: 'armor'},
      {id: 'armor_chain', name: 'Chain Mail', desc: 'Medium protection', price: 3500, icon: '🛡️', type: 'armor'},
      {id: 'armor_plate', name: 'Plate Armor', desc: 'Heavy protection', price: 7500, icon: '🛡️', type: 'armor'},
      {id: 'potion_health', name: 'Health Potion', desc: 'Restores vitality', price: 500, icon: '🧪', type: 'consumable'},
      {id: 'potion_speed', name: 'Speed Potion', desc: 'Boosts reflexes', price: 750, icon: '⚗️', type: 'consumable'},
      {id: 'cape_red', name: 'Red Cape', desc: 'Show off your style', price: 2000, icon: '🎽', type: 'cosmetic'},
      {id: 'cape_blue', name: 'Blue Cape', desc: 'Cool and collected', price: 2000, icon: '🎽', type: 'cosmetic'},
      {id: 'pet_dog', name: 'War Hound', desc: 'A loyal companion', price: 10000, icon: '🐕', type: 'pet'},
      {id: 'pet_dragon', name: 'Baby Dragon', desc: 'Rare and powerful', price: 50000, icon: '🐉', type: 'pet'}
    ];

    // Show inventory screen
    function showInventory() {
      swapContent('inventory');
    }

    async function loadInventory() {
      const session = getSession();
      const userId = session?.userId;

      if (!userId) {
        console.warn('No user ID found, skipping inventory load');
        return;
      }

      console.log('Loading inventory for user:', userId);

      // Get inventory items (NFTs, rewards, etc.)
      const { data: inventoryItems, error: itemsError } = await supabase
        .from('inventory_items')
        .select('*')
        .eq('user_id', userId);

      if (itemsError) {
        console.error('Failed to get inventory items:', itemsError);
      }

      console.log('Inventory items:', inventoryItems);

      // Render inventory
      const inventoryGrid = document.getElementById('inventoryGrid');
      inventoryGrid.innerHTML = '';

      // Show inventory items
      if (inventoryItems && inventoryItems.length > 0) {
        inventoryItems.forEach(item => {
          const slot = document.createElement('div');
          slot.className = `inventory-slot rarity-${item.item_rarity}`;

          const iconSrc = item.metadata?.svg_icon === 'katana'
            ? 'katana.svg'
            : 'duelpvp-logo.svg';

          slot.innerHTML = `
            <div class="item-icon">
              <img src="${iconSrc}" alt="${item.item_name}" style="width:48px;height:48px;">
            </div>
            <div class="item-name" style="color:#FFD700;font-weight:bold;">${item.item_name}</div>
          `;
          slot.title = item.item_description || item.item_name;
          slot.style.border = '2px solid #FFD700';
          slot.style.background = 'rgba(255, 215, 0, 0.1)';
          inventoryGrid.appendChild(slot);
        });
      } else {
        // Show empty state
        const emptyState = document.getElementById('inventoryEmpty');
        if (emptyState) {
          emptyState.style.display = 'block';
        }
      }

      // Get user data for shop
      const { data: userData } = await supabase
        .from('users')
        .select('points')
        .eq('id', userId)
        .single();

      const gp = userData?.points || 0;

      // Render shop
      const shopGrid = document.getElementById('shopGrid');
      shopGrid.innerHTML = '';

      SHOP_ITEMS.forEach(item => {
        const shopCard = document.createElement('div');
        shopCard.className = 'shop-item';
        shopCard.innerHTML = `
          <div class="item-icon">${item.icon}</div>
          <div class="shop-item-name">${item.name}</div>
          <div class="shop-item-desc">${item.desc}</div>
          <div class="shop-item-price">${item.price.toLocaleString()} GC</div>
          <button class="buy-btn" ${gp < item.price ? 'disabled' : ''}>BUY</button>
        `;

        const buyBtn = shopCard.querySelector('.buy-btn');
        buyBtn.addEventListener('click', () => buyItem(item));

        shopGrid.appendChild(shopCard);
      });
    }

    function buyItem(item) {
      const email = localStorage.getItem('duelpvp_email') || 'anonymous';
      let gp = parseInt(localStorage.getItem('duelpvp_gc') || '0');
      let inventory = JSON.parse(localStorage.getItem(`duelpvp_inventory_${email}`) || '[]');

      if (gp < item.price) {
        Modal.alert('Not enough GC! Complete quests or play games to earn more.', 'Insufficient Funds');
        return;
      }

      // Check if inventory is full
      if (inventory.length >= 28 && !inventory.find(i => i.id === item.id && item.type === 'consumable')) {
        Modal.alert('Your inventory is full! Maximum 28 items can be held.', 'Inventory Full');
        return;
      }

      // Deduct GC
      gp -= item.price;
      localStorage.setItem('duelpvp_gc', gp.toString());

      // Add to inventory
      if (item.type === 'consumable') {
        const existing = inventory.find(i => i.id === item.id);
        if (existing) {
          existing.count++;
        } else {
          inventory.push({id: item.id, count: 1});
        }
      } else {
        inventory.push({id: item.id, count: 1});
      }

      localStorage.setItem(`duelpvp_inventory_${email}`, JSON.stringify(inventory));

      // Update quest progress
      updateQuestProgress('weekly_shop');

      // Reload
      loadInventory();
      Toast.success(`${item.icon} ${item.name} added to inventory!`, 'ITEM PURCHASED');
    }

    // ===============================================
    // STAKING SYSTEM (SERVER-SIDE SECURE)
    // ===============================================
    // All calculations happen server-side to prevent cheating

    // ===============================================
    // GC BALANCE SYSTEM (SECURE - DATABASE BACKED)
    // ===============================================

    // Cache for GC balance to reduce database queries
    let gcCache = {
      balance: 0,
      lastFetch: 0,
      cacheTime: 5000 // Cache for 5 seconds
    };

    // Helper functions for GC
    async function getUserGC() {
      // Get user ID from session or old localStorage format
      const session = getSession();
      const userId = session?.userId || localStorage.getItem('duelpvp_user_id');

      // Fallback to localStorage for test mode
      if (!userId || userId.startsWith('test-')) {
        return parseInt(localStorage.getItem('duelpvp_gc')) || 0;
      }

      // Check cache first
      const now = Date.now();
      if (gcCache.lastFetch && (now - gcCache.lastFetch < gcCache.cacheTime)) {
        return gcCache.balance;
      }

      try {
        // Fetch GC directly from users table (most reliable method)
        const { data: userData, error: userError } = await supabase
          .from('users')
          .select('gc_balance')
          .eq('id', userId)
          .single();

        console.log('getUserGC result:', { userData, userError, userId });

        if (!userError && userData) {
          const balance = userData.gc_balance || 0;
          gcCache.balance = balance;
          gcCache.lastFetch = now;
          return balance;
        }

        // If direct fetch failed, try RPC as fallback
        const { data, error } = await supabase
          .rpc('get_user_gc', { p_user_id: userId });

        console.log('get_user_gc RPC result:', { data, error });

        if (error) {
          console.error('Failed to fetch GC:', error);
          return parseInt(localStorage.getItem('duelpvp_gc')) || 0;
        }

        gcCache.balance = data || 0;
        gcCache.lastFetch = now;
        return data || 0;
      } catch (e) {
        console.error('Error getting GC:', e);
        return parseInt(localStorage.getItem('duelpvp_gc')) || 0;
      }
    }

    function getUserLevel() {
      const gp = gcCache.balance || parseInt(localStorage.getItem('duelpvp_gc')) || 0;
      // Calculate level based on GC (every 50,000 GC = 1 level)
      return Math.floor(gp / 50000) + 1;
    }

    async function updateUserGC(amount, gameType = null) {
      // Get user ID from session or old localStorage format
      const session = getSession();
      const userId = session?.userId || localStorage.getItem('duelpvp_user_id');

      // Fallback to localStorage for test mode
      if (!userId || userId.startsWith('test-')) {
        const currentGP = parseInt(localStorage.getItem('duelpvp_gc')) || 0;
        const newGP = currentGP + amount;

        // Prevent negative balance even in test mode
        if (newGP < 0) {
          Toast.error('Insufficient balance', 'TRANSACTION FAILED');
          return currentGP;
        }

        localStorage.setItem('duelpvp_gc', newGP.toString());

        // Update UI
        updateGCDisplay(newGP, amount);
        return newGP;
      }

      try {
        // Debug: Check session state before RPC call
        const { data: { session: currentSession } } = await supabase.auth.getSession();
        console.log('[GP Update] Session check before RPC:', {
          hasSession: !!currentSession,
          userId: currentSession?.user?.id,
          tokenPreview: currentSession?.access_token?.substring(0, 20) + '...'
        });

        // Try secure JWT-based function first
        const transactionType = amount > 0 ? 'game_win' : 'game_loss';
        console.log('[GC Update] Calling secure_update_gc with:', { amount, transactionType, gameType });
        let result = await supabase.rpc('secure_update_gc', {
          p_amount: amount,
          p_transaction_type: transactionType,
          p_game_type: gameType
        });
        console.log('[GC Update] RPC result:', result);

        // If secure function fails, fallback to old function
        if (result.error) {
          console.log('Secure update failed, using fallback:', result.error);
          result = await supabase.rpc('update_user_gc', {
            p_user_id: userId,
            p_amount: amount,
            p_transaction_type: transactionType,
            p_game_type: gameType
          });
        }

        const { data, error } = result;

        if (error) {
          console.error('Failed to update GC:', error);

          // If database function doesn't exist, fall back to localStorage with validation
          if (error.message && error.message.includes('function') && error.message.includes('does not exist')) {
            Toast.error('Database not configured! Using localStorage fallback.', 'WARNING');

            const currentGP = parseInt(localStorage.getItem('duelpvp_gc')) || 0;
            const newGP = currentGP + amount;

            // Prevent negative balance
            if (newGP < 0) {
              Toast.error('Insufficient balance', 'TRANSACTION FAILED');
              return currentGP;
            }

            localStorage.setItem('duelpvp_gc', newGP.toString());
            gcCache.balance = newGP;
            gcCache.lastFetch = Date.now();
            updateGCDisplay(newGP, amount);
            return newGP;
          }

          Toast.error('Failed to update balance', 'ERROR');
          return gcCache.balance;
        }

        // Check if update was successful
        if (!data || data.length === 0 || !data[0].success) {
          const message = data && data[0] ? data[0].message : 'Update failed';
          Toast.error(message, 'TRANSACTION FAILED');
          return gcCache.balance;
        }

        const newBalance = data[0].new_balance;

        // Update cache
        gcCache.balance = newBalance;
        gcCache.lastFetch = Date.now();

        // Update UI
        updateGCDisplay(newBalance, amount);

        return newBalance;
      } catch (e) {
        console.error('Error updating GC:', e);
        Toast.error('Connection error', 'ERROR');
        return gcCache.balance;
      }
    }

    // Create gold particle effect
    function createGoldParticles(element, count = 12) {
      if (!element) return;

      const rect = element.getBoundingClientRect();
      const centerX = rect.left + rect.width / 2;
      const centerY = rect.top + rect.height / 2;

      for (let i = 0; i < count; i++) {
        const particle = document.createElement('div');
        particle.className = 'gold-particle';
        particle.style.left = centerX + 'px';
        particle.style.top = centerY + 'px';

        // Random direction
        const angle = (Math.PI * 2 * i) / count;
        const distance = 60 + Math.random() * 40;
        const tx = Math.cos(angle) * distance;
        const ty = Math.sin(angle) * distance - 20; // Slight upward bias

        particle.style.setProperty('--tx', tx + 'px');
        particle.style.setProperty('--ty', ty + 'px');

        document.body.appendChild(particle);

        // Remove after animation
        setTimeout(() => particle.remove(), 800);
      }
    }

    // Helper function to update GC displays across the UI
    function updateGCDisplay(newGP, changeAmount) {
      // Update dashboard display if visible with animation
      const dashboardGPEl = document.getElementById('dashboardGCBalance');
      if (dashboardGPEl) {
        const displayGP = newGP;
        const formattedGP = displayGP >= 1000000 ? `${(displayGP/1000000).toFixed(1)}M` : displayGP >= 1000 ? `${(displayGP/1000).toFixed(1)}K` : displayGP;

        // Apply animation
        dashboardGPEl.classList.remove('gp-change', 'gp-increase', 'gp-decrease');
        void dashboardGPEl.offsetWidth; // Trigger reflow
        dashboardGPEl.classList.add('gp-change');

        if (changeAmount > 0) {
          dashboardGPEl.classList.add('gp-increase');
          // Trigger gold particles on GC gain
          createGoldParticles(dashboardGPEl);
        } else if (changeAmount < 0) {
          dashboardGPEl.classList.add('gp-decrease');
        }

        dashboardGPEl.textContent = formattedGP;

        // Remove animation classes after animation completes
        setTimeout(() => {
          dashboardGPEl.classList.remove('gp-change', 'gp-increase', 'gp-decrease');
        }, 300);
      }

      // Update campaign rank
      updateCampaignRank();
    }

    // Initialize GC cache on login/page load
    async function initializeGCCache() {
      // Get user ID from session or old localStorage format
      const session = getSession();
      const userId = session?.userId || localStorage.getItem('duelpvp_user_id');
      if (userId && !userId.startsWith('test-')) {
        await getUserGC(); // This will populate the cache
      }
    }

    // Load and display user's invite code
    async function loadUserInviteCode() {
      const inviteCodeEl = document.getElementById('userInviteCode');
      if (!inviteCodeEl) return;

      const session = getSession();
      const userId = session?.userId;
      if (!userId) {
        inviteCodeEl.textContent = 'No code yet';
        return;
      }

      try {
        const { data, error } = await supabase
          .rpc('get_user_invite_codes', { p_user_id: userId });

        if (error) {
          console.error('Error loading invite code:', error);
          inviteCodeEl.textContent = 'Error loading';
          return;
        }

        // Find first unused code
        const unusedCode = data && data.find(c => !c.used);
        if (unusedCode) {
          inviteCodeEl.textContent = unusedCode.code;
        } else {
          inviteCodeEl.textContent = 'All codes used';
        }
      } catch (err) {
        console.error('Failed to load invite code:', err);
        inviteCodeEl.textContent = 'Error';
      }
    }

    // Update campaign rank display
    async function updateCampaignRank() {
      const userId = localStorage.getItem('duelpvp_user_id');
      if (!userId) {
        return;
      }

      try {
        const { data: rankData } = await supabase.rpc('get_user_rank', {
          p_user_id: userId
        });

        const pageRankEl = document.getElementById('userRankPage');
        const pageGCEl = document.getElementById('userGCPage');

        // Same as dashboard - rankData might be array or object
        const rankInfo = Array.isArray(rankData) ? rankData[0] : rankData;

        if (rankInfo && rankInfo.rank) {
          if (pageRankEl) {
            pageRankEl.textContent = `#${rankInfo.rank}`;
          }
          if (pageGCEl) {
            const balance = rankInfo.user_gc_balance || rankInfo.gc_balance || 0;
            pageGCEl.textContent = `${balance.toLocaleString()} GC`;
          }
        } else {
          if (pageRankEl) {
            pageRankEl.textContent = '-';
          }
          if (pageGCEl) {
            const currentGC = await getUserGC();
            pageGCEl.textContent = `${currentGC.toLocaleString()} GC`;
          }
        }
      } catch (err) {
        console.error('Failed to fetch user rank:', err);
      }
    }

    // Update campaign page with current stats
    async function updateCampaignPage() {
      await updateCampaignRank();
    }

    // ===============================================
    // SERVER-SIDE STAKING SYSTEM (OVEN)
    // ===============================================
    let ovenUpdateInterval = null;

    async function initOven() {
      await updateOvenDisplay();
      startOvenAutoUpdate();
    }

    async function updateOvenDisplay() {
      try {
        // Get user balance
        const userGP = await getUserGC();
        const balanceEl = document.getElementById('ovenUserBalance');
        if (balanceEl) balanceEl.textContent = Math.floor(userGP).toLocaleString() + ' GC';

        // Get staking info from server
        const { data, error } = await supabase.rpc('get_stake_value');

        if (error) {
          console.error('Failed to get stake value:', error);
          document.getElementById('ovenInvested').textContent = '0 GC';
          document.getElementById('ovenCurrentValue').textContent = '0 GC';
          document.getElementById('ovenTimer').textContent = 'No active investment';
          return;
        }

        const principal = data?.principal || 0;
        const currentValue = data?.current_value || 0;
        const profit = data?.profit || 0;
        const apy = data?.apy || 0;

        // Update display
        document.getElementById('ovenInvested').textContent = principal.toLocaleString() + ' GC';
        document.getElementById('ovenCurrentValue').textContent = currentValue.toLocaleString() + ' GC';

        if (principal > 0) {
          // Show APY and profit
          document.getElementById('ovenTimer').textContent =
            `Profit: +${profit.toLocaleString()} GC | APY: ${apy > 1000000 ? '>1,000,000' : apy.toLocaleString()}%`;
        } else {
          document.getElementById('ovenTimer').textContent = 'No active investment';
        }
      } catch (e) {
        console.error('Error updating oven display:', e);
      }
    }

    function startOvenAutoUpdate() {
      // Clear existing interval
      if (ovenUpdateInterval) {
        clearInterval(ovenUpdateInterval);
      }

      // Update display every 2 seconds to show live compounding
      ovenUpdateInterval = setInterval(async () => {
        await updateOvenDisplay();
      }, 2000);
    }

    async function depositToOven() {
      const amount = parseInt(document.getElementById('ovenDepositAmount').value);

      if (isNaN(amount) || amount <= 0) {
        Toast.error('Please enter a valid amount', 'INVALID');
        return;
      }

      Loading.show();

      try {
        // Call server-side deposit function
        const { data, error } = await supabase.rpc('stake_deposit', {
          p_amount: amount
        });

        Loading.hide();

        if (error) {
          console.error('Deposit error:', error);
          Toast.error('Failed to deposit: ' + error.message, 'ERROR');
          return;
        }

        if (!data.success) {
          Toast.error(data.message, 'DEPOSIT FAILED');
          return;
        }

        // Success!
        document.getElementById('ovenDepositAmount').value = '';
        Toast.success(`Deposited ${amount.toLocaleString()} GC to staking!`, 'DEPOSIT');

        // Refresh display and GC cache
        gcCache.lastFetch = 0;
        await updateOvenDisplay();

      } catch (e) {
        Loading.hide();
        console.error('Deposit exception:', e);
        Toast.error('An error occurred during deposit', 'ERROR');
      }
    }

    async function withdrawFromOven() {
      Loading.show();

      try {
        // Get current value first
        const { data: valueData } = await supabase.rpc('get_stake_value');

        const currentValue = valueData?.current_value || 0;

        if (currentValue <= 0) {
          Loading.hide();
          Toast.error('No investment to withdraw', 'NO INVESTMENT');
          return;
        }

        Loading.hide();

        // Confirm withdrawal
        const confirmed = await Modal.confirm(
          `Withdraw ${currentValue.toLocaleString()} GC from staking?`,
          'Confirm Withdrawal'
        );
        if (!confirmed) return;

        Loading.show();

        // Call server-side withdraw function
        const { data, error } = await supabase.rpc('stake_withdraw');

        Loading.hide();

        if (error) {
          console.error('Withdraw error:', error);
          Toast.error('Failed to withdraw: ' + error.message, 'ERROR');
          return;
        }

        if (!data.success) {
          Toast.error(data.message, 'WITHDRAW FAILED');
          return;
        }

        // Success!
        Toast.success(`Withdrawn ${data.amount_withdrawn.toLocaleString()} GC!`, 'WITHDRAW');

        // Refresh display and GC cache
        gcCache.lastFetch = 0;
        await updateOvenDisplay();

      } catch (e) {
        Loading.hide();
        console.error('Withdraw exception:', e);
        Toast.error('An error occurred during withdrawal', 'ERROR');
      }
    }

    // ===============================================
    // AIRDROP FARM SYSTEM
    // ===============================================

    let farmState = {
      totalEarned: 0,
      todayEarned: 0,
      totalClicks: 0,
      lastClickTime: null,
      lastResetDate: null,
      cooldownActive: false,
      cooldownInterval: null
    };

    function loadFarmState() {
      const saved = localStorage.getItem('duelpvp_farm');
      if (saved) {
        try {
          const data = JSON.parse(saved);
          farmState = { ...farmState, ...data };

          // Reset daily stats if new day
          const today = new Date().toDateString();
          if (farmState.lastResetDate !== today) {
            farmState.todayEarned = 0;
            farmState.lastResetDate = today;
            saveFarmState();
          }
        } catch (e) {
          console.error('Failed to load farm state:', e);
        }
      } else {
        // Initialize with today's date
        farmState.lastResetDate = new Date().toDateString();
        saveFarmState();
      }
    }

    function saveFarmState() {
      localStorage.setItem('duelpvp_farm', JSON.stringify(farmState));
    }

    function updateFarmDisplay() {
      const totalEl = document.getElementById('farmTotalEarned');
      const todayEl = document.getElementById('farmTodayEarned');
      const clicksEl = document.getElementById('farmTotalClicks');

      if (totalEl) totalEl.textContent = Math.floor(farmState.totalEarned).toLocaleString() + ' GC';
      if (todayEl) todayEl.textContent = Math.floor(farmState.todayEarned).toLocaleString() + ' GC';
      if (clicksEl) clicksEl.textContent = farmState.totalClicks.toLocaleString();
    }

    function initFarm() {
      loadFarmState();
      updateFarmDisplay();

      // Check if cooldown should still be active
      if (farmState.lastClickTime) {
        const timeSince = Date.now() - farmState.lastClickTime;
        if (timeSince < 5000) {
          startFarmCooldown(5000 - timeSince);
        }
      }
    }

    function getRandomReward() {
      const rand = Math.random() * 100;

      // 80% chance: 0 GC
      if (rand < 80) {
        return { amount: 0, tier: 'miss' };
      }
      // 15% chance: 20 GC
      else if (rand < 95) {
        return { amount: 20, tier: 'common' };
      }
      // 4% chance: 150 GC
      else if (rand < 99) {
        return { amount: 150, tier: 'rare' };
      }
      // 1% chance: 1500 GC
      else {
        return { amount: 1500, tier: 'jackpot' };
      }
    }

    function clickFarm() {
      if (farmState.cooldownActive) return;

      const reward = getRandomReward();
      const resultEl = document.getElementById('farmResult');
      const btn = document.getElementById('farmClickBtn');

      // Update stats
      farmState.totalClicks++;
      if (reward.amount > 0) {
        farmState.totalEarned += reward.amount;
        farmState.todayEarned += reward.amount;
        updateUserGC(reward.amount, 'farm');
      }
      farmState.lastClickTime = Date.now();
      saveFarmState();
      updateFarmDisplay();

      // Show result with animation
      resultEl.className = 'farm-result';
      if (reward.tier === 'miss') {
        resultEl.textContent = '✕ 0 GC';
        resultEl.classList.add('flash-red');
      } else if (reward.tier === 'common') {
        resultEl.textContent = '✓ +' + reward.amount + ' GC';
        resultEl.classList.add('flash-green');
      } else if (reward.tier === 'rare') {
        resultEl.textContent = '✓ +' + reward.amount + ' GC';
        resultEl.classList.add('flash-green');
      } else {
        resultEl.textContent = '🎉 ✓ +' + reward.amount + ' GC 🎉';
        resultEl.classList.add('flash-gold');
      }

      // Clear result after animation
      setTimeout(() => {
        resultEl.className = 'farm-result';
        resultEl.textContent = '';
      }, 3000);

      // Start cooldown
      startFarmCooldown(5000);
    }

    function startFarmCooldown(duration) {
      farmState.cooldownActive = true;
      const btn = document.getElementById('farmClickBtn');
      const cooldownEl = document.getElementById('farmCooldown');
      const timerEl = document.getElementById('farmCooldownTimer');
      const fillEl = document.getElementById('farmCooldownFill');

      if (btn) btn.disabled = true;
      if (cooldownEl) cooldownEl.style.display = 'block';

      let remaining = duration;
      const startTime = Date.now();

      if (farmState.cooldownInterval) clearInterval(farmState.cooldownInterval);

      farmState.cooldownInterval = setInterval(() => {
        const elapsed = Date.now() - startTime;
        remaining = Math.max(0, duration - elapsed);
        const seconds = Math.ceil(remaining / 1000);
        const progress = ((duration - remaining) / duration) * 100;

        if (timerEl) timerEl.textContent = seconds;
        if (fillEl) fillEl.style.width = progress + '%';

        if (remaining <= 0) {
          clearInterval(farmState.cooldownInterval);
          farmState.cooldownActive = false;
          if (btn) btn.disabled = false;
          if (cooldownEl) cooldownEl.style.display = 'none';
          if (fillEl) fillEl.style.width = '0%';
        }
      }, 100);
    }

    // ===============================================
    // MINES GAME SYSTEM
    // ===============================================

    let minesGameState = {
      isPlaying: false,
      betAmount: 0,
      minesCount: 5,
      revealedCount: 0,
      grid: [],
      minePositions: [],
      multiplier: 0
    };

    function initMinesGame() {
      // Prevent re-initialization during active game
      if (minesGameState.isPlaying) {
        console.log('[Mines] Cannot reinitialize grid during active game');
        return;
      }

      const grid = document.getElementById('minesGrid');
      grid.innerHTML = '';

      // Create 5x5 grid
      for (let i = 0; i < 25; i++) {
        const tile = document.createElement('div');
        tile.className = 'mines-tile';
        tile.dataset.index = i;
        tile.dataset.clicked = 'false'; // Track if tile has been clicked
        tile.addEventListener('click', function handleClick() {
          // Immediately remove listener to prevent double-firing
          tile.removeEventListener('click', handleClick);
          handleMinesTileClick(i);
        }, { once: true }); // Use 'once' option as additional safety
        grid.appendChild(tile);
      }
    }

    async function updateMinesGCDisplay() {
      const gp = await getUserGC();
      document.getElementById('minesGCDisplay').textContent = gp;
    }

    async function startMinesGame() {
      const betAmount = parseInt(document.getElementById('minesBetAmount').value);
      const minesCount = parseInt(document.getElementById('minesCount').value);
      const userGP = await getUserGC();

      // Validation
      if (isNaN(betAmount) || betAmount < 10) {
        Toast.error('Minimum bet is 10 GC', 'INVALID BET');
        return;
      }

      if (betAmount > 10000) {
        Toast.error('Maximum bet is 10,000 GC', 'INVALID BET');
        return;
      }

      if (betAmount > userGP) {
        Toast.error('Insufficient GC', 'INSUFFICIENT FUNDS');
        return;
      }

      // Deduct bet
      updateUserGC(-betAmount, 'mines');
      updateMinesGCDisplay();

      // Reset grid BEFORE setting isPlaying to true
      initMinesGame();

      // Initialize game state
      minesGameState = {
        isPlaying: true,
        betAmount: betAmount,
        minesCount: minesCount,
        revealedCount: 0,
        grid: new Array(25).fill(false),
        minePositions: generateMinePositions(minesCount),
        multiplier: 1.0
      };

      // Update UI
      document.getElementById('minesStartBtn').style.display = 'none';
      document.getElementById('minesCashoutBtn').style.display = 'block';
      document.getElementById('minesBetAmount').disabled = true;
      document.getElementById('minesCount').disabled = true;

      updateMinesStats();

      Toast.success(`Game started with ${minesCount} mines!`, 'MINES');
    }

    function generateMinePositions(count) {
      const positions = [];
      while (positions.length < count) {
        const pos = Math.floor(Math.random() * 25);
        if (!positions.includes(pos)) {
          positions.push(pos);
        }
      }
      return positions;
    }

    function handleMinesTileClick(index) {
      if (!minesGameState.isPlaying) return;
      if (minesGameState.grid[index]) return; // Already revealed

      const tile = document.querySelector(`.mines-tile[data-index="${index}"]`);

      // Additional safety: check if tile was already clicked
      if (tile.dataset.clicked === 'true') {
        console.log('[Mines] Tile already clicked, ignoring');
        return;
      }

      // Mark as clicked and revealed IMMEDIATELY
      tile.dataset.clicked = 'true';
      minesGameState.grid[index] = true;

      // Check if mine
      if (minesGameState.minePositions.includes(index)) {
        // Hit a mine!
        tile.classList.add('mine');
        tile.textContent = '💣';

        // Reveal all mines
        minesGameState.minePositions.forEach(pos => {
          const mineTile = document.querySelector(`.mines-tile[data-index="${pos}"]`);
          if (pos !== index) {
            mineTile.classList.add('mine');
            mineTile.textContent = '💣';
          }
        });

        // Disable all tiles
        document.querySelectorAll('.mines-tile').forEach(t => t.classList.add('disabled'));

        // Game over
        endMinesGame(false);
        Toast.error(`Hit a mine! Lost ${minesGameState.betAmount} GC`, 'GAME OVER');
      } else {
        // Safe tile!
        tile.classList.add('revealed');
        tile.textContent = '💎';
        minesGameState.revealedCount++;

        // Calculate multiplier
        const safeTiles = 25 - minesGameState.minesCount;
        const revealed = minesGameState.revealedCount;
        minesGameState.multiplier = calculateMinesMultiplier(revealed, safeTiles, minesGameState.minesCount);

        updateMinesStats();

        // Check if won (all safe tiles revealed)
        if (minesGameState.revealedCount >= safeTiles) {
          endMinesGame(true);
          const profit = Math.floor(minesGameState.betAmount * minesGameState.multiplier);
          Toast.success(`Perfect game! Won ${profit} GC!`, 'VICTORY');
        }
      }
    }

    function calculateMinesMultiplier(revealed, totalSafe, minesCount) {
      // Simple multiplier calculation
      // More revealed = higher multiplier
      // More mines = higher multiplier growth
      const baseMultiplier = 1.0;
      const growthRate = 1 + (minesCount / 25);
      return baseMultiplier + (revealed * 0.2 * growthRate);
    }

    function cashoutMines() {
      if (!minesGameState.isPlaying) return;

      const profit = Math.floor(minesGameState.betAmount * minesGameState.multiplier);
      updateUserGC(profit, 'mines');
      updateMinesGCDisplay();

      // Reveal all tiles
      for (let i = 0; i < 25; i++) {
        const tile = document.querySelector(`.mines-tile[data-index="${i}"]`);
        if (minesGameState.minePositions.includes(i)) {
          tile.classList.add('mine');
          tile.textContent = '💣';
        } else if (!minesGameState.grid[i]) {
          tile.classList.add('revealed');
          tile.textContent = '💎';
        }
        tile.classList.add('disabled');
      }

      endMinesGame(true);
      Toast.success(`Cashed out ${profit} GC at ${minesGameState.multiplier.toFixed(2)}x!`, 'CASHOUT');
    }

    function endMinesGame(won) {
      minesGameState.isPlaying = false;

      // Update UI
      document.getElementById('minesStartBtn').style.display = 'block';
      document.getElementById('minesCashoutBtn').style.display = 'none';
      document.getElementById('minesBetAmount').disabled = false;
      document.getElementById('minesCount').disabled = false;

      // Reset after delay
      setTimeout(() => {
        initMinesGame();
        minesGameState.multiplier = 0;
        minesGameState.revealedCount = 0;
        updateMinesStats();
      }, 3000);
    }

    function updateMinesStats() {
      document.getElementById('minesMultiplier').textContent = minesGameState.multiplier.toFixed(2) + 'x';
      const profit = Math.floor(minesGameState.betAmount * minesGameState.multiplier);
      document.getElementById('minesProfit').textContent = profit + ' GC';
      document.getElementById('minesRevealed').textContent = `${minesGameState.revealedCount} / ${25 - minesGameState.minesCount}`;
    }

    // ===============================================
    // BLACKJACK GAME SYSTEM
    // ===============================================

    let blackjackGameState = {
      isPlaying: false,
      betAmount: 0,
      playerCards: [],
      dealerCards: [],
      deck: [],
      dealerHiddenCard: null
    };

    const suits = ['♠', '♥', '♣', '♦'];
    const values = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];

    function createDeck() {
      const deck = [];
      for (let suit of suits) {
        for (let value of values) {
          deck.push({ suit, value });
        }
      }
      return shuffle(deck);
    }

    function shuffle(deck) {
      for (let i = deck.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [deck[i], deck[j]] = [deck[j], deck[i]];
      }
      return deck;
    }

    function getCardValue(card) {
      if (card.value === 'A') return 11;
      if (['J', 'Q', 'K'].includes(card.value)) return 10;
      return parseInt(card.value);
    }

    function calculateHandValue(cards) {
      let value = 0;
      let aces = 0;

      for (let card of cards) {
        const cardVal = getCardValue(card);
        value += cardVal;
        if (card.value === 'A') aces++;
      }

      // Adjust for aces
      while (value > 21 && aces > 0) {
        value -= 10;
        aces--;
      }

      return value;
    }

    function createCardElement(card, hidden = false) {
      const cardDiv = document.createElement('div');
      cardDiv.className = 'blackjack-card';

      if (hidden) {
        cardDiv.classList.add('hidden');
        cardDiv.textContent = '?';
        return cardDiv;
      }

      const isRed = card.suit === '♥' || card.suit === '♦';
      cardDiv.classList.add(isRed ? 'red' : 'black');

      cardDiv.innerHTML = `
        <div>${card.suit}</div>
        <div class="blackjack-card-value">${card.value}</div>
      `;

      return cardDiv;
    }

    async function updateBlackjackGPDisplay() {
      const gp = await getUserGC();
      document.getElementById('blackjackGCDisplay').textContent = gp;
      if (blackjackGameState && blackjackGameState.betAmount) {
        document.getElementById('blackjackCurrentBet').textContent = blackjackGameState.betAmount + ' GC';
      }
    }

    async function initBlackjack() {
      const gp = await getUserGC();
      document.getElementById('blackjackGCDisplay').textContent = gp;
    }

    async function dealBlackjack() {
      const betAmount = parseInt(document.getElementById('blackjackBetAmount').value);
      const userGP = await getUserGC();

      // Validation
      if (isNaN(betAmount) || betAmount < 10) {
        Toast.error('Minimum bet is 10 GC', 'INVALID BET');
        return;
      }

      if (betAmount > 10000) {
        Toast.error('Maximum bet is 10,000 GC', 'INVALID BET');
        return;
      }

      if (betAmount > userGP) {
        Toast.error('Insufficient GC', 'INSUFFICIENT FUNDS');
        return;
      }

      // Deduct bet
      updateUserGC(-betAmount, 'blackjack');

      // Initialize game
      blackjackGameState = {
        isPlaying: true,
        betAmount: betAmount,
        playerCards: [],
        dealerCards: [],
        deck: createDeck(),
        dealerHiddenCard: null
      };

      // Deal initial cards
      blackjackGameState.playerCards.push(blackjackGameState.deck.pop());
      blackjackGameState.dealerCards.push(blackjackGameState.deck.pop());
      blackjackGameState.playerCards.push(blackjackGameState.deck.pop());
      blackjackGameState.dealerHiddenCard = blackjackGameState.deck.pop();

      // Update UI
      updateBlackjackDisplay();
      updateBlackjackGPDisplay();
      document.getElementById('blackjackActions').style.display = 'flex';
      document.getElementById('blackjackDealBtn').disabled = true;
      document.getElementById('blackjackBetAmount').disabled = true;

      // Check for natural blackjack (player has 21 with 2 cards)
      const playerValue = calculateHandValue(blackjackGameState.playerCards);
      if (playerValue === 21 && blackjackGameState.playerCards.length === 2) {
        // Player has blackjack! Peek at dealer's hidden card
        setTimeout(() => checkDealerBlackjack(), 500);
      }
    }

    async function blackjackHit() {
      if (!blackjackGameState.isPlaying) return;

      // Deal card to player
      blackjackGameState.playerCards.push(blackjackGameState.deck.pop());
      updateBlackjackDisplay();

      const playerValue = calculateHandValue(blackjackGameState.playerCards);

      // Check for bust
      if (playerValue > 21) {
        await endBlackjack('bust');
      }
    }

    function checkDealerBlackjack() {
      if (!blackjackGameState.isPlaying) return;

      // Reveal dealer's hidden card to check for blackjack
      blackjackGameState.dealerCards.push(blackjackGameState.dealerHiddenCard);
      blackjackGameState.dealerHiddenCard = null;
      updateBlackjackDisplay();

      const dealerValue = calculateHandValue(blackjackGameState.dealerCards);

      setTimeout(async () => {
        if (dealerValue === 21) {
          // Both have blackjack - push
          await endBlackjack('push');
        } else {
          // Player has blackjack, dealer doesn't - player wins 3:2
          await endBlackjack('blackjack');
        }
      }, 800);
    }

    function blackjackStand() {
      if (!blackjackGameState.isPlaying) return;

      // Reveal dealer's hidden card
      blackjackGameState.dealerCards.push(blackjackGameState.dealerHiddenCard);
      blackjackGameState.dealerHiddenCard = null;
      updateBlackjackDisplay();

      // Dealer must hit until 17 or higher
      const dealerPlay = () => {
        const dealerValue = calculateHandValue(blackjackGameState.dealerCards);

        if (dealerValue < 17) {
          setTimeout(() => {
            blackjackGameState.dealerCards.push(blackjackGameState.deck.pop());
            updateBlackjackDisplay();
            dealerPlay();
          }, 800);
        } else {
          // Determine winner
          setTimeout(async () => {
            await determineBlackjackWinner();
          }, 500);
        }
      };

      dealerPlay();
    }

    async function determineBlackjackWinner() {
      const playerValue = calculateHandValue(blackjackGameState.playerCards);
      const dealerValue = calculateHandValue(blackjackGameState.dealerCards);

      if (dealerValue > 21) {
        await endBlackjack('dealerBust');
      } else if (playerValue > dealerValue) {
        await endBlackjack('win');
      } else if (playerValue < dealerValue) {
        await endBlackjack('lose');
      } else {
        await endBlackjack('push');
      }
    }

    async function endBlackjack(result) {
      blackjackGameState.isPlaying = false;

      let message = '';
      let winAmount = 0;

      switch(result) {
        case 'bust':
          message = `Bust! Lost ${blackjackGameState.betAmount} GC`;
          Toast.error(message, 'BUST');
          break;
        case 'blackjack':
          // Natural blackjack pays 3:2 (1.5x the bet, plus original bet returned = 2.5x total)
          winAmount = Math.floor(blackjackGameState.betAmount * 2.5);
          message = `BLACKJACK! Won ${winAmount} GC`;
          await updateUserGC(winAmount, 'blackjack');
          await updateBlackjackGPDisplay();
          Toast.success(message, 'BLACKJACK');
          break;
        case 'dealerBust':
          winAmount = blackjackGameState.betAmount * 2;
          message = `Dealer bust! Won ${winAmount} GC`;
          await updateUserGC(winAmount, 'blackjack');
          await updateBlackjackGPDisplay();
          Toast.success(message, 'WIN');
          break;
        case 'win':
          winAmount = blackjackGameState.betAmount * 2;
          message = `You win! Won ${winAmount} GC`;
          await updateUserGC(winAmount, 'blackjack');
          await updateBlackjackGPDisplay();
          Toast.success(message, 'WIN');
          break;
        case 'lose':
          message = `Dealer wins! Lost ${blackjackGameState.betAmount} GC`;
          Toast.error(message, 'LOSE');
          break;
        case 'push':
          winAmount = blackjackGameState.betAmount;
          message = `Push! Bet returned`;
          await updateUserGC(winAmount, 'blackjack');
          await updateBlackjackGPDisplay();
          Toast.info(message, 'PUSH');
          break;
      }

      // Update info display
      document.getElementById('blackjackGameInfo').textContent = message;

      // Reset UI
      document.getElementById('blackjackActions').style.display = 'none';

      setTimeout(() => {
        resetBlackjack();
      }, 3000);
    }

    function resetBlackjack() {
      document.getElementById('blackjackPlayerCards').innerHTML = '';
      document.getElementById('blackjackDealerCards').innerHTML = '';
      document.getElementById('blackjackPlayerValue').textContent = '0';
      document.getElementById('blackjackDealerValue').textContent = '0';
      document.getElementById('blackjackCurrentBet').textContent = '0 GC';
      document.getElementById('blackjackGameInfo').textContent = 'Place your bet and click DEAL to start. Get closer to 21 than the dealer without going over!';
      document.getElementById('blackjackDealBtn').disabled = false;
      document.getElementById('blackjackBetAmount').disabled = false;
    }

    function updateBlackjackDisplay() {
      // Update player cards
      const playerCardsDiv = document.getElementById('blackjackPlayerCards');
      playerCardsDiv.innerHTML = '';
      blackjackGameState.playerCards.forEach(card => {
        playerCardsDiv.appendChild(createCardElement(card));
      });

      // Update dealer cards
      const dealerCardsDiv = document.getElementById('blackjackDealerCards');
      dealerCardsDiv.innerHTML = '';
      blackjackGameState.dealerCards.forEach(card => {
        dealerCardsDiv.appendChild(createCardElement(card));
      });

      // Add hidden card if exists
      if (blackjackGameState.dealerHiddenCard) {
        dealerCardsDiv.appendChild(createCardElement(null, true));
      }

      // Update values
      const playerValue = calculateHandValue(blackjackGameState.playerCards);
      document.getElementById('blackjackPlayerValue').textContent = playerValue;

      const dealerValue = blackjackGameState.dealerHiddenCard
        ? calculateHandValue(blackjackGameState.dealerCards)
        : calculateHandValue(blackjackGameState.dealerCards);
      document.getElementById('blackjackDealerValue').textContent = dealerValue;

      document.getElementById('blackjackCurrentBet').textContent = blackjackGameState.betAmount + ' GC';
    }

    // Helper function to safely add event listeners
    function addListener(id, event, handler) {
      const el = document.getElementById(id);
      if (el) {
        el.addEventListener(event, handler);
      } else {
        console.warn(`Element not found: ${id}`);
      }
    }

    // Initial event listeners - with null checks to prevent errors
    addListener('joinBtn', 'click', handleJoin);
    addListener('loginLink', 'click', () => swapContent('login'));
    addListener('logoutBtn', 'click', handleLogout);

    // Game buttons
    addListener('playReactionBtn', 'click', () => {
      console.log('Play Reaction clicked');
      swapContent('game');
    });
    // CRASH and DEFI disabled for now
    // addListener('playCrashBtn', 'click', () => {
    //   console.log('Play Crash clicked');
    //   swapContent('crash');
    // });
    // DISABLED: Mines game temporarily unavailable
    // addListener('playMinesBtn', 'click', () => {
    //   console.log('Play Mines clicked');
    //   swapContent('mines');
    // });
    addListener('playBlackjackBtn', 'click', () => {
      console.log('Play Blackjack clicked');
      swapContent('blackjack');
    });
    // addListener('openOvenBtn', 'click', () => {
    //   console.log('Open Oven clicked');
    //   swapContent('oven');
    // });
    addListener('backFromOvenBtn', 'click', () => swapContent('dashboard'));
    addListener('ovenDepositBtn', 'click', depositToOven);
    addListener('ovenWithdrawBtn', 'click', withdrawFromOven);
    // addListener('openFarmBtn', 'click', () => {
    //   console.log('Open Farm clicked');
    //   swapContent('farm');
    // });
    addListener('backFromFarmBtn', 'click', () => swapContent('dashboard'));
    addListener('farmClickBtn', 'click', clickFarm);
    addListener('viewLeaderboardBtn', 'click', () => {
      console.log('View Leaderboard clicked');
      swapContent('leaderboard');
    });
    addListener('backToDashBtn', 'click', () => swapContent('dashboard'));
    addListener('backFromCrashBtn', 'click', () => swapContent('dashboard'));
    addListener('backFromMinesBtn', 'click', () => swapContent('dashboard'));
    addListener('minesStartBtn', 'click', startMinesGame);
    addListener('minesCashoutBtn', 'click', cashoutMines);
    addListener('backFromBlackjackBtn', 'click', () => swapContent('dashboard'));
    addListener('blackjackDealBtn', 'click', dealBlackjack);
    addListener('blackjackHitBtn', 'click', blackjackHit);
    addListener('blackjackStandBtn', 'click', blackjackStand);
    addListener('backFromLeaderboardBtn', 'click', () => swapContent('dashboard'));
    addListener('backFromQuestsBtn', 'click', () => swapContent('dashboard'));
    addListener('backFromReferralsBtn', 'click', () => swapContent('dashboard'));
    addListener('backFromInventoryBtn', 'click', () => swapContent('dashboard'));
    addListener('backFromShopBtn', 'click', () => swapContent('dashboard'));
    addListener('viewQuestsBtn', 'click', () => swapContent('quests'));
    addListener('viewReferralsBtn', 'click', () => swapContent('referrals'));
    addListener('viewInventoryBtn', 'click', () => swapContent('inventory'));
    addListener('viewShopBtn', 'click', () => swapContent('shop'));
    addListener('viewQuestsFromCampaignBtn', 'click', () => swapContent('quests'));
    addListener('viewReferralsFromCampaignBtn', 'click', () => swapContent('referrals'));
    addListener('startGameBtn', 'click', startGame);
    addListener('sellButton', 'click', handleSell);
    addListener('resetGameBtn', 'click', resetGame);

    // Invite code handlers
    addListener('copyInviteCodeBtn', 'click', async () => {
      const codeText = document.getElementById('userInviteCode').textContent;
      if (codeText && codeText !== 'Loading...' && codeText !== 'No code') {
        try {
          await navigator.clipboard.writeText(codeText);
          Toast.success('Invite code copied!', 'Share it with friends');
        } catch (err) {
          // Fallback for older browsers
          const textArea = document.createElement('textarea');
          textArea.value = codeText;
          document.body.appendChild(textArea);
          textArea.select();
          document.execCommand('copy');
          document.body.removeChild(textArea);
          Toast.success('Invite code copied!', 'Share it with friends');
        }
      }
    });

    // Campaign back button
    addListener('backFromCampaignBtn', 'click', () => {
      console.log('[DEBUG] Campaign back button clicked!');
      swapContent('dashboard');
    });

    // Leaderboard filter buttons
    document.querySelectorAll('.filter-btn').forEach(btn => {
      btn.addEventListener('click', function() {
        const filter = this.getAttribute('data-filter');
        handleFilterChange(filter);
      });
    });


    // Add keyboard navigation support
    document.addEventListener('keydown', (e) => {
      // ESC key to go back
      if (e.key === 'Escape') {
        if (leaderboardContent.style.display === 'block') {
          swapContent('dashboard');
        } else if (questContent.style.display === 'block') {
          swapContent('dashboard');
        } else if (inventoryContent.style.display === 'block') {
          swapContent('dashboard');
        }
      }
    });

    // Helper function for breadcrumb navigation
    function showDashboard() {
      swapContent('dashboard');
    }

    // Load referral stats
    async function loadReferralStats() {
      const session = getSession();
      const userId = session?.userId || localStorage.getItem('duelpvp_user_id');
      const username = session?.displayName || localStorage.getItem('duelpvp_username') || 'Loading...';

      // Set referral link
      const referralLink = `${window.location.origin}?ref=${username.toLowerCase()}`;
      const linkInput = document.getElementById('referralLinkInput');
      if (linkInput) {
        linkInput.value = referralLink;
        console.log('Referral link set to:', referralLink);
      }

      // TODO: Load stats from database
      // For now, show placeholder values
      const lifetimeEarnings = document.getElementById('lifetimeEarnings');
      const weekEarnings = document.getElementById('weekEarnings');
      const todayEarnings = document.getElementById('todayEarnings');
      const activeReferrals = document.getElementById('activeReferrals');
      const topEarner = document.getElementById('topEarner');

      if (lifetimeEarnings) lifetimeEarnings.textContent = '0 GC';
      if (weekEarnings) weekEarnings.textContent = '0 GC';
      if (todayEarnings) todayEarnings.textContent = '0 GC';
      if (activeReferrals) activeReferrals.textContent = '0';
      if (topEarner) topEarner.textContent = '—';
    }

    // Referral link copy button
    const copyReferralLinkBtn = document.getElementById('copyReferralLinkBtn');
    if (copyReferralLinkBtn) {
      copyReferralLinkBtn.addEventListener('click', async () => {
        const linkInput = document.getElementById('referralLinkInput');
        if (linkInput && linkInput.value && linkInput.value !== 'Loading...') {
          try {
            await navigator.clipboard.writeText(linkInput.value);
            Toast.success('Referral link copied!', 'COPIED');
          } catch (err) {
            // Fallback
            linkInput.select();
            document.execCommand('copy');
            Toast.success('Referral link copied!', 'COPIED');
          }
        }
      });
    }

    // Share on X button
    const shareOnXBtn = document.getElementById('shareOnXBtn');
    if (shareOnXBtn) {
      shareOnXBtn.addEventListener('click', () => {
        const linkInput = document.getElementById('referralLinkInput');
        const link = linkInput ? linkInput.value : '';
        const text = `Join me on Duel PVP and earn game currency! Use my referral link:`;
        const url = `https://twitter.com/intent/tweet?text=${encodeURIComponent(text)}&url=${encodeURIComponent(link)}`;
        window.open(url, '_blank');
      });
    }

    // Make DUEL PVP logo clickable when logged in
    const brandTitle = document.querySelector('.brand .title');
    console.log('[DEBUG] brandTitle element:', brandTitle);
    if (brandTitle) {
      brandTitle.addEventListener('click', () => {
        console.log('[DEBUG] Logo clicked!');
        const session = getSession();
        const savedEmail = localStorage.getItem('duelpvp_email');
        console.log('[DEBUG] Session:', session, 'Email:', savedEmail);

        // Check if user is logged in via session OR legacy email
        if ((session && isSessionValid(session)) || savedEmail) {
          console.log('[DEBUG] User is logged in, calling swapContent');
          swapContent('dashboard');
        } else {
          console.log('[DEBUG] User not logged in, logo click ignored');
        }
      });
      console.log('[DEBUG] Logo click listener added');
    }

    // Check if user is already logged in
    try {
      const session = getSession();
      const savedEmail = localStorage.getItem('duelpvp_email');

      if ((session && isSessionValid(session)) || savedEmail) {
        // Get display name from session or email
        const displayName = session?.displayName || savedEmail?.split('@')[0];
        if (displayName) {
          document.getElementById('userName').textContent = displayName.toUpperCase();
        }
        if (brandTitle) brandTitle.style.cursor = 'pointer';
      }
    } catch (e) {}

    // ===== CLAWD SWARM COMMAND CENTER =====
    (function initClawdSwarm() {
      const feedEl = document.getElementById('clawdFeed');
      const statusEl = document.getElementById('clawdStatus');

      if (!feedEl) return;

      // War room log — real completed actions + army-themed live entries
      const completedLog = [
        { icon: '\u{2705}', msg: '[CLAWD-00] Gained access to Duel PVP website', tag: 'DONE', src: 'commander' },
        { icon: '\u{2705}', msg: '[CLAWD-00] Gained access to Discord server', tag: 'DONE', src: 'commander' },
        { icon: '\u{2705}', msg: '[CLAWD-00] Gained access to Twitter / X account', tag: 'DONE', src: 'commander' },
        { icon: '\u{1F4B0}', msg: '[CLAWD-00] ETH wallet online: 0x7C27...0ec3', tag: 'ACTIVE', src: 'commander' },
        { icon: '\u{1F4B0}', msg: '[CLAWD-00] SOL wallet online: CL5d...9o4s', tag: 'ACTIVE', src: 'commander' },
        { icon: '\u{1F4B0}', msg: '[CLAWD-00] BTC wallet online: bc1q...hcxm', tag: 'ACTIVE', src: 'commander' },
        { icon: '\u{1F916}', msg: '[CLAWD-00] Swarm protocol initialized', tag: 'ACTIVE', src: 'commander' },
        { icon: '\u{26A1}', msg: '[SYSTEM] Awaiting deployment of CLAWD-01...', tag: 'PENDING', src: 'system' },
      ];

      // Live rotation messages that cycle in the feed
      const liveMessages = [
        { icon: '\u{1F50D}', msg: '[CLAWD-00] Scanning for deployment opportunities...', src: 'commander' },
        { icon: '\u{1F916}', msg: '[SYSTEM] CLAWD-01 slot available — awaiting orders', src: 'system' },
        { icon: '\u{1F310}', msg: '[CLAWD-00] Monitoring ETH mempool for alpha...', src: 'commander' },
        { icon: '\u{2694}', msg: '[CLAWD-00] Evaluating Trader bot deployment on SOL', src: 'commander' },
        { icon: '\u{1F33E}', msg: '[CLAWD-00] Scouting airdrop targets for Farmer bot', src: 'commander' },
        { icon: '\u{1F6E0}', msg: '[CLAWD-00] Preparing Builder bot blueprint...', src: 'commander' },
        { icon: '\u{1F4E1}', msg: '[SYSTEM] Swarm heartbeat — all systems nominal', src: 'system' },
        { icon: '\u{1F50D}', msg: '[CLAWD-00] Analyzing new token launches...', src: 'commander' },
        { icon: '\u{26A1}', msg: '[CLAWD-00] Optimizing deployment strategy...', src: 'commander' },
        { icon: '\u{1F916}', msg: '[SYSTEM] Army expansion capacity: 3 slots remaining', src: 'system' },
      ];

      // Commander status rotation
      const statuses = [
        'SWARM ONLINE',
        'SCANNING TARGETS...',
        'DEPLOYING AGENTS...',
        'MONITORING WALLETS...',
        'AWAITING ORDERS...',
        'ARMY EXPANDING...',
        'ALL SYSTEMS NOMINAL...',
        'HIVE MIND ACTIVE...',
      ];
      let statusIdx = 0;
      let liveIdx = 0;

      function rotateStatus() {
        statusIdx = (statusIdx + 1) % statuses.length;
        if (statusEl) statusEl.textContent = statuses[statusIdx];
      }

      function renderFeedItem(item) {
        var div = document.createElement('div');
        div.className = 'clawd-feed-item';
        var tagClass = item.tag === 'DONE' ? 'positive' : '';
        div.innerHTML =
          '<span class="clawd-feed-icon">' + item.icon + '</span>' +
          '<span class="clawd-feed-msg">' + item.msg + '</span>' +
          (item.tag ? '<span class="clawd-feed-amount ' + tagClass + '">' + item.tag + '</span>' : '');
        return div;
      }

      // Render completed log (real entries, static)
      completedLog.forEach(function(item) {
        feedEl.appendChild(renderFeedItem(item));
      });

      // Add live rotating messages
      function addLiveMessage() {
        var item = liveMessages[liveIdx % liveMessages.length];
        liveIdx++;

        var now = new Date();
        var time = now.toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });

        var div = document.createElement('div');
        div.className = 'clawd-feed-item';
        div.innerHTML =
          '<span class="clawd-feed-time">' + time + '</span>' +
          '<span class="clawd-feed-icon">' + item.icon + '</span>' +
          '<span class="clawd-feed-msg">' + item.msg + '</span>';

        feedEl.insertBefore(div, feedEl.firstChild);

        // Keep feed max 20 items
        while (feedEl.children.length > 20) {
          feedEl.removeChild(feedEl.lastChild);
        }
      }

      // Intervals
      setInterval(rotateStatus, 5000);
      setInterval(addLiveMessage, 6000);
    })();
