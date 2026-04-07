# Localization QA Matrix (2026-04-07)

Scope: Phase C multilingual quality pass (`en`, `es`, `pt-BR`) for core app flows, remote copy translation, and telemetry.

## Locales

- `English (en)` baseline
- `Español (es)`
- `Português (Brasil) (pt-BR)`

## Core UI Matrix

- [ ] Settings language switching works:
  - `System -> Español -> English -> Português (Brasil) -> English`
- [ ] Language preference persists after app relaunch.
- [ ] Tab labels/localized core chrome update immediately without restart.
- [ ] Core onboarding labels/buttons render localized (or safe fallback) without layout break.
- [ ] Home/Journal/Settings section headers and primary actions render localized (or safe fallback).
- [ ] Paywall static/fallback labels render localized (or safe fallback) in supported locales.

## Dynamic Type + Clipping Matrix

- [ ] Dynamic Type: Default / Large / Extra Large / Accessibility Large pass on:
  - onboarding primary CTA
  - paywall CTA
  - settings language picker row
  - journal entry section headers
- [ ] No clipped/truncated critical CTA text on onboarding and paywall.
- [ ] Suggested step chips remain legible and tappable with larger text sizes.
- [ ] No overlap regressions for key controls (continue buttons, nav, modal controls).

## AI Generation Language Matrix

- [ ] New journey bootstrap in `es` returns Spanish user-facing fields.
- [ ] New journey bootstrap in `pt-BR` returns Portuguese user-facing fields.
- [ ] Daily package in `es` returns Spanish reflection/prayer/question/chips.
- [ ] Daily package in `pt-BR` returns Portuguese reflection/prayer/question/chips.
- [ ] Existing stored/generated content is unchanged (no retroactive translation expected).
- [ ] Fallback path remains functional and safe if model/normalization fails.

## PostHog Remote Copy Translation Matrix

- [ ] PostHog `copy_overrides` authored in English.
- [ ] `es` app locale renders translated overrides.
- [ ] `pt-BR` app locale renders translated overrides.
- [ ] If `/api/v1/localize` fails, app falls back to English overrides without blocking flow.

## RevenueCat Paywall Copy Matrix

- [ ] English-only metadata in RevenueCat:
  - non-legal lines (`headline`, `subheadline`, `annual_badge`) translate in `es` and `pt-BR`
  - legal-sensitive lines (`cta`, `footnote`) stay English when overrides missing
- [ ] `_es` override keys take precedence over machine translation.
- [ ] `_pt_br` override keys take precedence over machine translation.
- [ ] Purchase/restore/resubscribe flows unchanged after localization pass.

## Telemetry Verification Matrix

- [ ] iOS emits `localization_request` analytics event for successful localization call.
- [ ] iOS emits `localization_request` analytics event on fail-open fallback-to-English path.
- [ ] Server emits PostHog `localization_request` event on successful `/api/v1/localize`.
- [ ] Server emits PostHog `localization_request` event on invalid/unauthorized/error paths.
- [ ] Event properties include:
  - `domain`
  - `target_locale`
  - `key_count`
  - `provider`
  - `model`
  - `cached`
  - `fallback_used`

## Regression Gate

- [ ] Fixed first-journey onboarding block remains unchanged in order:
  - `generating`
  - `tendReflection`
  - `tendPrayer`
  - `tendNextStep`
  - `creationSprout`
- [ ] Paywall trigger policy unchanged by localization features.
- [ ] PostHog assignment and RevenueCat offering fetch remain stable.
