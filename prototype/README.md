# Nexus prototype

Browser-first design tool for Nexus — **not** the shipping product (that is the native iOS app in `app-ios/`).

All UX iteration happens here first. The prototype is semi-hooked to the real FastAPI backend (`api/`): real login/OTP, real research streaming, real chat — so latency and streaming are judged as design material. Designs are reviewed on **iPhone Safari**, never desktop, then locked flows are ported to SwiftUI in batches.

It uses the system font stack (renders SF Pro on iPhone) and every visual value comes from the shared design tokens in `src/styles/tokens.css`, generated from `/design-system/`.

## Run

```bash
npm install
npm run dev        # http://localhost:3000 — open from your phone via your Mac's LAN IP
```

## Environment variables

| Var | Purpose |
| --- | --- |
| `NEXT_PUBLIC_API_URL` | Base URL of the FastAPI backend (e.g. `http://192.168.1.10:8000` for local, or your Render URL). Unset → mock mode. |
| `WAITLIST_PROVIDER` | `local` (default), `resend` or `mailchimp` — backend for the landing-page waitlist form. |
| `RESEND_API_KEY`, `RESEND_AUDIENCE_ID` | Only when `WAITLIST_PROVIDER=resend`. |
