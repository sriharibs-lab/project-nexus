import type { Metadata } from "next";
import "../styles/tokens.css";
import "./globals.css";

export const metadata: Metadata = {
  title: "Nexus — Think, don't just save.",
  description:
    "Nexus is an AI-native content curation platform. Save anything, understand everything. Coming soon to iPhone.",
  openGraph: {
    title: "Nexus — Think, don't just save.",
    description:
      "An AI-native content curation platform. Save anything, understand everything.",
    type: "website",
  },
};

export const viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
