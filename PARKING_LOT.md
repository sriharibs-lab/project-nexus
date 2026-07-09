# Parking Lot

Accumulated follow-ups that must not block current work but must not be forgotten.
Review before TestFlight submission.

- [ ] **Terms of Service + Privacy Policy pages** — login screen disclaimer links are stubs (`#`). Need real hosted pages + linked from login and Settings. (added 2026-07-08)
- [ ] **SSE event key inconsistency** — research stream uses `event:`, chat stream uses `type:`. Unify backend on one vocabulary; prototype parser normalizes both meanwhile. NBL task candidate. (added 2026-07-08)
- [ ] **Google Sign-In** — Claude-style auth layout accommodates a "Continue with Google" pill above Apple; Nexus v1 ships Apple + email only (Google is Phase 2 per SPEC). (added 2026-07-08)
- [ ] **Supabase free-tier pausing** — project pauses after ~7 idle days (DNS vanishes, backend startup fails). Upgrade to Pro or add keep-alive before TestFlight. (added 2026-07-08)
- [ ] **Production email domain** — Resend SMTP wired into Supabase for OTP emails; until a domain is verified in Resend, delivery only works to Srihari's own email. Verify a sending domain (needs the nexus domain decision) before TestFlight. Also: replace `onboarding@resend.dev` sender with branded address. (added 2026-07-09)
- [ ] **iOS test target + auth smoke test** — no XCTest/XCUITest target exists in the Xcode project. Add one and cover the auth flow (incl. OTPField insertion path — regression guard for the AutoFill kerning bug). Good NBL task. (added 2026-07-09)
- [ ] **Supabase OTP length → 6** — project currently sends 8-digit codes; 6 is the iOS convention. If changed in dashboard, update `OTPField.otpLength` (AuthView.swift) and `OTP_LENGTH` (prototype login). (added 2026-07-09)
- [ ] **Dark mode design pass** — dark palette exists in tokens.css but is undesigned/buggy; prototype forces light (`color-scheme: light` + disabled media query in tokens.css). Design dark properly (CLAUDE.md: deep gray, same restraint) then re-enable. Srihari also noted checking Claude's design system for dark bg reference (BUILD_PLAN decision log 2026-06-13). (added 2026-07-09)
