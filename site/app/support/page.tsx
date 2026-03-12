export const metadata = {
  title: "Walk Worthy Support"
};

export default function SupportPage() {
  return (
    <main className="wrapper">
      <article className="card prose">
        <h1>Support</h1>
        <p>If you need help with Walk Worthy, email:</p>
        <p>
          <a href="mailto:keegan.ryan@keeganryan.co">keegan.ryan@keeganryan.co</a>
        </p>

        <h2>Include in your message</h2>
        <ul>
          <li>iPhone model and iOS version</li>
          <li>App version/build number</li>
          <li>A short description of the issue and steps to reproduce</li>
        </ul>
      </article>
    </main>
  );
}
