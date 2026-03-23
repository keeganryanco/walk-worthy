import Link from "next/link";
import type { ReactNode } from "react";

type NavKey = "home" | "privacy" | "terms" | "support";

const links: Array<{ key: NavKey; href: string; label: string }> = [
  { key: "home", href: "/", label: "Home" },
  { key: "privacy", href: "/privacy", label: "Privacy" },
  { key: "terms", href: "/terms", label: "Terms" },
  { key: "support", href: "/support", label: "Support" }
];

export function SiteShell({ current, children }: { current: NavKey; children: ReactNode }) {
  return (
    <main className="page">
      <div className="shell">
        <header className="site-header">
          <div className="brand-lockup">
            <p className="brand-mark">Tend</p>
            <p className="brand-tagline">pray. act. grow.</p>
          </div>

          <nav className="nav-pills" aria-label="Site navigation">
            {links.map((link) => (
              <Link
                key={link.key}
                href={link.href}
                className={link.key === current ? "nav-pill active" : "nav-pill"}
              >
                {link.label}
              </Link>
            ))}
          </nav>
        </header>

        {children}
      </div>
    </main>
  );
}
