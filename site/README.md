# Tend Legal Site

Minimal Next.js site for App Store-required URLs.

## Routes
- `/privacy`
- `/support`
- `/api/v1/journey-bootstrap` (POST)
- `/api/v1/journey-package` (POST)

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
- `OPENAI_PRIMARY_MODEL` (default `gpt-5-mini`)
- `OPENAI_ESCALATION_MODEL` (default `gpt-5.1`)
- `GEMINI_PRIMARY_MODEL` (default `gemini-2.5-flash`)

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
- optional `cycleCount`
- optional `completionCount`
- optional `recentJourneySignals`
- optional `dateISO`

Response:
- `package` (reflection/scripture/prayer/step payload)
- `meta` (`provider`, `model`, `escalated`, `fallbackUsed`, `generatedAt`)

After deploy, set App Store URLs to:
- Privacy Policy URL: `https://<vercel-domain>/privacy`
- Support URL: `https://<vercel-domain>/support`
