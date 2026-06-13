import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import "./globals.css";

/*
 * Geist — wordmark lockup only (maps to --nx-font-display).
 * The --font-geist CSS variable is set here so globals.css can reference it.
 */
const geist = localFont({
  src: "./fonts/GeistVF.woff",
  variable: "--font-geist",
  weight: "100 900",
});

export const metadata: Metadata = {
  title: "Nexus — Prototype",
  description: "Nexus iOS prototype — core screens",
};

// viewport-fit=cover is required so env(safe-area-inset-*) values are non-zero
// on iPhone models with a notch or Dynamic Island when opened in mobile Safari.
// In Next.js 14+ this must be a separate named export, not part of metadata.
export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${geist.variable} antialiased`}>
        {children}
      </body>
    </html>
  );
}
