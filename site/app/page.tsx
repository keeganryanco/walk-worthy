import Link from "next/link";
import { SiteShell } from "./_components/site-shell";

export default function HomePage() {
  return (
    <SiteShell current="home">
      <section className="panel" aria-labelledby="site-title">
        <h1 id="site-title" className="hero-title">
          Official Tend Resources
        </h1>
        <p className="hero-subtitle">
          Access support, privacy disclosures, and terms for Tend. This site hosts the public legal and support links
          used in App Store submission and in-app settings.
        </p>

        <div className="quick-links">
          <Link className="quick-link" href="/privacy">
            <strong>Privacy Policy</strong>
            <span>What we collect, how we use data, and your controls.</span>
          </Link>

          <Link className="quick-link" href="/terms">
            <strong>Terms of Use</strong>
            <span>Subscription terms, acceptable use, and legal terms.</span>
          </Link>

          <Link className="quick-link" href="/support">
            <strong>Support</strong>
            <span>Contact support and issue-reporting instructions.</span>
          </Link>
        </div>
      </section>
    </SiteShell>
  );
}
