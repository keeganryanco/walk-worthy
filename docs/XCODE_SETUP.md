# Xcode Setup and Run Guide

## Minimum needed to run in Xcode
1. Xcode installed and selected (`xcode-select -p`).
2. iOS Simulator runtime installed (from Xcode Components or CLI).
3. Generated project (`WalkWorthy.xcodeproj`).

## Fast path
Run from repo root:

```bash
./scripts/prepare_assets_for_ios.sh
./scripts/bootstrap_xcode.sh
```

Then open:

```bash
open WalkWorthy.xcodeproj
```

## If simulator runtime is missing
Install via CLI:

```bash
xcodebuild -downloadPlatform iOS
```

Or in Xcode:
- `Xcode > Settings > Components`
- Install latest `iOS Simulator` runtime

## Verify readiness

```bash
./scripts/xcode_ready_check.sh
```

## Run in Xcode
1. Open `WalkWorthy.xcodeproj`.
2. Scheme: `WalkWorthy`.
3. Destination: iPhone simulator (e.g., latest iPhone runtime).
4. Press Run (`Cmd+R`).

## Configure AI gateway (once Vercel is deployed)
Use the local xcconfig (recommended, one-time):
1. Copy `Config/LocalSecrets.example.xcconfig` to `Config/LocalSecrets.xcconfig`.
2. Fill in:
   - `TENDAI_BASE_URL` = your Vercel domain, e.g. `https://<your-vercel-domain>`.
   - `TENDAI_APP_KEY` = same value as Vercel `TEND_APP_SHARED_SECRET`.
   - `POSTHOG_API_KEY` = PostHog project key (`phc_...`).
   - `POSTHOG_HOST` = `https://us.i.posthog.com` (US cloud).
   - `REVENUECAT_IOS_PUBLIC_SDK_KEY` = RevenueCat iOS public SDK key (`appl_...`).
   - `REVENUECAT_ENTITLEMENT_ID` = `premium`.
3. Regenerate project:

```bash
xcodegen generate
```

Notes:
- If `TENDAI_BASE_URL` is blank, app falls back to local template generation automatically.
- `Config/LocalSecrets.xcconfig` is gitignored; this is persistent on your machine and used by Xcode GUI and CLI builds.

## Fresh Onboarding Retest (recommended)
Use this when you want onboarding from a clean slate and no duplicate test-runner app icon:

```bash
./scripts/sim_fresh_start.sh
```

Optional simulator override:

```bash
./scripts/sim_fresh_start.sh "iPhone 17 Pro"
```

## StoreKit local testing
Use the product IDs already scaffolded in app code:
- `co.keeganryan.tend.premium.weekly`
- `co.keeganryan.tend.premium.annual`

You can attach a StoreKit config file to the scheme in Xcode:
- `Product > Scheme > Edit Scheme... > Run > Options > StoreKit Configuration`

## Brand asset handoff
Place logos/icons/fonts here:
- `design/brand-assets/logos/`
- `design/brand-assets/icons/`
- `design/brand-assets/fonts/`

Prepare all runtime assets:

```bash
./scripts/prepare_assets_for_ios.sh
```
