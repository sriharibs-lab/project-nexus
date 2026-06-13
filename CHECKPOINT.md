# Nexus Build — Cycle Checkpoint
**Date:** 2026-06-13   **Status:** ✅ Clean

## What was built

The Nexus prototype now works on a real iPhone. When you open it in Safari on your phone, the app fills the full screen edge-to-edge — no browser chrome visible, status bar and home indicator spacing handled correctly for Dynamic Island and Home Button devices alike. On a desktop browser at normal width, it still shows the centered iPhone mockup on the warm canvas, exactly as before. The prototype now behaves like a real app on any device you hand it to.

## ✅ Verify it worked

- [ ] **Mobile Safari (iPhone)** — open the prototype URL on an iPhone; the app should fill the full screen with no horizontal scroll, status bar area at top, and bottom tab bar above the home indicator
- [ ] **Desktop browser (1280px)** — the centered 390×844 iPhone mockup should appear on the warm canvas, unchanged from before
- [ ] **DevTools emulation** — in Chrome, toggle device emulation to 390px width; the app should switch to full-screen mode with no frame chrome; toggle back to 1280px and the phone mockup returns

## 📋 Decisions made this cycle (no action needed)

| What was decided | Options considered | Why |
|---|---|---|
| Runtime JS hook (useIsNarrow) for mobile/desktop switch | Pure CSS media queries, Tailwind responsive classes | All screens use inline React styles, so only a JS hook can switch the component tree structure — not just styling |
| 640px as the breakpoint | 390px, 768px, 480px | Cleanly splits phone-width browsers from desktop; 390px target still fills the screen at any width below 640px |
| 100dvh for mobile frame height | 100vh, minHeight | dvh accounts for the mobile browser address bar collapsing; 100vh does not; minHeight breaks height: 100% on child screens |
| SSR defaults to desktop layout | Default to mobile | Desktop is where prototype reviews happen — defaulting to desktop avoids layout shift on every page load for reviewers |

## 🔜 Next cycle will work on

Retry 1A-013 — fix the many-to-many items↔collections join table (Alembic revision conflict + enum fixes). Once merged, the next tasks are iOS SwiftUI architecture scaffold (1B-001b) and the API client layer (1B-004), which are the first steps toward a working iPhone app.

## ⏳ Waiting on you (blocked tasks)

| Task | What you need to do | What it unlocks |
|---|---|---|
| S3/R2 storage (1A-008) | Create an R2 or S3 bucket and paste credentials into `api/.env` | Stores full article text in cloud instead of PostgreSQL TEXT — needed before production launch, not before TestFlight |
