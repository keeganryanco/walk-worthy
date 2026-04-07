# App Store Metadata Requirements (iOS)

_As of March 12, 2026, based on Apple App Store Connect Help._

## A. Required app-level fields (App Information)
1. **Name** (required, localized)
- 2-30 characters
- Proposed: `Tend`

2. **Subtitle** (localized; used on product page)
- Up to 30 characters
- Proposed: `pray. act. grow.`

3. **Primary category** (required)
- Proposed candidate: `Lifestyle`

4. **Content rights** (required)
- Must declare rights ownership

5. **Age rating questionnaire** (required)
- Must be completed before submission

## B. Required version-level fields (Platform Version Information)
1. **Screenshots** (required, localized)
- Must upload required screenshot sets for supported devices

2. **Description** (required, localized)
- Up to 4000 characters

3. **Keywords** (required, localized)
- Up to 100 bytes
- Comma-separated

4. **Support URL** (required, localized)
- Must include protocol (`https://`)
- Must lead to actual contact information (address/email/phone as applicable)

5. **Copyright** (required)
- Format example: `2026 Your Name or Company`

6. **Version number** (required)
- Semantic version label shown to users

## C. Required App Privacy fields
1. **Privacy Policy URL** (required for all iOS apps)
- Must be live URL
- Can be localized

2. **App Privacy questionnaire responses** (required)
- Must disclose data collected by app and third-party SDKs
- Must be kept up to date as practices change

## D. Required App Review fields
1. **Review contact** (required)
- Name
- Email
- Phone

2. **Review notes** (not always required, strongly recommended)
- Up to 4000 bytes
- Should include reviewer instructions and test path

3. **Sign-in credentials** (required only if app needs login)
- Not applicable for current no-auth MVP

## E. In-App Purchase / Subscription metadata (required for monetization)
For each subscription product:
1. Reference name (required, internal)
2. Product ID (required)
3. Duration and price (required)
4. Localized display name (required)
- 2-30 characters
5. Localized description (required)
- Up to 45 characters
6. App Review screenshot (required)
7. Availability + storefront pricing (required)

## F. Suggested initial metadata draft for Tend
1. App Name: `Tend`
2. Subtitle: `pray. act. grow.`
3. Promotional Text (optional, up to 170 chars):
- `Turn prayer into one faithful next step each day.`
4. Description (draft opening):
- `Tend helps you pray, take one concrete step, and reflect on what changes over time.`
5. Keyword starter set (must fit 100 bytes):
- `prayer,christian,faith,devotional,reflection,discipline`
6. Support email contact (for support destination page):
- `tend@keeganryan.co`

## F2. Subscription metadata draft
1. Product strategy:
- Annual subscription with 3-day introductory free trial (MVP default)
- Weekly subscription without trial as secondary option
2. Initial price points:
- `$35/year`
- `$5.99/week`
3. Required text in paywall:
- Billing period, trial duration, auto-renew language, cancel-anytime path
4. Required controls:
- `Restore Purchases` and link to Terms/Privacy

## G. URL requirements summary
- **Support URL** must provide real user contact info and include full protocol.
- **Privacy Policy URL** is required for iOS and must remain current.
- **Marketing URL** is optional but recommended for brand trust.

## H. Review notes recommendations for this app
Use this template in App Review Notes:
1. “This app is local-first and does not require account creation.”
2. “All core features are testable without login or external services.”
3. “To test premium flows, use StoreKit sandbox; restore purchases is in Settings > Subscription.”
4. “Scripture snippets are AI-generated with reference constraints and are intended for devotional guidance.”
5. “No health, financial, or guaranteed outcome claims are presented in app content.”

## Sources (Apple)
- https://developer.apple.com/help/app-store-connect/reference/app-information
- https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties
- https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information
