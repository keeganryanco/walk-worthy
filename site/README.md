# Tend Legal Site

Minimal Next.js site for App Store-required URLs.

## Routes
- `/privacy`
- `/support`
- `/api/v1/journey-bootstrap` (POST)
- `/api/v1/journey-package` (POST)
- `/api/v1/localize` (POST)
- `/api/v1/attribution` (POST, app-internal)

## Local development
```bash
pnpm install
pnpm dev
```

Optional analytics (Google Analytics 4):

```bash
export NEXT_PUBLIC_GA_ID=G-XXXXXXXXXX
```

## Build
```bash
pnpm build
pnpm start
```

## Deploy to Vercel
1. Import this repo in Vercel.
2. Set Root Directory to `site`.
3. Build command: `pnpm build`
4. Output: default Next.js output
5. Deploy.

## AI gateway environment variables
Copy `.env.example` values into Vercel Project Settings -> Environment Variables.

Required for AI orchestration:
- `OPENAI_API_KEY`
- `GEMINI_API_KEY`

Optional:
- `TEND_APP_SHARED_SECRET` (recommended)
- `OPENAI_DEVOTIONAL_MODEL` (default `gpt-5.4`; scripture/reflection/prayer/arc)
- `OPENAI_ACTION_MODEL` (default `gpt-5.1`; action question and suggestions)
- `OPENAI_REPAIR_MODEL` (default `OPENAI_DEVOTIONAL_MODEL`)
- `OPENAI_UTILITY_MODEL` (default `OPENAI_ACTION_MODEL`)
- `OPENAI_PRIMARY_MODEL` (default `gpt-5-mini`)
- `OPENAI_ESCALATION_MODEL` (default `gpt-5.1`)
- `GEMINI_PRIMARY_MODEL` (default `gemini-2.5-flash`)
- `OPENAI_TRANSLATION_MODEL` (default: `OPENAI_PRIMARY_MODEL`)
- `GEMINI_TRANSLATION_MODEL` (default: `GEMINI_PRIMARY_MODEL`)
- `LOCALIZATION_CACHE_TTL_SECONDS` (default `604800`)
- `TIKTOK_EVENTS_ACCESS_TOKEN` (required for TikTok attribution relay)
- `TIKTOK_CRM_EVENT_SET_ID` (required for TikTok attribution relay; CRM Event Set ID from TikTok Events Manager)
- `TIKTOK_EVENTS_SOURCE` (optional, default `crm`)
- `TIKTOK_EVENTS_TEST_EVENT_CODE` (optional; use while validating in TikTok Test Events)
- `TIKTOK_EVENTS_API_URL` (optional override; default `https://business-api.tiktok.com/open_api/v1.3/event/track/`)

### TikTok attribution relay (app funnel)

The iOS app forwards key lifecycle events to `POST /api/v1/attribution`, and this route relays mapped conversion events to TikTok when the env vars above are set:

- `onboarding_started` → custom TikTok event `OnboardingStarted`
- `onboarding_completed` → `CompleteRegistration`
- `free_trial_started` → `StartTrial`
- `trial_converted_paid` → `Subscribe`

Notes:
- The relay is server-side and uses your Vercel environment variables (no TikTok secret in the iOS binary).
- TikTok optimization uses standard events; custom events are report/audience signals only.
- For best attribution, set up TikTok CRM/Event mapping in Events Manager and map funnel events to standard events there.

## API contract (MVP)

### `POST /api/v1/journey-bootstrap`

Headers:
- `Content-Type: application/json`
- `x-tend-app-key: <TEND_APP_SHARED_SECRET>` (if configured)

Body:
- `name`
- `prayerIntentText`
- `goalIntentText`
- `reminderWindow`

Response:
- `bootstrap`:
  - `journeyTitle`
  - `journeyCategory`
  - `themeKey` (`basic | faith | patience | peace | resilience | community | discipline | healing | joy | wisdom`)
  - `initialMemory`
  - `initialPackage`
- `meta` (`provider`, `model`, `escalated`, `fallbackUsed`, `generatedAt`)

### `POST /api/v1/journey-package`

Headers:
- `Content-Type: application/json`
- `x-tend-app-key: <TEND_APP_SHARED_SECRET>` (if configured)

Body:
- `profile`
- `journey` (supports `themeKey`)
- optional `memory`
- optional `recentEntries`
- optional `followThroughContext`
- optional `cycleCount`
- optional `completionCount`
- optional `recentJourneySignals`
- optional `dateISO`

Response:
- `package` (reflection/scripture/prayer/step payload)
- `meta` (`provider`, `model`, `escalated`, `fallbackUsed`, `generatedAt`)

### `POST /api/v1/localize`

Headers:
- `Content-Type: application/json`
- `x-tend-app-key: <TEND_APP_SHARED_SECRET>` (if configured)

Body:
- `domain` (`posthog_onboarding | revenuecat_paywall`)
- `targetLocale` (`en | es | pt-br | de | ja | ko`; normalized server-side)
- `strings` (key-value map of source English text)
- optional `telemetry`:
  - `distinctID`
  - `appVersion`
  - `buildNumber`
  - `platform`

Response:
- `translated` (key-value map with best-effort localized values)
- `meta` (`provider`, `model`, `cached`, `fallbackUsed`)

### `POST /api/v1/attribution` (app-internal)

Headers:
- `Content-Type: application/json`
- `x-tend-app-key: <TEND_APP_SHARED_SECRET>` (if configured)

Body:
- `event` (for example `onboarding_started`, `onboarding_completed`, `free_trial_started`, `trial_converted_paid`)
- optional `eventID`
- optional `timestamp` (ISO-8601)
- optional `properties` (`currency`, `value`, `product_id`, etc.)
- optional `telemetry`:
  - `distinctID`
  - `appVersion`
  - `buildNumber`
  - `platform`

Response:
- `ok`
- `relay` (`delivered` boolean; reason when not delivered)

After deploy, set App Store URLs to:
- Privacy Policy URL: `https://<vercel-domain>/privacy`
- Support URL: `https://<vercel-domain>/support`
