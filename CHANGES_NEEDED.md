**SUMMARY OF CHANGES NEEDED:**

## 1. Daily Login Quest Fix
- Add "Claim Daily Reward" button in quests section
- Button calls `claim_daily_login()` RPC function
- Shows countdown until next day

## 2. Registration Flow Change
Current: Code required → Wallet connect → Name → Register
New: Wallet connect → Name + Optional code → Register

Files to modify:
- script.js (remove code gate, add referral field to naming page, add daily login UI)
- DAILY_LOGIN_AND_REFERRAL_FIXES.sql (run in Supabase first)

Do you want me to:
A) Make these changes now
B) Just tell you what SQL to run first

Which do you prefer?
