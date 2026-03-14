export const metadata = {
  title: "Tend Privacy Policy"
};

export default function PrivacyPage() {
  return (
    <main className="wrapper">
      <article className="card prose">
        <h1>Privacy Policy</h1>
        <p>Last updated: March 12, 2026</p>

        <h2>Overview</h2>
        <p>
          Tend is designed as a local-first prayer app. For MVP, your prayer content is stored on your device.
        </p>

        <h2>Data We Collect</h2>
        <ul>
          <li>Prayer entries, reflections, and journey data you create in the app (stored locally on device).</li>
          <li>Purchase status managed by Apple for subscription access.</li>
        </ul>

        <h2>Data Sharing</h2>
        <p>We do not sell your personal information. We do not run a user account backend for MVP.</p>

        <h2>Third Parties</h2>
        <p>
          Subscription processing is handled by Apple through StoreKit and App Store billing.
        </p>

        <h2>Your Choices</h2>
        <ul>
          <li>You may delete the app to remove local app data from your device.</li>
          <li>You may manage or cancel subscriptions from your Apple ID settings.</li>
        </ul>

        <h2>Contact</h2>
        <p>
          For privacy questions, contact <a href="mailto:keegan.ryan@keeganryan.co">keegan.ryan@keeganryan.co</a>.
        </p>
      </article>
    </main>
  );
}
