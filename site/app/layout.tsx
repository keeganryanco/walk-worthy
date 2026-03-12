import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Walk Worthy",
  description: "Support and privacy information for Walk Worthy."
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
