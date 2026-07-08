# Parking Lot

Accumulated follow-ups that must not block current work but must not be forgotten.
Review before TestFlight submission.

- [ ] **Terms of Service + Privacy Policy pages** — login screen disclaimer links are stubs (`#`). Need real hosted pages + linked from login and Settings. (added 2026-07-08)
- [ ] **SSE event key inconsistency** — research stream uses `event:`, chat stream uses `type:`. Unify backend on one vocabulary; prototype parser normalizes both meanwhile. NBL task candidate. (added 2026-07-08)
- [ ] **Google Sign-In** — Claude-style auth layout accommodates a "Continue with Google" pill above Apple; Nexus v1 ships Apple + email only (Google is Phase 2 per SPEC). (added 2026-07-08)
- [ ] **Supabase free-tier pausing** — project pauses after ~7 idle days (DNS vanishes, backend startup fails). Upgrade to Pro or add keep-alive before TestFlight. (added 2026-07-08)
