import Link from "next/link";
import { SiteShell } from "../_components/site-shell";

export const metadata = {
  title: "Tend Support"
};

export default function SupportPage() {
  return (
    <SiteShell current="support">
      <section className="panel legal">
        <article>
          <h1>Support</h1>
          <p className="meta">Support email: tend@keeganryan.co</p>

          <p>
            For help with Tend, send us an email and we will assist with troubleshooting, subscription issues, restore
            purchases, notifications, and account/device migration questions.
          </p>

          <div className="support-grid">
            <section className="support-card" aria-labelledby="support-contact-heading">
              <h3 id="support-contact-heading">Contact</h3>
              <p>
                Email:{" "}
                <a className="inline-link" href="mailto:tend@keeganryan.co">
                  tend@keeganryan.co
                </a>
              </p>
              <p className="support-subline">Typical response window: 1-3 business days.</p>
            </section>

            <section className="support-card" aria-labelledby="support-include-heading">
              <h3 id="support-include-heading">Include In Your Message</h3>
              <ul>
                <li>Device model and iOS version.</li>
                <li>Tend app version/build number.</li>
                <li>What happened and steps to reproduce.</li>
                <li>Screenshots or screen recordings if available.</li>
              </ul>
            </section>

            <section className="support-card" aria-labelledby="support-purchases-heading">
              <h3 id="support-purchases-heading">Purchases and Billing</h3>
              <ul>
                <li>Subscriptions are managed by Apple through your Apple ID.</li>
                <li>Use "Restore Purchases" in Tend after reinstalling or changing devices.</li>
                <li>Refund requests are handled directly by Apple.</li>
              </ul>
            </section>
          </div>

          <h2>Privacy and Data Requests</h2>
          <p>
            For privacy questions or requests related to your data, email{" "}
            <a className="inline-link" href="mailto:tend@keeganryan.co">
              tend@keeganryan.co
            </a>{" "}
            with subject line "Tend Privacy Request."
          </p>

          <h2>Notification Issues</h2>
          <p>If reminders are not firing, verify the following before contacting support:</p>
          <ul>
            <li>iOS Settings → Notifications → Tend is enabled.</li>
            <li>Focus mode is not silencing the reminder window you selected.</li>
            <li>Reminder time and timezone are set correctly in Tend settings.</li>
          </ul>

          <p className="footer-note">
            Related pages: <Link className="inline-link" href="/privacy">Privacy Policy</Link> and{" "}
            <Link className="inline-link" href="/terms">Terms of Use</Link>.
          </p>
        </article>
      </section>
    </SiteShell>
  );
}
