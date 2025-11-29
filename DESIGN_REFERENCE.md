# Design Reference for Warrior Campaign

This file contains CSS design patterns extracted from the original code. Use these patterns for consistent styling when building the new campaign from scratch.

## Color Variables
```css
--gold: #FFD64D
--gold-hi: #FFF3A3
--bg: #0b0f12
--success: #4CAF50
--danger: #F44336
```

## Button Styles

### Primary Button (Gold)
```css
.btn-submit, .btn-primary {
  padding: 12px 24px;
  background: var(--gold);
  border: 2px solid var(--gold);
  border-radius: 8px;
  color: #000;
  font-family: 'Press Start 2P', monospace;
  font-size: 11px;
  transition: all 0.2s cubic-bezier(0.34, 1.56, 0.64, 1);
  box-shadow: 0 1px 2px rgba(0,0,0,.4), 0 4px 8px rgba(0,0,0,.2);
}
.btn-primary:hover {
  background: var(--gold-hi);
  transform: translateY(-2px);
  box-shadow: 0 2px 4px rgba(0,0,0,.4), 0 6px 16px rgba(255,214,77,.4);
}
```

### Invest Button (Green)
```css
.btn-invest {
  background: rgba(76,175,80,.2);
  border-color: #4CAF50;
  color: #4CAF50;
}
.btn-invest:hover:not(:disabled) {
  background: rgba(76,175,80,.35);
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(76,175,80,.4);
}
```

### Gamble Button (Red)
```css
.btn-gamble {
  background: rgba(244,67,54,.2);
  border-color: #F44336;
  color: #F44336;
}
.btn-gamble:hover:not(:disabled) {
  background: rgba(244,67,54,.35);
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(244,67,54,.4);
}
```

### Back Button
```css
.back-btn {
  padding: 8px 12px;
  background: rgba(255,214,77,.1);
  border: 1px solid var(--gold);
  color: var(--gold);
  font-family: 'Press Start 2P', monospace;
  font-size: 10px;
  cursor: pointer;
  border-radius: 4px;
  transition: all 0.2s;
}
.back-btn:hover {
  background: rgba(255,214,77,.2);
}
```

## Card Styles

### Base Card
```css
.stat-card, .dashboard-card {
  background: rgba(255,214,77,.05);
  border: 1px solid rgba(255,214,77,.2);
  border-radius: 8px;
  padding: 16px;
  transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}
.stat-card:hover {
  transform: translateY(-3px) scale(1.02);
  border-color: rgba(255,214,77,0.5);
  background: rgba(255,214,77,.08);
  box-shadow: 0 8px 24px rgba(255,214,77,0.15);
}
```

### Themed Cards (Invest/Gamble)
```css
.campaign-card.invest {
  border: 2px solid rgba(76,175,80,.4);
  background: rgba(16,24,16,.25);
}
.campaign-card.invest:hover {
  border-color: rgba(76,175,80,.7);
  box-shadow: 0 8px 28px rgba(76,175,80,.2);
}

.campaign-card.gamble {
  border: 2px solid rgba(244,67,54,.4);
  background: rgba(24,16,16,.25);
}
.campaign-card.gamble:hover {
  border-color: rgba(244,67,54,.7);
  box-shadow: 0 8px 28px rgba(244,67,54,.2);
}
```

## Container Styles

### Main Container
```css
.page-container {
  position: fixed;
  inset: 0;
  display: grid;
  place-items: center center;
  padding: 20px;
  overflow-y: auto;
  z-index: 4;
}
```

### Panel/Content Container
```css
.campaign-container, .dashboard-content {
  width: min(720px, 92vw);
  background: rgba(12,16,20,.10);
  border: 2px solid rgba(255,214,77,.3);
  border-radius: 12px;
  padding: 24px;
  backdrop-filter: blur(8px);
}
```

### Game Container
```css
.game-container {
  width: min(900px, 92vw);
  background: rgba(12,16,20,.92);
  border: 2px solid rgba(255,214,77,.3);
  border-radius: 12px;
  padding: 24px;
  backdrop-filter: blur(8px);
}
```

## Typography

### Titles
```css
.campaign-title, .card-title {
  font-family: 'Press Start 2P', monospace;
  font-size: 14px;
  color: #FFD700;
  text-shadow: 0 2px 4px rgba(0,0,0,0.4);
}
```

### Stats
```css
.stat-label {
  font-family: 'Press Start 2P', monospace;
  font-size: 10px;
  color: #a0a8b0;
}
.stat-value {
  font-family: 'Press Start 2P', monospace;
  font-size: 18px;
  color: var(--gold);
}
```

