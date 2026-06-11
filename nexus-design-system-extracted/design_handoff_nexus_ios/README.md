# Handoff: Nexus — iOS app (collections + AI agent)

## Overview
Nexus is an iOS app for AI-grounded research collections. Users create a **Collection** by describing a topic in natural language (the AI researches and proposes authoritative sources) or by adding links directly. Each collection has two tabs: **Nexus** (the AI agent — default landing tab: framing summary, starter prompts, grounded Q&A with inline citations, and creation actions like audio summaries and quizzes) and **Sources** (the grounding material — view, add, remove). This package covers the full v1 surface: home/collection list, first-run creation flow, the collection view, the add-source flow, the Nexus chat, and the brand mark.

## About the Design Files
The files in this bundle are **design references created in HTML/React (Babel, single-file JSX)** — interactive prototypes showing intended look and behavior, NOT production code to copy directly. The task is to **recreate these designs in the target codebase's environment** (SwiftUI is the natural fit for iOS; React Native also works) using its established patterns. If no codebase exists yet, choose the platform-appropriate framework (SwiftUI recommended) and implement the designs there.

`DESIGN_LANGUAGE.md` (copied from the project's CLAUDE.md) is the canonical design language — read it first. Where this README and that file overlap, they agree; that file wins on philosophy, this one on specifics.

## Fidelity
**High-fidelity.** Colors, type scale, spacing, radii, copy, and motion curves are final and should be recreated faithfully. The iPhone bezel/status bar in the prototypes (`ios-frame.jsx`) is scaffolding — use real device chrome. The design-canvas/tweaks wrappers (`design-canvas.jsx`, `fre.jsx` artboard layout) are presentation scaffolding only.

## App model
- Collections are the root. No global library.
- Home = list of collection cards → tapping one opens its **Nexus** tab.
- Collection tabs: **Nexus** (default) and **Sources**, in a floating bottom glass capsule.
- Creation is AI-seeded ("Research a topic") or manual ("Start with a link").

## Terminology (locked strings)
| Concept | String |
|---|---|
| Primary container | Collection |
| AI tab | Nexus |
| Sources tab / one item | Sources / Source |
| AI-seeded creation | Research a topic |
| Manual creation | Start with a link |
| AI building state | Researching… |
| Sources found state | Found N sources |
| Add manually | Add a source |
| Remove | Remove from collection |
| Onboarding CTA | Create your first collection |

## Design tokens
From `landing-kit.jsx → lTheme()`:
- Page background: `radial-gradient(135% 60% at 50% -8%, #E7DCF4 0%, #F9F8FC 50%)` (the soft plum bloom — the ONLY ambient color)
- Surfaces: `#FFFFFF` (surface), `#F4F2F9` (surface2), `#FBFAFD` (surface3)
- Ink/text: `#130E1A`; muted `#68607A`; faint `#9A93AC`; ghost `#B7B1C4`
- Hairlines: border `#E9E5F2`, borderStrong `#DCD7EA`, hair `#EEEBF5`
- **Accent plum `#7054AB`** — approved uses ONLY: send/confirm buttons, loading spinner, selected tab tint (icon + label), Echo-pulse wait state, brand mark. Everything else is accent-free; hierarchy comes from weight + spacing.
- Type: system stack (`-apple-system, 'SF Pro Text'…`), negative letter-spacing throughout (−0.1 to −0.8 by size). Wordmark only: Geist 600, tracking −0.035em.
- Radii: cards/rows 13–16, composer 22–24, menus 22–26, pills/capsule 999. Shadows: hairline cards get `0 1px 2px rgba(19,14,26,0.03)`; floating glass gets `0 22px 58px`-class soft float shadows; sheets `0 -12px 40px rgba(19,14,26,0.20)`.

## Material model (two layers — never mixed)
1. **Inline controls ON a surface** (composer, rows, cards, create-cards): solid/translucent fill + hairline border. No glass, no heavy shadow.
2. **Floating layers ABOVE content** (menus, the bottom tab capsule): **Liquid Glass** — layered: backdrop blur(8px) saturate(195%) brightness(1.05); diagonal white gloss gradient; inset chromatic edges (faint blue 150,170,255 bottom / pink 255,150,205); crisp specular rim; soft float shadow. Radius 22–26. Scrim behind menus is transparent — content outside is never dimmed/blurred. See `LiquidGlassCard` in `landing-app.jsx`.

## Brand: the Echo mark
Final mark (see `logo.html` / `logo.jsx → NexusMark`): two facing arcs holding a filled center node, plus a second lighter arc pair (32% opacity) radiating outward. Strictly monochrome in-hue: plum on white, white on ink. 48-grid: inner arcs r11 stroke 3, outer arcs r17.5 stroke 2.2 @ 32%, node r4.4. Wordmark lockup: mark + "Nexus" (Geist 600), gap = 0.36 × icon size. The 24-grid icon version is `nexus` in `landing-kit.jsx → LIcon`; `nexusFill` is the selected-tab variant.

## Screens

### 1. Home — collection list (`home.html`, `landing-app.jsx`)
Status area → header row: Recent/All segmented pivot (sliding thumb, swipeable panes) left, avatar "M" right. Collection cards are full-width rows with vertical gap (NOT a divided list). Composer pinned at bottom (24px above home indicator). Avatar opens the account menu: Liquid Glass card blooming from the avatar's top-right corner (anchor top:64, right:14); avatar hides instantly (opacity 0, .05s) while open, springs back with `nxPop` bounce on close. Menu: profile header (name + email) + rows Account · Settings · Feedback. No dividers anywhere in menus — hierarchy via caption/weight/spacing.

### 2. FRE / Create a collection (`fre-flow.jsx`)
- **Input screen**: kicker `NEW COLLECTION`, headline "Start a collection on" + rotating topic word (cycles every 2.2s, fade+rise transition, 240ms), composer ("Research a topic…", + button, mic→plum send swap when active), trending topic chips (trending icon + label), then "Or start with a link" with Website/PDF/YouTube tiles. Avatar + account menu top-right (same as home).
- **Tap a topic chip → sources sheet**: a bottom sheet rises to **90%** (`translateY(9.5%)`, ease `cubic-bezier(.32,.72,.28,1)`, .52s) while the input screen scales back to 0.945 with 22px corner radius (iOS modal style). Grabber, topic title, status line: plum spinner + rolling phrases ("Researching…", "Finding authoritative sources…", …, ~2s apart). Six shimmer rows stream into real source rows one-by-one (~430ms apart).
- **Review**: status becomes "✓ Found 6 sources — tap to deselect any". Rows: type icon in soft square, title, source · meta, check circle (tap toggles; deselected rows dim to 45%; minimum 1 selected). Footer slides up (overshoot ease `cubic-bezier(.22,1.18,.36,1)`): full-width plum pill **"Create collection · N sources"**.
- **Confirm → page push**: the sheet dismisses DOWN while the collection page pushes in FROM THE RIGHT (two simultaneous motions; leading-edge shadow). Back later pops the page right — sheet = modal, collection = pushed page. X/scrim during the sheet phases dismisses downward.

### 3. Collection view (`collection-view.jsx`)
Header: circular back button (40px, white + hairline ring, spring press scale 0.84 with bouncy release `cubic-bezier(.18,1.5,.4,1)` .44s). Title (26/700/−0.7) + "N sources · updated …".
**Bottom tab capsule** (floating Liquid Glass, centered, 24px above home indicator): two vertical items — 26px icon over 11.5px label, 30px horizontal padding. Selected: filled icon variant + plum tint on icon AND label; inactive: muted outline. The white glass thumb slides between tabs on a **true-spring `linear()` easing** (~520ms, overshoots ~1.12 — never a JS/rAF spring) and simultaneously plays a liquid bubble squash: scale(1.13,.87) at 38% → scale(.95,1.05) at 68% → 1 (.56s). Panes swipe horizontally in sync (slide, 380ms, `cubic-bezier(.2,.8,.2,1)`).

### 4. Nexus tab (default)
- **Hero**: Echo mark (27px, ink) → AI-written framing paragraph (16.5/500/1.55) — an enticing editorial hook ending "I've read all N sources — ask me anything." (model-generated per collection in production; see `NX_FRAMING` for the quality bar) → `CREATE` caption → 2×2 grid of creation cards (white, hairline, radius 14; plum icon + 13.5/600 label): Audio summary (waveform glyph), Infographic, Quiz me, Write a paper → `OR ASK` caption → six question chips (wrapping pills).
- **Chat**: user message = right-aligned pill (surface2, radius 18). Wait state = **Echo pulse**: the mark's arc pairs ripple outward from the breathing node (two staggered rings, scale .45→1.45 fade, 1.7s loop, plum). Answers are plain left-aligned text (15/1.6) with **inline source chips** mid-sentence (22px pills: type icon + source name, 11.5/600 muted) and bullet blocks where appropriate. Creation prompts return artifact cards: audio player (ink play circle, "Two hosts · 4:32", waveform glyph), infographic preview, quiz card (Question 1 of 5 + tappable options), paper outline. After the first exchange, unused suggestions render as a horizontally scrollable chip row above the composer. Auto-scroll to latest (set scrollTop, no scrollIntoView).
- **Composer** (prominent): two-tier, radius 24, strong border + `0 0 0 3px #F4F2F9` halo ring; ghost "Ask Nexus anything"; row: + attach, spacer, mic, and the single ink-filled **audio button** (waveform glyph) — the one ink anchor on this surface.

### 5. Sources tab
Flat list (no cards, no dividers): bare type glyph (globe/file/video/photo/mic/note, 19px muted) + title (15/600) + "Source · meta" line + quiet x (Remove from collection; row collapses via max-height .3s + fade). Rows fade in on add; new fetched links show a shimmer title + "Fetching…" that resolves (~1.4s). Bottom: full-width **"+ Add a source"** pill button (48px, white, hairline, centered icon+label; + rotates 45° while the sheet is open).

### 6. Add a source (AI-driven sheet)
Same grammar as creation: sheet rises to ~92%. Title "Add a source" + close X. Composer ("Research a topic…"), `SUGGESTED FOR THIS COLLECTION` — three topic-aware chips marked with the Echo glyph (e.g. "Sanctions and their history") — then `OR ADD A LINK` tiles (Website / PDF / YouTube; insert directly with fetch shimmer). Tapping a suggestion: Researching state (plum spinner + rolling phrases, 3 shimmer rows) → 3 sources stream in with check circles → plum footer **"Add N sources"** → rows drop into the top of the list, sheet dismisses down.

## Motion reference
- Press bounce on EVERY tappable: scale to 0.88–0.97, release springs past via `cubic-bezier(.18,1.5,.4,1)` (~.24s). Avatar/back button use 0.84 + .44s.
- Menus: bloom-morph — surface scales .12→1 from the anchor corner on baked spring `linear()` (k=200, c=15.5, ζ≈.55); content fades in ~.1s later; close = quick ease-in collapse (.26s `cubic-bezier(.4,0,.9,.35)`). Corner-pinned via transform-origin.
- Sheets: `cubic-bezier(.32,.72,.28,1)`; page push/pop: `cubic-bezier(.2,.8,.2,1)` .48s; footer reveals: `cubic-bezier(.22,1.18,.36,1)`.
- Shimmer: 1.6s linear gradient sweep (#EDEAF5→#F5F3FB). Entrances degrade to visible (reduced motion / print).
- Never animate transforms while retargeting a hidden element — disable transitions at rest (see sheet reset bug note in `fre-flow.jsx`).

## State management
- Creation flow: `input → loading → review → collection` (+ `closing` with direction: sheet closes DOWN, page pops RIGHT). Found-source streaming is per-item timers; review requires ≥1 selected.
- Collection: items array (id, src, title, meta, icon, pending); pivot Nexus|Sources; add-sheet phase input|loading|review.
- Chat: messages [{role:'user',text} | {role:'nexus', blocks, kind?}]; busy flag drives Echo pulse; blocks = paragraphs/bullets with inline chip refs; kind = audio|info|quiz|paper artifacts.
- Production data needs: topic→sources research endpoint (streamed), per-collection framing summary, grounded Q&A with citations, artifact generation.

## Safe areas
All bottom-pinned elements clear the home indicator: capsule 24px, sheet footers 28px, home composers 24px. Hit targets ≥44px (capsule items ~50px, buttons 48–50px).

## Assets
No raster assets. All icons are 24-grid stroke SVGs (1.6–1.7px, round caps) in `landing-kit.jsx → LIcon`, including the `nexus`/`nexusFill` brand glyph and `layers`/`layersFill`. Brand mark + lockup: `logo.jsx`. Wordmark font: Geist (Google Fonts) — only for the lockup, not UI text.

## Files
- `DESIGN_LANGUAGE.md` — canonical design language (read first)
- `fre.html` — canvas of every screen, one row per flow (open in a browser; needs the sibling .jsx files)
- `fre-flow.jsx` — creation flow (input → sheet → review → page push)
- `collection-view.jsx` — collection view: tabs, Nexus chat, Sources list, add-source sheet
- `landing-app.jsx` — home screen, Pressable/Segmented/PivotSwipe/BloomMenu/LiquidGlassCard primitives, avatar menu
- `landing-kit.jsx` — theme tokens + icon set
- `landing-pieces.jsx` — sample collections/sources data
- `home.html` — home screen standalone (with motion tweaks panel)
- `logo.html` / `logo.jsx` — brand mark spec sheet
- `fre.jsx`, `ios-frame.jsx`, `design-canvas.jsx`, `tweaks-panel.jsx` — presentation scaffolding (device bezel, canvas, tweaks)
