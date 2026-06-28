# Nexus Build — Cycle Checkpoint
**Date:** 2026-06-28   **Status:** ⚠️ Review recommended

## What was built

Nexus now has a real login screen — users can sign in with Apple or receive a magic link to their email and enter a 6-digit code to get in. The app no longer routes through a placeholder stub at launch. On top of that, tapping anywhere outside the chat input now properly dismisses the keyboard (both by tapping blank space and by dragging the chat thread upward), and the "trending" icon on the research screen now uses the correct chart-line symbol instead of one that looked like "open in new tab".

## ✅ Verify it worked

- [ ] **Auth screen** — Open the app on a physical iPhone. You should see "Sign in with Apple" as the primary button and a "Continue with email" secondary option — no longer the old stub. Tap "Continue with email", enter your email, and confirm an OTP entry screen appears.
- [ ] **Keyboard dismiss** — Open any collection, tap the chat input to raise the keyboard, then tap blank space in the chat area — keyboard should slide away. Also try dragging the chat thread upward while the keyboard is up — it should follow your finger.
- [ ] **Trending icon** — Tap "Research a topic" from the home screen. The trending topic chips should show a rising chart-line icon (not an arrow pointing up-right).
- [ ] **Chat SSE fix (blocked)** — Send a message in the chat and immediately try to send a second one. This is still broken — the fix was written but not committed. Next cycle should resolve it.

## 📋 Decisions made this cycle (no action needed)

| What was decided | Options considered | Why |
|---|---|---|
| Auth proxied through our backend — Supabase keys never ship in the iOS binary | Ship Supabase SDK directly on device | SPEC §10: credentials must stay server-side |
| OTP verify + user provisioning in a single API call | Two separate calls (verify then provision) | Fewer round-trips, faster login, simpler iOS code |
| OTP auto-submits when 6 digits are entered | Always require a tap on "Verify" button | Removes an unnecessary step; matches iMessage, banking apps |
| AuthManager now stores both access token + refresh token | Store only access token | SPEC §10 requires short-lived tokens with rotation — storing only the access token logs users out after 15 minutes |
| Keyboard dismiss uses SwiftUI simultaneousGesture, not onTapGesture | onTapGesture (broken — steals child taps), UIKit resignFirstResponder broadcast | simultaneousGesture fires alongside child button taps instead of blocking them |
| Keyboard follows scroll gesture interactively (.interactively mode) | Snap-dismiss on scroll start | Matches iPhone Messages and Mail behavior |
| Trending icon uses SF Symbol, not custom Canvas drawing | Keep the hand-drawn zigzag path | SF Symbols render at all sizes/weights automatically and need zero maintenance |

## 🚨 Decisions that need your input

**Apple Sign-In nonce not forwarded to Supabase.** When the user signs in with Apple, iOS generates a security nonce but the app currently discards it before sending the identity token to the backend. This weakens replay-protection (someone who intercepts an identity token could theoretically replay it). It won't crash anything or block TestFlight, but it should be fixed before public launch. No action needed from you now — flagging it so you know.

**Apple "Hide My Email" users stored with blank email.** If a user chooses to hide their email from Apple, the backend currently stores an empty string in the database instead of rejecting the sign-in with a clear error. Again, not a crash, not a launch blocker — but worth fixing before real users hit it.

**Research streaming is buffer-then-yield, not incremental.** The AI research feature currently waits for the full Claude response before showing any sources (up to 10–15 seconds). Incremental streaming was considered but deferred — the shimmer UI already handles the wait and adding real-time parsing before TestFlight adds fragility. This decision should be revisited if the first device test shows the wait is painful.

## 🔜 Next cycle will work on

The SSE chat fix (1F-002) needs one more pass — a one-line string change in APIClient.swift plus committing the test file. After that closes, the remaining 1F enhancements (avatar button, rotating FRE topics, live trending chips, URL paste sheet) bring the first-run experience to a level ready for a real device test session.

## ⏳ Waiting on you (blocked tasks)

| Task | What you need to do | What it unlocks |
|---|---|---|
| S3/R2 bucket for full-text storage (1A-008) | Create an R2 or S3 bucket and paste the credentials into `api/.env` | Full article text stored durably; reader works offline for all content types |
| Daily Briefing push notifications (1C-011) | Add your APNs key (from Apple Developer portal) to `api/.env` | Daily briefing cards delivered to your iPhone via push notification |
