# PATCH-006: Vercel AI Gateway + iOS Wiring

## Goal
Add a secure-ish MVP backend surface for AI orchestration (Vercel `site/` subfolder) and wire iOS to consume it with deterministic local fallback.

## Scope
- Added Next.js API route:
  - `POST /api/v1/journey-package`
- Added provider orchestration in `site/lib/ai/*`:
  - OpenAI primary (`gpt-5-mini`)
  - Gemini secondary (`gemini-2.5-flash`)
  - OpenAI escalation (`gpt-5.1`)
  - deterministic template fallback when generation/parsing fails
- Added payload validation + scripture reference normalization on backend.
- Added optional shared-secret header auth (`x-tend-app-key`) via `TEND_APP_SHARED_SECRET`.
- Added iOS remote provider:
  - `BackendDailyJourneyPackageProvider`
  - Uses `TENDAIBaseURL` and `TENDAIAppKey` from app Info.plist/build settings.
  - Falls back to template path if gateway is unset/unavailable.
- Added deployment and setup docs:
  - `docs/VERCEL_AI_GATEWAY_DEPLOY.md`
  - updates to `docs/VERCEL_DEPLOY.md`, `docs/XCODE_SETUP.md`, `site/README.md`.

## Validation
- `pnpm --dir site build` passes.
- `xcodebuild -project WalkWorthy.xcodeproj -scheme WalkWorthy -destination 'platform=iOS Simulator,name=iPhone 17' test` passes.
