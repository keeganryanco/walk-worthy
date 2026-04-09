# Tend Next Major Features Plan

Last updated: 2026-04-09

## Why this doc exists

Capture the next major feature tracks after launch, with implementation-first planning and explicit sequencing.

## Priority order

1. Multilingual support (highest priority)
2. UX + immersion improvements
3. Sharing for devotionals/plants
4. Deeper theological/devotional progression

---

## 1) Multilingual support (highest priority)

### Progress tracker (updated 2026-04-09, Japanese pass)

#### Phase A (ship now)
- [x] App language setting added (`System Default`, `English`, `Español`) with persisted selection.
- [x] Runtime locale wiring applied at app root (`.environment(\\.locale, ...)`) so core UI updates without restart.
- [x] Core static UI localization resources added (`en.lproj`, `es.lproj`) with key coverage for onboarding/home/journal/settings/paywall core copy.
- [x] AI request payload now includes `languageCode` and `localeIdentifier` for bootstrap and daily package calls.
- [x] Backend request schema accepts `languageCode` and `localeIdentifier`.
- [x] Prompt builders now require output language (`en`/`es`) for user-facing generated fields.
- [x] Validation/fallback logic now has Spanish-aware first-person prayer and localized fallback copy/chips.

#### Phase B (next)
- [x] Translation endpoint in `site/` with cache (`/api/v1/localize` or equivalent).
- [x] Route PostHog onboarding copy through translation path when locale is non-English.
- [x] Route RevenueCat metadata copy through translation path when locale is non-English.
- [x] Manual per-locale override map for legal/brand-sensitive paywall copy (`*_es` suffix keys).

#### Phase C (quality + scale)
- [x] Glossary and terminology guardrails for devotional/Bible-adjacent phrasing by language.
- [x] QA matrix for top locales + dynamic type and clipping audits.
- [x] Telemetry for translation success/failure and fallback-to-English rate by locale.
- [x] Add second non-English language after Spanish stabilization (`pt-BR`).

#### Phase D (live expansion)
- [x] Add Korean (`ko`) app-wide localization wiring (UI locale, AI language routing, remote-copy translation locale support).
- [x] Add Korean core static strings (`ko.lproj`) with parity against `en.lproj`.
- [x] Extend RevenueCat locale override support to `_ko` metadata keys.
- [x] Extend backend localization normalization and glossary support to Korean.
- [x] Add Japanese (`ja`) app-wide localization wiring (UI locale, AI language routing, remote-copy translation locale support).
- [x] Add Japanese core static strings (`ja.lproj`) with parity against `en.lproj`.
- [x] Extend RevenueCat locale override support to `_ja` metadata keys.
- [x] Extend backend localization normalization and glossary support to Japanese.

### Goals

- Let users use Tend in non-English languages.
- Avoid manual copy duplication for every PostHog/RevenueCat tweak.
- Keep AI responses, onboarding copy, and paywall copy consistent in user language.

### Current state (important constraints)

- iOS static UI is currently hardcoded English (no localization tables).
- PostHog onboarding copy is fetched directly on-device and consumed as plain strings (`OnboardingExperimentService`).
- RevenueCat paywall copy is fetched directly from offering metadata (`SubscriptionService.resolvePaywallConfig`).
- AI prompt/backend flow currently assumes English tone/instructions, with no explicit language field in request schema.

### Recommended architecture

Use **English as source-of-truth** + **automatic translation layer** + **manual override escape hatch**.

1. Source text stays in English:
   - PostHog payloads
   - RevenueCat offering metadata
   - iOS fallback/default strings
2. Add a backend localization endpoint in `site/`:
   - Input: `{ strings, targetLocale, domain, versionHash }`
   - Output: translated strings with same keys
   - Cache by `(source_hash, locale)` to keep cost low
3. iOS applies translation only when locale is not English:
   - If translation succeeds, render localized copy
   - If it fails, render original English immediately (no blocking)
4. Add manual overrides for critical brand strings:
   - Optional keys like `paywall_headline_es` or explicit override map in backend
   - Overrides beat machine translation

### AI multilingual plan

1. Extend request payload (`JourneyPackageRequest`) with:
   - `languageCode` (e.g. `es`, `pt-BR`)
   - `localeIdentifier`
2. Update AI prompt builder:
   - Add hard instruction: output reflection/prayer/step in requested language
   - Keep theological guardrails identical
   - Keep first-person prayer rule across all languages
3. Scripture handling:
   - Keep canonical reference identity stable (avoid malformed references)
   - Add localized display format later (phase 2)
4. Validation:
   - Add language conformance checks (basic script/locale sanity)
   - Keep fallback behavior safe (English fallback if needed)

