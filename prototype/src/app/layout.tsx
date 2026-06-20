import type { Metadata } from "next";
import localFont from "next/font/local";
import "./globals.css";

const geistSans = localFont({
  src: "./fonts/GeistVF.woff",
  variable: "--font-geist-sans",
  weight: "100 900",
});

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

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${geistSans.variable} antialiased`}>{children}</body>
    </html>
  );
}
