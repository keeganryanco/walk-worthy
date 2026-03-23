import Link from "next/link";
import { SiteShell } from "../_components/site-shell";

export const metadata = {
  title: "Tend Privacy Policy"
};

export default function PrivacyPage() {
  return (
    <SiteShell current="privacy">
      <section className="panel legal">
        <article>
          <h1>Privacy Policy</h1>
          <p className="meta">Last updated: March 23, 2026</p>

          <p>
            This Privacy Policy explains how Tend ("Tend," "we," "us," or "our") collects, uses, discloses, and
            safeguards information when you use the Tend iOS app and this website.
          </p>

          <p>
            Tend is built as a local-first experience. Most prayer and journey content is stored on your device using
            Apple frameworks. We also use cloud services for analytics, subscriptions, and AI-generated content.
          </p>

          <h2>1. Scope</h2>
          <p>This policy applies to:</p>
          <ul>
            <li>The Tend iOS app.</li>
            <li>This website and support/legal pages.</li>
            <li>Related support communications sent to our support email.</li>
          </ul>

          <h2>2. Information We Collect</h2>

          <h3>2.1 Information you provide in the app</h3>
          <ul>
            <li>Name you enter in onboarding.</li>
            <li>Prayer intent and goal text you enter during onboarding and journey setup.</li>
            <li>Journey entries, reflections, action steps, and completion updates you create.</li>
            <li>Reminder preferences (such as preferred reminder window/time).</li>
          </ul>

          <h3>2.2 Information processed for subscriptions</h3>
          <ul>
            <li>
              Subscription purchase and entitlement status are processed through Apple and RevenueCat.
            </li>
            <li>
              Tend receives subscription status/entitlement metadata needed to unlock premium features and restore
              purchases.
            </li>
            <li>
              Tend does not receive your full payment card number. Apple handles billing and payment credentials.
            </li>
          </ul>

          <h3>2.3 Analytics and diagnostics</h3>
          <ul>
            <li>
              We use PostHog to collect product analytics such as app events (for example: onboarding completed,
              journey created, paywall shown), app version/build, platform, and a pseudonymous device/app identifier.
            </li>
            <li>
              We configure analytics to avoid sending free-form prayer/reflection text as analytics properties.
            </li>
          </ul>

          <h3>2.4 Notification data</h3>
          <ul>
            <li>We request notification permission to deliver reminders if you opt in.</li>
            <li>Notification authorization state and scheduling preferences are stored for reminder functionality.</li>
          </ul>

          <h3>2.5 AI generation request data</h3>
          <ul>
            <li>
              When AI generation is requested, Tend sends selected journey context to our AI gateway endpoint
              (hosted on Vercel), including prayer/goal context, journey metadata, and recent journey signals needed
              to generate daily reflection content.
            </li>
            <li>
              The gateway may call one or more model providers (currently OpenAI and/or Google Gemini, depending on
              configured provider availability) to generate output.
            </li>
          </ul>

          <h2>3. How We Use Information</h2>
          <ul>
            <li>Provide core app functionality (journeys, tend flow, reminders, and progress).</li>
            <li>Generate personalized daily reflection/prayer/action packages.</li>
            <li>Maintain and improve app reliability, UX, and product quality through analytics.</li>
            <li>Process subscriptions, entitlement checks, purchases, and restores.</li>
            <li>Respond to support and legal requests.</li>
            <li>Protect against fraud, abuse, misuse, and security incidents.</li>
          </ul>

          <h2>4. Where Data Is Stored</h2>
          <ul>
            <li>
              Local app content is primarily stored on your device via SwiftData/local app storage.
            </li>
            <li>Analytics events are processed by PostHog cloud services.</li>
            <li>Subscription metadata is processed by Apple and RevenueCat.</li>
            <li>AI generation requests are processed through our Vercel-hosted API gateway and model providers.</li>
          </ul>

          <h2>5. Data Sharing and Disclosure</h2>
          <p>We do not sell your personal data.</p>
          <p>We share data only as needed with service providers and platform partners to operate Tend:</p>
          <ul>
            <li>Apple (StoreKit/App Store subscriptions and billing).</li>
            <li>RevenueCat (subscription entitlement and purchase infrastructure).</li>
            <li>PostHog (analytics and product telemetry).</li>
            <li>Vercel (hosting and API infrastructure).</li>
            <li>OpenAI and/or Google Gemini APIs (AI generation requests).</li>
          </ul>

          <p>
            We may also disclose information when required by law, to enforce our Terms, or to protect rights,
            safety, and security.
          </p>

          <h2>6. AI and Model Processing Disclosures</h2>
          <ul>
            <li>
              Tend uses AI APIs to generate personalized reflections, paraphrased scripture references, prayer text,
              and suggested small-step actions.
            </li>
            <li>
              AI output may be inaccurate or incomplete and should be reviewed by users before relying on it.
            </li>
            <li>
              Do not submit highly sensitive personal data you do not want processed by third-party AI providers.
            </li>
          </ul>

          <div className="notice" role="note" aria-label="AI use notice">
            AI-generated content in Tend is provided for faith-based reflection and habit support, not for medical,
            legal, or mental-health diagnosis or emergency guidance.
          </div>

          <h2>7. Data Retention</h2>
          <ul>
            <li>Local journey content remains on your device until you delete it or uninstall the app.</li>
            <li>Analytics and provider records are retained according to provider retention settings and legal needs.</li>
            <li>Support emails are retained as needed to resolve requests and satisfy legal obligations.</li>
          </ul>

          <h2>8. Your Choices and Controls</h2>
          <ul>
            <li>You can delete app content from within the app and/or by uninstalling the app.</li>
            <li>You can disable notifications in iOS Settings at any time.</li>
            <li>You can manage or cancel subscriptions in your Apple ID subscription settings.</li>
            <li>You may contact us regarding privacy requests using the email below.</li>
          </ul>

          <h2>9. Children&apos;s Privacy</h2>
          <p>
            Tend is not directed to children under 13, and we do not knowingly collect personal information from
            children under 13. If you believe a child has provided personal information, contact us and we will
            address the request.
          </p>

          <h2>10. Security</h2>
          <p>
            We use reasonable administrative, technical, and organizational measures designed to protect data.
            However, no method of transmission or storage is completely secure.
          </p>

          <h2>11. International Processing</h2>
          <p>
            Service providers may process data in jurisdictions outside your state or country. By using Tend, you
            understand that information may be processed in those jurisdictions, subject to applicable law.
          </p>

          <h2>12. Changes to This Policy</h2>
          <p>
            We may update this Privacy Policy from time to time. If we make material changes, we will update the
            "Last updated" date and, where appropriate, provide additional notice.
          </p>

          <h2>13. Contact</h2>
          <p>
            Privacy questions or requests: <a className="inline-link" href="mailto:keegan.ryan@keeganryan.co">keegan.ryan@keeganryan.co</a>
          </p>

          <p className="footer-note">
            Related pages: <Link className="inline-link" href="/terms">Terms of Use</Link> and{" "}
            <Link className="inline-link" href="/support">Support</Link>.
          </p>
        </article>
      </section>
    </SiteShell>
  );
}
