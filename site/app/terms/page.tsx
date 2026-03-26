import Link from "next/link";
import { SiteShell } from "../_components/site-shell";

export const metadata = {
  title: "Tend Terms of Use"
};

export default function TermsPage() {
  return (
    <SiteShell current="terms">
      <section className="panel legal">
        <article>
          <h1>Terms of Use</h1>
          <p className="meta">Effective date: March 23, 2026</p>

          <p>
            These Terms of Use ("Terms") govern your access to and use of the Tend app, website, and related
            services (collectively, the "Service"). By using Tend, you agree to these Terms.
          </p>

          <h2>1. Eligibility and Acceptance</h2>
          <ul>
            <li>You must comply with applicable law when using Tend.</li>
            <li>If you are under the age of majority in your jurisdiction, use Tend only with permission from a parent or guardian.</li>
            <li>If you do not agree to these Terms, do not use the Service.</li>
          </ul>

          <h2>2. License and Apple Terms</h2>
          <ul>
            <li>
              Subject to these Terms, we grant you a limited, non-exclusive, non-transferable, revocable license to
              use Tend for personal, non-commercial use.
            </li>
            <li>
              If you access Tend through Apple platforms, your use is also subject to Apple terms, including the
              Licensed Application End User License Agreement (EULA).
            </li>
            <li>
              Apple is not responsible for Tend content, maintenance, or support obligations beyond what is required by law.
            </li>
          </ul>

          <h2>3. Service Description</h2>
          <p>
            Tend is a faith-based prayer and action habit app. It provides journey tracking, reminders, AI-generated
            reflection content, and subscription-based premium features.
          </p>

          <h2>4. AI-Generated Content Disclaimer</h2>
          <ul>
            <li>
              Tend may generate reflections, scripture paraphrases/references, prayer text, and suggested steps using
              AI systems.
            </li>
            <li>
              AI output may be incomplete, inaccurate, or unsuitable in some situations.
            </li>
            <li>
              Tend does not provide medical, legal, financial, mental-health, or emergency-response advice.
            </li>
            <li>
              You are responsible for how you interpret and use generated content.
            </li>
          </ul>

          <h2>5. User Content</h2>
          <ul>
            <li>
              You retain ownership of content you enter in Tend (for example name, prayer goals, reflections, and
              journey notes).
            </li>
            <li>
              You grant us a limited license to process that content only as needed to operate and improve the Service,
              including AI generation and support/debug operations.
            </li>
            <li>
              You must not upload unlawful or infringing content.
            </li>
          </ul>

          <h2>6. Subscription Terms</h2>
          <p>
            Tend offers auto-renewing subscriptions through Apple In-App Purchase, including weekly and annual plans.
          </p>
          <ul>
            <li>Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period.</li>
            <li>Your Apple account is charged for renewal within 24 hours before the current period ends.</li>
            <li>Free trial eligibility, trial length, and plan availability may vary by offer and region.</li>
            <li>Manage or cancel subscriptions in your Apple ID account settings.</li>
            <li>Refunds are handled by Apple according to Apple policies.</li>
          </ul>

          <h2>7. Acceptable Use</h2>
          <p>You agree not to:</p>
          <ul>
            <li>Use Tend in violation of law or regulation.</li>
            <li>Attempt unauthorized access to systems, data, or accounts.</li>
            <li>Reverse engineer, scrape, or interfere with normal Service operation.</li>
            <li>Use Tend to transmit harmful code, abusive content, or spam.</li>
          </ul>

          <h2>8. Availability and Changes</h2>
          <ul>
            <li>We may update, modify, suspend, or discontinue features at any time.</li>
            <li>We may release fixes, enhancements, and changes to models/providers as needed.</li>
            <li>We do not guarantee uninterrupted availability in all regions or on all devices.</li>
          </ul>

          <h2>9. Intellectual Property</h2>
          <ul>
            <li>All Tend branding, software, design, and non-user content are owned by Tend or its licensors.</li>
            <li>These Terms do not transfer any ownership rights to you.</li>
          </ul>

          <h2>10. Termination</h2>
          <p>
            You may stop using Tend at any time. We may suspend or terminate access if you violate these Terms or if
            needed to protect users, legal compliance, or service integrity.
          </p>

          <h2>11. Warranty Disclaimer</h2>
          <p>
            Tend is provided on an "as is" and "as available" basis to the maximum extent permitted by law. We do not
            guarantee that the Service will be error-free, uninterrupted, or suitable for every purpose.
          </p>

          <h2>12. Limitation of Liability</h2>
          <p>
            To the maximum extent permitted by law, Tend and its operator will not be liable for indirect, incidental,
            special, consequential, or punitive damages, or loss of data, revenue, or profits arising from use of the Service.
          </p>

          <h2>13. Indemnification</h2>
          <p>
            You agree to indemnify and hold Tend harmless from claims, liabilities, damages, and expenses arising from
            your misuse of the Service, violation of these Terms, or violation of applicable law.
          </p>

          <h2>14. Governing Law</h2>
          <p>
            These Terms are governed by applicable laws of the United States and the state laws that apply to Tend&apos;s
            operations, without regard to conflict-of-law principles, except where local law requires otherwise.
          </p>

          <h2>15. Changes to These Terms</h2>
          <p>
            We may revise these Terms from time to time. Continued use after changes become effective means you accept
            the updated Terms.
          </p>

          <h2>16. Contact</h2>
          <p>
            Legal and terms inquiries: <a className="inline-link" href="mailto:tend@keeganryan.co">tend@keeganryan.co</a>
          </p>

          <p className="footer-note">
            Related pages: <Link className="inline-link" href="/privacy">Privacy Policy</Link> and{" "}
            <Link className="inline-link" href="/support">Support</Link>.
          </p>
        </article>
      </section>
    </SiteShell>
  );
}
