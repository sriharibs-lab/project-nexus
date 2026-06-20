import { NextRequest, NextResponse } from "next/server";
import fs from "fs";
import path from "path";

// ── Waitlist API route ──
// Stores emails in a local JSON file (dev) or forwards to a provider.
// To wire a real provider: set WAITLIST_PROVIDER=resend|mailchimp and
// add the corresponding API key env var (RESEND_API_KEY or MAILCHIMP_API_KEY).
// Neither env var is required — it degrades to local file storage.

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function localWaitlistPath(): string {
  return path.join(process.cwd(), ".waitlist.json");
}

function readLocalWaitlist(): string[] {
  try {
    const raw = fs.readFileSync(localWaitlistPath(), "utf-8");
    return JSON.parse(raw) as string[];
  } catch {
    return [];
  }
}

function writeLocalWaitlist(emails: string[]): void {
  fs.writeFileSync(localWaitlistPath(), JSON.stringify(emails, null, 2), "utf-8");
}

async function addToResend(email: string): Promise<void> {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) throw new Error("RESEND_API_KEY not set");
  const audienceId = process.env.RESEND_AUDIENCE_ID;
  if (!audienceId) throw new Error("RESEND_AUDIENCE_ID not set");

  const res = await fetch(`https://api.resend.com/audiences/${audienceId}/contacts`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({ email, unsubscribed: false }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Resend error ${res.status}: ${body}`);
  }
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  let body: { email?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ message: "Invalid request body." }, { status: 400 });
  }

  const email = (body.email ?? "").trim().toLowerCase();

  if (!email || !EMAIL_REGEX.test(email)) {
    return NextResponse.json(
      { message: "Enter a valid email address." },
      { status: 422 }
    );
  }

  const provider = process.env.WAITLIST_PROVIDER ?? "local";

  try {
    if (provider === "resend") {
      await addToResend(email);
    } else {
      // Local file fallback — fine for dev/preview
      const existing = readLocalWaitlist();
      if (!existing.includes(email)) {
        writeLocalWaitlist([...existing, email]);
      }
    }
  } catch (err) {
    console.error("[waitlist]", err);
    return NextResponse.json(
      { message: "Failed to save. Please try again." },
      { status: 500 }
    );
  }

  return NextResponse.json({ ok: true }, { status: 201 });
}
