# Nexus Build — Cycle Checkpoint
**Date:** 2026-06-20   **Status:** ⚠️ Review recommended

## What was built
Nexus now has a complete App Store submission package. The app icon is a real Echo mark design (not a placeholder), five polished screenshots cover every core screen with correct brand colors, and the store listing copy (title, subtitle, description, keywords) is written and validated against Apple's character limits. A 6-scene preview video script with timing, animation, and production notes is ready for a video editor.

## ✅ Verify it worked
- [ ] **App icon preview** — Open `app-store/app-icon-preview.html` in a browser; confirm the Echo mark renders at all sizes (1024px, 180px, 120px, 87px, 60px)
- [ ] **Screenshots** — Open `app-store/screenshots/screenshot-template.html`; verify 5 screens render with correct plum/ink brand colors on an iPhone 6.7" frame
- [ ] **Store listing** — Open `app-store/store-listing.md`; confirm you use a subtitle that is ≤ 30 characters (compliant alternatives are listed in the file)
- [ ] **ASO metadata** — Open `app-store/aso-metadata.json`; all fields present including privacy nutrition labels
- [ ] **Video script** — Open `app-store/preview-video-script.md`; 6 scenes × 5 seconds with real UI descriptions

## 📋 Decisions made this cycle (no action needed)
| What was decided | Options considered | Why |
|---|---|---|
| Screenshots rendered in HTML/CSS (not Figma) | Figma, Sketch, HTML | Keeps assets in repo, no external tool dependency, matches design token values |
| 5 screenshots (not 10) | 3–10 | Covers all 5 core screens; Apple requires minimum 3, App Store Connect accepts up to 10 for optional extras |
| Video script: 6 scenes × 5s = 30s | 15s, 30s, 60s | 30s is optimal for App Store preview; long enough to show real UX, short enough to hold attention |

## 🚨 Decisions that need your input
**Store listing subtitle:** The `store-listing.md` file flags one subtitle variant as 32 characters (2 over Apple's 30-char limit). The file already provides compliant alternatives — pick one before App Store submission. The `aso-metadata.json` is already correct (uses the compliant version).

## 🔜 Next cycle will work on
Phase 1E — Launch Prep: TestFlight beta distribution (500 users), bug bash, and App Store submission. This completes the full 1.0 build loop.

## ⏳ Waiting on you (blocked tasks)
| Task | What you need to do | What it unlocks |
|---|---|---|
| 1A-008 — Cloud storage | Add S3/R2 credentials to `api/.env` | Full-text article storage at scale |
| 1C-011 — Daily Briefing push | Provide APNs key from Apple Developer portal | Morning briefing push notifications |
| Store listing subtitle | Pick a compliant subtitle (≤ 30 chars) from `app-store/store-listing.md` | App Store submission unblocked |