## Input Fields
```css
.input-field {
  padding: 12px 14px;
  background: rgba(0,0,0,.4);
  border: 1px solid rgba(255,214,77,.2);
  border-radius: 8px;
  color: #e6ecf1;
  font-family: 'Press Start 2P', monospace;
  font-size: 11px;
  transition: all 0.2s;
}
.input-field:focus {
  outline: none;
  border-color: var(--gold);
  background: rgba(0,0,0,.6);
  box-shadow: 0 0 0 2px rgba(255,214,77,.1);
}
```

## Progress Bars
```css
.campaign-progress-bar {
  width: 100%;
  height: 16px;
  background: rgba(0,0,0,0.4);
  border-radius: 8px;
  overflow: hidden;
}
.campaign-progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #FFD700, #FFA500);
  border-radius: 8px;
  transition: width 0.5s ease;
  box-shadow: 0 0 15px rgba(255,215,0,0.6);
}
```

## Animations

### Fade In
```css
@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(20px) scale(0.96);
    filter: blur(4px);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
    filter: blur(0);
  }
}
.fade-in {
  animation: fadeIn 0.4s cubic-bezier(0.16, 1, 0.3, 1);
}
```

### Flash Animations (for game results)
```css
@keyframes flashGreen {
  0% { transform: scale(1) rotate(0deg); opacity: 0; }
  20% { transform: scale(1.3) rotate(-5deg); opacity: 1; }
  40% { transform: scale(1.3) rotate(5deg); opacity: 1; }
  100% { transform: scale(1) rotate(0deg); opacity: 1; }
}

@keyframes flashRed {
  0% { transform: scale(1); opacity: 0; }
  20% { transform: scale(1.5); opacity: 1; }
  100% { transform: scale(1); opacity: 1; }
}

@keyframes flashGold {
  0% { transform: scale(1) rotate(0deg); opacity: 0; filter: brightness(1); }
  15% { transform: scale(1.5) rotate(-10deg); opacity: 1; filter: brightness(1.5); }
  30% { transform: scale(1.5) rotate(10deg); opacity: 1; filter: brightness(2); }
  100% { transform: scale(1) rotate(0deg); opacity: 1; filter: brightness(1); }
}
```

## Grid Layouts

### Dashboard Cards Row
```css
.dashboard-cards-row, .campaign-cards-row {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 20px;
  margin-bottom: 20px;
}

@media(max-width: 600px) {
  .campaign-cards-row {
    grid-template-columns: 1fr;
  }
}
```

### Stats Grid
```css
.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 16px;
}
```

## Game-Specific Patterns

### Grid-based Game (Mines)
```css
.mines-grid {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 8px;
  max-width: 400px;
  margin: 0 auto;
}
.mines-tile {
  aspect-ratio: 1;
  background: rgba(255,214,77,.1);
  border: 2px solid rgba(255,214,77,.3);
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
}
.mines-tile:hover:not(.revealed) {
  background: rgba(255,214,77,.2);
  transform: scale(1.05);
}
```

### Card Game (Blackjack)
```css
.blackjack-card {
  width: 60px;
  height: 84px;
  background: #fff;
  border: 2px solid #333;
  border-radius: 8px;
  font-family: 'Press Start 2P', monospace;
  font-size: 18px;
  box-shadow: 0 4px 8px rgba(0,0,0,.3);
  animation: cardDeal 0.3s ease-out;
}
@keyframes cardDeal {
  from {
    opacity: 0;
    transform: translateY(-20px) scale(0.8);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}
```

## Layout Pattern for Game Pages

### Two-Column Layout
```css
.game-layout {
  display: grid;
  grid-template-columns: 280px 1fr;
  gap: 24px;
}
.game-sidebar {
  /* Left column for instructions/stats */
}
.game-main {
  /* Right column for game area */
}

@media(max-width: 768px) {
  .game-layout {
    grid-template-columns: 1fr;
  }
}
```

## Header Pattern
```css
.campaign-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  padding-bottom: 12px;
  border-bottom: 1px solid rgba(255,214,77,.2);
}
```

## Notes
- Always use `'Press Start 2P', monospace` for game titles, labels, and stats
- Use `Inter, system-ui, Arial` for body text and descriptions
- Maintain consistent spacing: 8px, 12px, 16px, 20px, 24px
- Use cubic-bezier(0.16, 1, 0.3, 1) for smooth transitions
- Color coding: Green for DeFi/Investment, Red for Games/Gambling, Gold for rewards
