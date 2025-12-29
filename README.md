# Duel PVP - Solana Gaming Platform

A fully on-chain MMO gaming experience built on Solana, combining classic MMO progression with idle game mechanics.

## Features

- **Solana Integration**: Lightning-fast blockchain transactions using Solana web3.js
- **Single Page Application**: All content stays in the DOM with smooth transitions
- **Continuous Animations**:
  - Lava glow effect (6s loop)
  - Slogan fade animation (6s loop)
  - Blinking cursor effect (1s loop)
  - All animations run continuously without interruption
- **Gaming Features**:
  - Real-time PVP battles
  - Idle progression mechanics
  - On-chain game state and transactions
  - Transparent, verifiable gameplay

## Technical Details

- Built on Solana blockchain for fast, low-cost transactions
- Pure HTML/CSS/JavaScript (no frameworks)
- Solana web3.js for wallet integration
- All animations use CSS keyframes for smooth performance
- Content swapping without page reloads
- Responsive design with mobile support
- Pixel-perfect RuneScape-style UI

## File Structure

```
duelpvp-site/
├── index.html       # Main single-page application
├── vercel.json      # Vercel configuration
├── assets/
│   ├── bg-wildy.png # Background image
│   └── logo-pvp.png # Logo (unused in current version)
└── README.md        # This file
```

## Deployment

1. Push to GitHub repository
2. Connect to Vercel
3. Deploy automatically

## Animation Timings

- **Lava Glow**: 6 second loop with brightness variations
- **Slogan Pulse**: 6 second fade in/out cycle
- **Cursor Blink**: 1 second on/off cycle

All animations are synchronized to create a cohesive visual experience.
