# Codex Track: AI/Core Logic Plan

## Scope
Codex owns:
1. AI daily content pipeline
2. Memory system (strong per-journey, light cross-journey)
3. Journey progression/watering mechanics
4. Offline-support behavior
5. PostHog analytics integration
6. RevenueCat integration and initial no-paywall window

Gemini owns UI/UX only and should integrate against these interfaces.

## Product rules to implement
- Onboarding wow is generated from onboarding answers (generic but personalized baseline).
- Daily package format:
  - reflection thought
  - scripture reference
  - scripture paraphrase
  - prayer
  - small-step prompt
  - suggested step options
- Small-step completion should update journey progression ("water" event).
- Journey completion should persist a "memory plant" artifact for history.

## AI architecture (recommended)

## 1) Provider abstraction
- `AIContentProvider` protocol behind app logic.
- `TemplateFallbackProvider` always available offline.
- `RemoteProvider` for online generation.
- `AIOrchestrator` decides remote vs fallback and handles caching.

## 2) Structured output contract
- Strongly typed decoded schema (no freeform parsing in UI).
- Validation stage:
  - verse reference format check
  - non-empty fields
  - max length limits
  - tone/claim checks

## 3) Memory layers
- `JourneyMemorySnapshot` (per journey):
  - latest goal summary
  - streak/progress
  - blockers/wins
  - preferred tone/emphasis
- `GlobalLightMemory` (across journeys):
  - very small preference map only

## 4) Persistence
- SwiftData models for:
  - memory snapshots
  - daily generated packages (cache)
  - progression events ("waterings")

## 5) Offline strategy
- Daily prefetch when online:
  - fetch/cache package for each active journey for today (and optional +1 day).
- Offline behavior:
  - allow viewing cached day content and logging progress.
  - allow existing journey continuation.
  - block starting a new journey when no network (as requested), with clear message.

## Model/provider brainstorming framework
Choose provider/model by benchmark, not guesswork:
1. JSON reliability (strict schema adherence)
2. verse-reference reliability
3. latency under mobile conditions
4. cost per generated package

Run a small benchmark set (20-50 prompts) before final model lock.

## Analytics plan (PostHog)
- Integrate PostHog client with local queue + retry.
- Event taxonomy (initial):
  - onboarding_started/completed
  - onboarding_wow_seen
  - review_prompt_shown
  - journey_created
  - daily_package_generated
  - small_step_completed
  - journey_completed
  - paywall_shown/paywall_skipped/paywall_subscribed (when enabled)

Privacy: no raw prayer text in analytics events by default.

## Monetization plan (RevenueCat)
- Integrate SDK early for entitlement plumbing.
- Initial launch policy:
  - no paywall for first 3 days from install/profile creation.
  - keep entitlement checks/policy ready for later paywall activation.

## Proposed implementation sequence
1. Add domain contracts + SwiftData models.
2. Implement progression/watering use cases.
3. Implement AI orchestrator with template fallback + cache.
4. Add offline gating policy for new journey creation.
5. Add PostHog service + event schema.
6. Add RevenueCat service + no-paywall-first-3-days policy.
7. Add tests (unit + integration-level where practical).

## Tests required
- Memory merge/update logic
- AI payload validation and fallback behavior
- offline gating logic (new journey blocked, existing journey allowed)
- 3-day no-paywall policy logic
- analytics event dispatch mapping

## Inputs needed from user before final lock
1. Preferred AI provider(s) shortlist for benchmark
2. Hard budget target per DAU or per generated package
3. RevenueCat App Store Connect key configuration completion timing
4. RevenueCat offering/paywall experiment setup timing
5. Any prohibited content themes beyond current scripture policy