### Delivery phases

#### Phase A (fast path, ship first)
- Add iOS app language setting (`System Default` + selected language). ✅
- Localize core static UI via `Localizable.strings` for top 1-2 languages. ✅ (`en` + `es`)
- Add AI `languageCode` support end-to-end. ✅

#### Phase B (remote copy translation)
- Build backend translation endpoint + cache.
- Route PostHog/RevenueCat strings through translator when locale != English.
- Add optional manual per-locale override keys.

#### Phase C (quality + scale)
- Translation glossary for biblical/devotional terms. ✅
- QA matrix for top languages + dynamic type. ✅
- Add telemetry:
  - translation success/failure rate ✅
  - fallback-to-English rate by locale ✅
- Add second non-English language (`pt-BR`). ✅

### Acceptance criteria

- User can set language and get:
  - app chrome localized
  - onboarding/paywall copy localized
  - AI devotional package localized
- If translation fails, UX remains functional with English fallback.
- No regression to paywall or onboarding completion.

---

## 2) UX + immersion improvements

### Product direction

Increase delight and consistency without turning the app into a distracting game.

### Candidate improvements

1. Onboarding simplification:
   - Evaluate 2-question journey creation vs 1 adaptive prompt
2. Progression UX:
   - Better “collection” framing for grown plants (light Pokédex feel)
   - Keep devotional focus primary
3. Rewards:
   - Gentle milestone moments (no noisy gamification)
   - Theme-based growth badges tied to follow-through
4. Home/Journey polish:
   - Reduce layout edge cases across devices/safe areas

### Experiments

- PostHog test:
  - `journey_create_v1` (2 questions) vs `journey_create_v2` (1 adaptive prompt)
- Measure:
  - create completion
  - day-1 tend completion
  - day-7 retention

---

## 3) Sharing component (plants + devotionals)

### Goal

Allow meaningful sharing moments that feel devotional, not performative.

### v1 scope

1. Share card types:
   - Plant growth milestone card
   - Daily devotional card (reflection/scripture paraphrase + reference)
2. Controls:
   - Include/exclude prayer text
   - Include/exclude journey title
3. Privacy defaults:
   - Conservative defaults (private-sensitive fields off by default)
4. Distribution:
   - Native iOS share sheet first

### Technical shape

- SwiftUI share renderer -> image snapshot
- Branded card templates by light/dark mode
- Event tracking:
  - `share_opened`
  - `share_completed`
  - `share_type`

---

## 4) Deeper theological/devotional progression

### Goal

Make journeys feel directional and transformational over time, not just daily isolated prompts.

### Approach

1. Add “journey arc” scaffolding:
   - Stage intent per cycle (foundation -> practice -> perseverance -> integration)
2. Strengthen memory usage in generation:
   - Explicitly tie today’s reflection to prior follow-through and prior prayer themes
3. Add periodic synthesis:
   - Every N tends, generate a short “growth insight” summary
4. Guardrails:
   - Keep respectful, non-coercive tone
   - Keep no-guarantee and no-shame policy

### Model considerations

- Start with current model stack + better prompts/context shaping.
- If quality plateau appears:
  - escalate only this feature path to higher-capability model for synthesis events
  - keep normal daily generations on cheaper model

---

## Execution roadmap (recommended)

## Sprint 1
- Multilingual Phase A
- Define translation glossary seed list
- Add instrumentation for language + translation fallback

## Sprint 2
- Multilingual Phase B
- UX experiment spec for journey creation simplification

## Sprint 3
- Sharing v1
- Devotional depth scaffolding (journey arc fields + prompt wiring)

## Sprint 4
- Multilingual Phase C quality pass ✅
- Deeper theological progression experiment rollout

---

## Decisions to lock before implementation

1. First non-English launch languages (recommend: Spanish first, then Portuguese).
2. Whether to expose manual language selector in onboarding or only in Settings.
3. Whether to allow machine-translated paywall copy in production immediately, or only with manual override for legal-sensitive lines.
4. Whether devotional sharing defaults include scripture reference by default.

---

## Immediate next tasks (translation-first)

1. Add RFC for localization architecture (`rfcs/RFC-0006-LOCALIZATION-AND-MULTILINGUAL-AI.md`). ✅
2. Implement `languageCode` in journey package request and prompt. ✅
3. Add app setting + persistence for selected language. ✅
4. Add backend translation endpoint with cache and glossary hooks. ✅ (Phase B)
5. Wire PostHog/RevenueCat copy translation fallback path in iOS. ✅ (Phase B)
6. Add Phase C quality and scale pass (`pt-BR`, glossary guardrails, telemetry, QA matrix). ✅
