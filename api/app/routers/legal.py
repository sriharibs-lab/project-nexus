"""
Legal pages — Terms of Service + Privacy Policy, served as styled HTML.

Public (no auth). Stable URLs the iOS app links to and App Store Connect
points at for the required Privacy Policy URL:
  GET /legal/terms
  GET /legal/privacy

NOTE (for Srihari): this is solid, app-accurate boilerplate — have it reviewed
and fill the bracketed placeholders ([LEGAL ENTITY], [GOVERNING LAW]) before
public App Store release.
"""

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter(prefix="/legal", tags=["legal"])

_UPDATED = "October 9, 2026"
_CONTACT = "srihari.scorp@gmail.com"

_STYLE = """
:root { color-scheme: light dark; }
* { box-sizing: border-box; }
body {
  margin: 0; background: #F7F3EC; color: #17120C;
  font: 16px/1.65 -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
  -webkit-text-size-adjust: 100%;
}
.wrap { max-width: 720px; margin: 0 auto; padding: 48px 22px 96px; }
.eyebrow { font-size: 12px; font-weight: 700; letter-spacing: 1.4px; text-transform: uppercase; color: #7054AB; }
h1 { font-size: 30px; font-weight: 700; letter-spacing: -0.5px; margin: 10px 0 4px; }
.updated { color: #6A6253; font-size: 14px; margin-bottom: 32px; }
h2 { font-size: 19px; font-weight: 700; letter-spacing: -0.2px; margin: 34px 0 10px; }
p, li { color: #2A2419; }
a { color: #7054AB; }
ul { padding-left: 22px; }
li { margin: 6px 0; }
.note { background: #FFFFFF; border: 1px solid #E6DFD2; border-radius: 14px; padding: 14px 16px; font-size: 14.5px; color: #6A6253; }
hr { border: none; border-top: 1px solid #E6DFD2; margin: 40px 0; }
@media (prefers-color-scheme: dark) {
  body { background: #17120C; color: #F2ECE2; }
  p, li { color: #D9D2C6; }
  .updated { color: #A89F8E; }
  .note { background: #221B12; border-color: #3A3225; color: #A89F8E; }
  hr { border-top-color: #3A3225; }
}
"""


def _page(title: str, body: str) -> str:
    return f"""<!doctype html><html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Nexus — {title}</title><style>{_STYLE}</style></head>
<body><div class="wrap">
<div class="eyebrow">Nexus</div>
<h1>{title}</h1>
<p class="updated">Last updated: {_UPDATED}</p>
{body}
<hr>
<p class="note">Questions? Contact us at <a href="mailto:{_CONTACT}">{_CONTACT}</a>.</p>
</div></body></html>"""


_PRIVACY = _page("Privacy Policy", f"""
<p>Nexus (the "App", operated by [LEGAL ENTITY], "we", "us") is an AI-native
content-curation app that helps you save, organize, summarize, and ask questions
about internet content. This policy explains what we collect, how we use it, and
your choices.</p>

<h2>Information we collect</h2>
<ul>
<li><strong>Account</strong> — your email address (for sign-in), or the identifier from Sign in with Apple.</li>
<li><strong>Your content</strong> — the links, articles, videos, podcasts, and topics you save, the collections you create, your questions, and the artifacts (quizzes, reports) you generate.</li>
<li><strong>Usage &amp; diagnostics</strong> — basic operational and error telemetry so we can keep the service reliable (e.g. which AI operations ran, failures). We do not use third-party advertising trackers.</li>
</ul>

<h2>How we use your information</h2>
<ul>
<li>To provide the App's core features — research, saving sources, chat answers grounded in your sources, and content generation.</li>
<li>To process the content you save and your questions through AI models to produce summaries, answers, and artifacts.</li>
<li>To operate, secure, debug, and improve the service.</li>
</ul>

<h2>AI processing &amp; service providers</h2>
<p>To deliver the App, your content and queries are processed by trusted
third-party providers acting on our behalf. These include:</p>
<ul>
<li><strong>Supabase</strong> — authentication and database.</li>
<li><strong>Render</strong> — application hosting.</li>
<li><strong>Anthropic</strong> — AI research and chat.</li>
<li><strong>Fireworks AI</strong> — embeddings and content generation.</li>
<li><strong>Deepgram</strong> — audio transcription (for podcasts/audio you add).</li>
<li><strong>Jina AI</strong> — article content extraction.</li>
<li><strong>Resend</strong> — transactional sign-in emails.</li>
</ul>
<p>We share only what each provider needs to perform its function. We do not
sell your personal information.</p>

<h2>Data retention &amp; deletion</h2>
<p>We keep your data while your account is active. You can permanently delete
your account and all associated data at any time from <strong>Settings →
Account → Delete account</strong>. This removes your collections, sources,
generated content, and your sign-in identity. Deletion is immediate and cannot
be undone.</p>

<h2>Security</h2>
<p>We use industry-standard measures to protect your data in transit and at
rest. No method of transmission or storage is 100% secure, but we work to
protect your information.</p>

<h2>Children</h2>
<p>Nexus is not directed to children under 13, and we do not knowingly collect
personal information from them.</p>

<h2>Changes</h2>
<p>We may update this policy; we will revise the "Last updated" date above and,
where appropriate, notify you in the App.</p>
""")


_TERMS = _page("Terms of Service", f"""
<p>These Terms govern your use of Nexus (the "App", operated by [LEGAL ENTITY]).
By using the App you agree to these Terms.</p>

<h2>The service</h2>
<p>Nexus helps you save, organize, summarize, and ask questions about internet
content using AI. The App is currently offered as a beta and is provided on an
"as is" and "as available" basis.</p>

<h2>Your account</h2>
<p>You must provide accurate sign-in information and are responsible for activity
under your account. You must be at least 13 years old to use the App.</p>

<h2>Your content</h2>
<p>You retain ownership of the content you add. You grant us a limited license to
store and process that content solely to provide the App's features to you
(including processing it through the AI providers described in our Privacy
Policy). You are responsible for ensuring you have the right to save and use the
content you add.</p>

<h2>Acceptable use</h2>
<ul>
<li>Don't use the App for unlawful purposes or to infringe others' rights.</li>
<li>Don't attempt to disrupt, reverse-engineer, or abuse the service or its rate limits.</li>
<li>Don't upload content you don't have the right to use.</li>
</ul>

<h2>AI-generated output</h2>
<p>The App uses AI to generate summaries, answers, and artifacts. <strong>AI
output can be inaccurate or incomplete and is not professional (legal, medical,
financial, or other) advice.</strong> Verify important information against the
original sources before relying on it.</p>

<h2>Disclaimers &amp; limitation of liability</h2>
<p>To the maximum extent permitted by law, the App is provided without warranties
of any kind, and we are not liable for indirect, incidental, or consequential
damages arising from your use of the App.</p>

<h2>Termination</h2>
<p>You may stop using the App and delete your account at any time. We may suspend
or terminate access if these Terms are violated or to protect the service.</p>

<h2>Governing law</h2>
<p>These Terms are governed by the laws of [GOVERNING LAW], without regard to
conflict-of-law rules.</p>

<h2>Changes</h2>
<p>We may update these Terms; continued use after changes means you accept the
updated Terms.</p>
""")


@router.get("/terms", response_class=HTMLResponse)
async def terms() -> str:
    return _TERMS


@router.get("/privacy", response_class=HTMLResponse)
async def privacy() -> str:
    return _PRIVACY
