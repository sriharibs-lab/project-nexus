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

## Autonomous Build System (NBL — designed, not yet built)
- 6-agent loop: Architect → Planner → SWE → Test → Review → ALM
- **Architect** is the strategic CTO agent — steers direction, weighs alternatives, flags risks
- Plan: `/Users/srihari/.claude/plans/whimsical-bubbling-kitten.md`
- When building: read the plan file first; don't implement without it

## Key Files
- [SPEC.md](SPEC.md) — Full product specification
- [BUILD_PLAN.md](BUILD_PLAN.md) — Running build plan, updated continuously
- [nexus-design-system-extracted/design_handoff_nexus_ios/DESIGN_LANGUAGE.md](nexus-design-system-extracted/design_handoff_nexus_ios/DESIGN_LANGUAGE.md) — Design system canonical
- GitHub: https://github.com/sriharibs-lab/project-nexus

## User Preferences
- AI-native architecture: model + tools + memory + skills as the foundation
- No feature creep — every feature must earn its place
- Privacy-first by design
- Start focused: iPhone app first, then expand
