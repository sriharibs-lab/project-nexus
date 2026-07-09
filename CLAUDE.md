# Project Nexus — CLAUDE.md

## Communication Style
- Keep all responses **short and crisp**. No verbosity, no padding.
- User should not need to repeat themselves. Aggressively capture new context here.
- Surface decisions, blockers, and tradeoffs — don't hide them.

## Project Overview
Nexus is a mobile-first, AI-native content curation platform.
**Platform roadmap:** iOS (launch) → Android → Web → Desktop/Mac  
Goal: help users save, organize, summarize, and make sense of internet content (articles, podcasts, videos, threads, blogs, announcements).

Core thesis: The entire product is an AI harness — tools, skills, and memory built ground-up. Not a feature on top of a traditional app. The AI *is* the product.

## Design System
- All design resources (tokens, logos, icons, typography) must be **centrally maintained** and platform-agnostic
- Source of truth: design token JSON + SVG assets in `/design-system/`
- Prototype built in React/Next.js to nail UX before native iOS build

## UX Philosophy
- User has exceptionally high UX standards. Benchmark: **Notion + NotebookLM** — Notion's clean information architecture and minimal color discipline, NotebookLM's AI-native interaction model.
- **Color**: Light/white background, near-black text, one accent used sparingly. Dark mode = deep gray, same restraint. Not dark-first anymore.
- **Landing page**: Single-box, one CTA, no bottom feature sections. Clean.
- Custom logos, icons, and typography are non-negotiable.
- Mobile-first (iPhone launch). Every screen must be purposeful and beautiful.
- Never propose generic UI. Always go for opinionated, modern, unique.
- **Always render visuals.** At every design step, produce an actual HTML file or React component the user can open in a browser. Never describe colors, fonts, or layouts in text or tables alone — user must see, not read.

## App IA (locked)
- Collections are the root. No global library.
- Each Collection has two tabs: **Nexus** (AI agent, default landing) + **Sources** (links)
- Creation: "Research a topic" (AI-seeded) | "Start with a link" (manual)
- Saving a link always prompts to assign to a collection — no inbox
- Full terminology table: SPEC.md §5a

## Design System (v1 complete)
- Full iOS handoff in `nexus-design-system-extracted/design_handoff_nexus_ios/`
- Read `DESIGN_LANGUAGE.md` + `README.md` before any UI work — canonical and non-negotiable
- Brand mark: **Echo** (SVG in `logo.jsx`). Palette: soft plum bloom bg, ink text, plum `#7054AB` accent
- Material model: inline = solid + hairline; floating = Liquid Glass (menus, tab capsule)

## Working Model (locked 2026-07-08) — Browser-first design
- **All UX design iteration happens in `/prototype` (Next.js), never directly in SwiftUI.** Srihari reviews on his **iPhone in Safari** (never desktop) — no Xcode in the design loop.
- Prototype is semi-hooked to the real FastAPI backend (real login/OTP, real research streaming, real chat) so latency/streaming are judged as design material.
- Prototype is a **design tool, not a product** — shipping app is native iOS. Locked designs port to SwiftUI in flow-batches; each batch gets a device fidelity pass.
- **Phases:** 1) Full app UX in browser (semi-live) → 2) Port to SwiftUI + full E2E → 3) Q&A quality (headless harness, runs in parallel from the start).
- **NBL restriction:** mechanical work only (backend, wiring, tests, porting locked specs). Never UI/design judgment.

### Port protocol (from 2026-07-09 login retro)
- **"Port-ready" definition**: a flow ports to SwiftUI only after Srihari has tested it in the prototype ON HIS PHONE including keyboard-up states AND live-mode E2E against the real backend. Logic bugs (OTP length, debounce, API 500s) must die in the browser.
- **Claude simulator-checks before handoff**: after any iOS change, run the app in the Simulator and eyeball screenshots of each state (incl. keyboard up) before asking Srihari to test. His device time is for feel/fidelity, not for finding layout bugs.
- **Batch device tests**: accumulate fixes; Srihari tests once per batch, never one-rebuild-per-fix.
- **Timebox platform mysteries to 2 attempts**, then park with documented investigation (AutoFill took 6 — too many).
- **Every new backend endpoint gets one real E2E call** (curl against live DB) before it's "done" — unit tests with mocked DBs don't count.
- **Calibrated claims**: "changed X, hypothesis Y, please verify" ≠ "fixed". Only say fixed after verification.
- DEBUG builds show a build stamp on the auth screen — check it when behavior "didn't change" (stale-build detector).

### Fidelity contract (fixes past browser→app drift)
- Past failure: HTML designs never translated 1:1 to SwiftUI. Root causes: wrong fonts in browser, untokenized values, effects with no SwiftUI equivalent (glass), motion physics mismatch.
- Rules: prototype uses **system font stack** (renders SF Pro on iPhone Safari — same glyphs as the app); **every value from tokens** (no raw hex/px), same JSON feeds both CSS and Swift; **constrained vocabulary** — only primitives with a known-exact SwiftUI mapping are allowed in the prototype.
- **Device-final list** (designed directly in SwiftUI, only roughed-in in browser): Liquid Glass/materials, spring physics, haptics, native sheets/keyboard behavior.
- Every port batch ends with a **side-by-side screenshot diff** (prototype vs simulator) before the flow is called done.

## Autonomous Build System (NBL — designed, not yet built)
- 6-agent loop: Architect → Planner → SWE → Test → Review → ALM
- **Architect** is the strategic CTO agent — steers direction, weighs alternatives, flags risks
- Plan: `/Users/srihari/.claude/plans/whimsical-bubbling-kitten.md`
- When building: read the plan file first; don't implement without it

## Key Files
- [SPEC.md](SPEC.md) — Full product specification
- [BUILD_PLAN.md](BUILD_PLAN.md) — Running build plan, updated continuously
- [PARKING_LOT.md](PARKING_LOT.md) — Accumulated follow-ups (stub links, deferred decisions); review before TestFlight. Add items here whenever something is stubbed or deferred.
- [nexus-design-system-extracted/design_handoff_nexus_ios/DESIGN_LANGUAGE.md](nexus-design-system-extracted/design_handoff_nexus_ios/DESIGN_LANGUAGE.md) — Design system canonical
- GitHub: https://github.com/sriharibs-lab/project-nexus

## User Preferences
- AI-native architecture: model + tools + memory + skills as the foundation
- No feature creep — every feature must earn its place
- Privacy-first by design
- Start focused: iPhone app first, then expand
