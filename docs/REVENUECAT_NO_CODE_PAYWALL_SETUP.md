# RevenueCat Code Paywall Setup (Tend)

Tend uses a **custom SwiftUI paywall** (code paywall). RevenueCat is still the remote control for:
- entitlement state,
- package/pricing source,
- paywall mode on/off,
- copy/config A/B via offering metadata.

## What Is Wired In The App

- The app fetches `offerings.current` from RevenueCat.
- It renders subscription options from that offering's packages.
- Purchase and restore run through RevenueCat SDK.
- Paywall mode is controlled remotely by offering metadata key `paywall_mode`:
  - `disabled`
  - `first_tend_review_then_paywall`
  - `session_gate` (currently treated as off in app policy)
- Paywall copy/config is read from offering metadata (keys below).

## Metadata Keys Supported By The App

Set these on the active offering (RevenueCat -> Product catalog -> Offerings -> `<offering>` -> Metadata):

```json
{
  "paywall_mode": "first_tend_review_then_paywall",
  "paywall_headline": "Don’t break the commitment you just made.",
  "paywall_subheadline": "Start your 3-day free trial to keep growing daily.",
  "paywall_cta": "Start 3-Day Free Trial",
  "paywall_annual_badge": "Best Value",
  "paywall_footnote": "Cancel anytime in Settings.",
  "default_package": "annual"
}
```

`default_package` accepts:
- `annual`
- `weekly`
- a full product ID (for example `co.keeganryan.tend.premium.annual`)

### Locale-specific overrides (Phase B/C)

For Spanish, the app supports explicit suffix overrides:

- `paywall_headline_es`
- `paywall_subheadline_es`
- `paywall_cta_es`
- `paywall_annual_badge_es`
- `paywall_footnote_es`

For Portuguese (Brazil), the app supports explicit suffix overrides:

- `paywall_headline_pt_br`
- `paywall_subheadline_pt_br`
- `paywall_cta_pt_br`
- `paywall_annual_badge_pt_br`
- `paywall_footnote_pt_br`

Resolution order for non-English app locales (`es`, `pt-BR`):
1. Use explicit `*_es` key if present.
   - For `pt-BR`, use explicit `*_pt_br` key if present.
2. If missing and field is non-legal (`headline`, `subheadline`, `annual_badge`), app uses backend machine translation.
3. If missing and field is legal-sensitive (`cta`, `footnote`), app keeps English source text (no machine translation).

## Turn Paywall On / Off (No App Release)

1. Open RevenueCat -> Offerings -> active offering metadata.
2. Set:
   - ON: `"paywall_mode": "first_tend_review_then_paywall"`
   - OFF: `"paywall_mode": "disabled"`
3. Save.
4. Relaunch app or run Settings -> Subscription -> Reload Products.

## A/B Messaging In RevenueCat

Use separate offerings with different metadata copy and split traffic via RevenueCat Experiments.

1. Create offering A and offering B (same products/packages).
2. Set different metadata values (`paywall_headline`, `paywall_subheadline`, `paywall_cta`, etc.).
3. Create an experiment in RevenueCat that routes users between these offerings.
4. Monitor conversion in RevenueCat.

## A/B Pricing In RevenueCat

Pricing tests should be run with different products/packages per offering.

1. Create pricing product set in App Store Connect (example: alternate weekly/annual product IDs).
2. Import products into RevenueCat.
3. Attach pricing set A to offering A, pricing set B to offering B.
4. Run RevenueCat experiment across A/B offerings.
5. The app automatically renders whichever package set RevenueCat returns.

## Important Notes

- App-side paywall trigger timing is still controlled by `MonetizationPolicy` and first-tend milestones.
- RevenueCat controls *whether* paywall should be active (`paywall_mode`) and *how* it is presented (copy/packages).
- Offering metadata is safer than hardcoding strings in app for rapid copy tests.

## Troubleshooting

- Confirm iOS public SDK key and entitlement ID are set in `Config/LocalSecrets.xcconfig`.
- Confirm offering has at least one package.
- Confirm products are active in App Store Connect and imported into RevenueCat.
- If stale behavior persists, uninstall/reinstall app and reload products.
