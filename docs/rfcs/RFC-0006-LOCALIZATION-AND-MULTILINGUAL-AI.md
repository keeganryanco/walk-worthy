# RFC-0006: Localization and Multilingual AI

- Status: Accepted (Phase A shipped)
- Date: 2026-04-06
- Owners: iOS app + AI gateway

## Context

Tend launched with English-only static UI and English-first AI assumptions.
We need multilingual support without breaking onboarding, paywall, or AI safety guardrails.

## Decision

Adopt a phased rollout:

1. Phase A (now):
   - Add in-app language selector (`system`, `en`, `es`) in Settings.
   - Persist language and apply runtime locale at app root.
   - Add `en.lproj` + `es.lproj` resources for core screens.
   - Send `languageCode` + `localeIdentifier` in bootstrap and daily AI requests.
   - Require language in backend prompt builders.
   - Make fallback/validation language-aware for Spanish where logic was English-only.

2. Phase B (next):
   - Add backend translation endpoint with caching.
   - Translate PostHog/RevenueCat remote copy for non-English locales.
   - Support manual override keys for legal/brand-sensitive paywall lines.

3. Phase C (quality/scale):
   - Glossary and quality controls for devotional terminology.
   - Telemetry on translation failures and fallback-to-English rate.
   - Expand to additional languages after Spanish stability.

## Implemented in Phase A

### iOS

- `AppLanguage` introduced with persisted `@AppStorage` key: `app.language`.
- Root locale wiring applied in `WalkWorthyApp` with `.environment(\.locale, ...)`.
- Settings language picker added.
- Core key-based localization helper `L10n` used for runtime string paths.
- Core string localization resources added:
  - `WalkWorthy/Resources/en.lproj/Localizable.strings`
  - `WalkWorthy/Resources/es.lproj/Localizable.strings`

### AI request plumbing

- iOS request payloads include:
  - `languageCode`
  - `localeIdentifier`
- Added to both:
  - bootstrap request
  - daily package request

### Backend

- Request schemas updated to accept language fields on:
  - `/api/v1/journey-bootstrap`
  - `/api/v1/journey-package`
- Prompt builders updated to explicitly require output language (`en`/`es`).
- Fallback and validation paths updated with Spanish-aware handling.

## Guardrails preserved

- First-person prayer requirement preserved.
- Existing theological/safety constraints preserved.
- Onboarding fixed first-journey block order unchanged.

## Known limitations after Phase A

- PostHog and RevenueCat remote copy are not auto-translated yet.
- If remote copy is English-only, non-English users may still see English in those remote fields.
- Dynamic/generated phrase coverage in deep-edge screens remains iterative.

## Next actions

1. Build translation endpoint + cache in `site/`.
2. Route PostHog/RevenueCat strings through translation layer for non-English locales.
3. Add manual override path for paywall legal text.
4. Add translation/fallback telemetry dashboards.
