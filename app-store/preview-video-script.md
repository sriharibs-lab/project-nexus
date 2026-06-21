# Nexus — App Store Preview Video Script
**Duration:** 30 seconds  
**Format:** iPhone 15 Pro (6.7") · Portrait · No audio (App Store previews auto-play muted)  
**Tone:** Calm, intelligent, confident — not hype-y. Every caption should read like a thoughtful product person wrote it, not a marketer.

---

## Scene Breakdown

---

### Scene 1 — [0:00–0:05]
**Screen:** Home screen. Three collection cards visible: "AI & the Future of Work", "Morning Reads", "Longevity Research". Each card shows a title, 1-line summary, and subtle chip ("3 new insights", "5 sources").

**Caption (centered, large bold, above the device frame):**  
`Everything you've saved.`  
`Finally organized.`

**Animation:**  
- App opens cold (spring-in from scale 0.95). Collections slide up one by one with staggered entrance (80ms apart, ease-out).  
- No taps, no interactions — let the UI speak.  
- Subtle ambient scroll of the list after 3s, then freeze on the last frame.

**Production note:** Capture the soft plum bloom radial gradient background — it should feel warm and calm, not sterile.

---

### Scene 2 — [0:05–0:10]
**Screen:** Collection creation flow. User types "AI & the future of work" into the composer. After 1.5s the bottom sheet rises — sources stream in one by one (shimmer → resolved rows with check circles).

**Caption:**  
`Research any topic.`  
`Nexus finds the sources.`

**Animation:**  
- Composer text types in with a blinking cursor (medium typing speed, about 40ms/char).  
- Sheet rises with the design-system easing: `cubic-bezier(.32,.72,.28,1)` over 0.52s.  
- Source rows stream in at 430ms intervals — shimmer briefly, then resolve with the source title and the plum check circle.  
- End on "Found 8 sources — tap to deselect" status pill.

**Production note:** The streaming effect is the hero moment here. Make sure the shimmer is visible and the reveal feels satisfying, not rushed.

---

### Scene 3 — [0:10–0:15]
**Screen:** Nexus AI tab. Collection is open. The Echo framing paragraph is visible at top. A user message appears from the right: "What should I read first and why?" Then the Nexus answer streams in — plain, thoughtful, with one inline source chip visible.

**Caption:**  
`Your AI has read everything.`  
`Just ask.`

**Animation:**  
- User bubble slides in from right with spring ease.  
- Echo pulse wait state briefly animates (two concentric rings radiating from the center node, plum, ~0.8s).  
- Answer text streams in progressively, not word-by-word — paragraph-block reveals at 200ms intervals.  
- An inline source chip fades in mid-sentence: small pill with globe icon + "HBR".

**Production note:** The Echo pulse is brand-defining — make sure it's captured clearly. The answer should feel grounded and intelligent, not like a generic chatbot response.

---

### Scene 4 — [0:15–0:20]
**Screen:** Reader view. Full article open: "The Cognitive Labor Divide" by HBR. Two sentences are highlighted in amber. A floating annotation card is visible beneath one highlight.

**Caption:**  
`Read without distraction.`  
`Annotate what matters.`

**Animation:**  
- Slow, smooth scroll through the article body (~30px/s).  
- Pause briefly on the highlighted passage. The highlight has a warm amber glow — subtle, not distracting.  
- The annotation card ("Your Note") fades in gently beneath the second highlight.  
- End with the reader toolbar visible at the bottom: Highlight · Ask Nexus · Share · More.

**Production note:** The warm ivory background (#FFFEF9) of the reader distinguishes it from the main app. The contrast makes this feel like a different, calmer space. Let that breathe.

---

### Scene 5 — [0:20–0:25]
**Screen:** Daily Briefing. The date header is prominent ("Friday, June 20"). Two briefing cards are stacked — the first fully visible with a "Read" button in plum. A finger swipes left to reveal the second card.

**Caption:**  
`Your daily briefing.`  
`Curated from what you've saved.`

**Animation:**  
- Card stack animates in with a slight depth/parallax entrance (front card drops in, cards behind peek from bottom-right).  
- Swipe left on the first card — it slides away revealing the next. Use a spring-physics feel, slight overshoot and settle.  
- Progress dots at the bottom update in sync with the swipe.
- End on the second card, "Read" button visible.

**Production note:** This is the "daily habit" moment. The tone here should feel like the app is doing the heavy lifting so the user doesn't have to.

---

### Scene 6 — [0:25–0:30]
**Screen:** App icon on a dark home screen — surrounded by other app icons, positioned in the spotlight. Then a gentle zoom into the icon, centering on the Echo mark. Fade to white. Final lock-up: Echo mark + "Nexus" wordmark centered on white.

**Caption (final card, white background, centered):**  
`Nexus`  
`Your AI library.`  
*Below in smaller text:* `Download on the App Store`

**Animation:**  
- Home screen icon view: slow zoom into the Nexus icon (1.0× → 1.25×, 2s ease-in-out).  
- Cross-dissolve to white at 1.5s into the zoom.  
- Echo mark + wordmark fade in on white background (opacity 0 → 1, 0.4s ease).  
- Hold final frame for 1.5s.

**Production note:** The icon must look premium and distinct. The plum gradient with the Echo mark should read immediately at home screen size among other icons.

---

## Caption Typography
- **Scene captions:** 52px, SF Pro Display, weight 700, letter-spacing -0.04em, color #130E1A on light bg / white on dark bg  
- **Final lock-up:** Nexus wordmark in Geist 600, tracking -0.035em at 64px. Subtitle at 20px, weight 400, color #68607A.

## Pacing Notes
- Each scene: 5 seconds. No filler, no transitions longer than 0.3s between scenes.  
- Cut rhythm: clean, direct. No wipes or spin transitions — cut or cross-dissolve only.  
- The app should feel like it thinks clearly because it's built clearly.

## Production Tools
- **Capture:** Xcode Simulator screen recording (4K, 60fps) or physical device with QuickTime.  
- **Edit:** Final Cut Pro or CapCut for sequencing.  
- **Export:** H.264, 1080×1920 min (1290×2796 for 6.7" native), 30fps, under 500MB.  
- **Apple spec:** Max 30s, must open with the app itself (not a title card), muted by default.
