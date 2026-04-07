# RFC-0006: Localization and Multilingual AI

- Status: Accepted and Implemented through Phase C
- Date: 2026-04-07
- Owners: iOS app + AI gateway

## Context

Tend launched with English-only static UI and English-first AI assumptions.
We need multilingual support without breaking onboarding, paywall, or AI safety guardrails.

## Decision

Adopt a phased rollout:

1. Phase A:
   - Add in-app language selector (`system`, `en`, `es`) in Settings.
   - Persist language and apply runtime locale at app root.
   - Add `en.lproj` + `es.lproj` resources for core screens.
   - Send `languageCode` + `localeIdentifier` in bootstrap and daily AI requests.
   - Require language in backend prompt builders.
   - Make fallback/validation language-aware for Spanish where logic was English-only.

2. Phase B:
   - Add backend translation endpoint with caching.
   - Translate PostHog/RevenueCat remote copy for non-English locales.
   - Support manual override keys for legal/brand-sensitive paywall lines.

3. Phase C:
   - Glossary and quality controls for devotional terminology.
   - Telemetry on translation failures and fallback-to-English rate.
   - Expand to additional languages after Spanish stability (`pt-BR` first).

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

## Implemented in Phase B

### Backend localization endpoint

- Added `POST /api/v1/localize` in `site/` with existing shared-secret auth pattern.
- Added in-memory translation cache keyed by domain + locale + source hash.
- Added provider orchestration:
  - OpenAI primary
  - Gemini fallback
  - source-text fallback on provider/output failure
- Added strict placeholder/key preservation checks before accepting translated values.

### Remote copy wiring in iOS

- PostHog onboarding `copy_overrides` now pass through remote localization when locale is non-English.
- RevenueCat paywall copy now supports:
  - machine translation for non-legal fields
  - manual locale override keys for legal/brand-sensitive fields.
- Legal-sensitive policy preserved:
  - `cta` and `footnote` stay English unless explicit locale override is present.

## Implemented in Phase C

### Locale expansion and language routing

- Added `pt-BR` as a supported app language option in Settings.
- Added `pt-BR.lproj` resource with key parity to Phase A/B core string set.
- Extended locale normalization across iOS and backend:
  - AI generation language: `en | es | pt`
  - remote-copy translation locale: `en | es | pt-br`

### AI generation quality for Portuguese (Brazil)

- Extended bootstrap and daily prompt language targeting to Portuguese (Brazil).
- Extended fallback copy/chip banks and validation heuristics to Portuguese:
  - first-person prayer checks
  - reflection/question normalization
  - fallback question/chip behavior

### Glossary guardrails (soft enforcement)

- Added domain+locale glossary hints in localization prompt builder.
- Added post-translation soft normalization for devotional/Bible-adjacent terminology.
- Guardrail design is non-blocking and fail-open (source fallback remains available).

### Translation telemetry contract

- Extended `/api/v1/localize` to accept optional telemetry:
  - `telemetry.distinctID`
  - `telemetry.appVersion`
  - `telemetry.buildNumber`
  - `telemetry.platform`
- Server now emits PostHog `localization_request` events for:
  - success/failure/unauthorized/invalid payload
  - provider/model
  - cached/fallback flags
  - locale/domain/key-count
- iOS client now emits `localization_request` analytics events for:
  - success/failure
  - fallback-to-English path usage
  - locale/domain/key-count/provider/cached

## Guardrails preserved

- First-person prayer requirement preserved.
- Existing theological/safety constraints preserved.
- Onboarding fixed first-journey block order unchanged.

## Known limitations after Phase C

- Existing generated tend/journey content is not retroactively translated.
- Legal-sensitive paywall lines (`cta`, `footnote`) require explicit locale overrides to avoid English fallback.
- Translation cache is in-memory per deployment (not persistent/shared store).
- `pt-BR.lproj` currently ships with key parity and can be iteratively refined for copy polish.

## Next actions

1. Add persisted/shared translation cache (Redis) if translation volume grows.
2. Add dashboard views for `localization_request` success/fallback rates by locale.
3. Refine Portuguese static copy quality in `pt-BR.lproj`.
4. Evaluate next locale after Spanish + Portuguese stabilization.
