import type { Metadata } from "next";
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
  title: "Nexus",
  description: "AI-native content curation",
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
