# Project Nexus

AI-native content curation platform. Save, organize, summarize, and make sense of internet content.

**Platform roadmap:** iOS → Android → Web → Desktop

---

## Monorepo Structure

```
/
├── prototype/        Next.js 14 — UX prototype (nail the experience before native build)
├── api/              FastAPI — backend, AI integrations
├── app-ios/          Swift/SwiftUI — iPhone app (initialized after prototype sign-off)
├── design-system/    Platform-agnostic design tokens + assets
│   ├── tokens/       colors.json · typography.json · spacing.json · motion.json
│   └── assets/       icons/ · logos/
├── SPEC.md           Full product specification
├── BUILD_PLAN.md     Running build plan
└── CLAUDE.md         AI assistant instructions
```

## Quick Start

**Prototype**
```bash
cd prototype && npm install && npm run dev
```

**API**
```bash
cd api && python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```

## Design System

Token files in `design-system/tokens/` follow the [Design Tokens Community Group](https://design-tokens.github.io/community-group/format/) spec.
Fill in `$value` fields before generating platform-specific outputs.
