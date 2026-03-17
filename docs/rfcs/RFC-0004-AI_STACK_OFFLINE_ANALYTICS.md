# RFC-0004: AI Stack + Offline + Analytics + Monetization Sequencing

## Status
Draft (implementation started)

## Goal
Define an MVP-safe AI and growth stack for Tend that preserves local-first UX, supports personalization, and can be executed in parallel with UI work.

## Decisions
1. AI generation will be server-assisted (network required for new journey creation), with local deterministic fallback for daily continuity.
2. App remains usable offline for existing journeys via cached daily packages.
3. New journey creation remains blocked offline.
4. PostHog will be the analytics system of record.
5. RevenueCat will manage subscription entitlements/paywall plumbing.
6. Paywall presentation policy: no paywall for first 3 days from first launch, then rules apply.

## AI Model Recommendation (MVP)
Recommended default:
- Primary generation model: a cost-efficient structured-output model (`GPT-5 mini` or `Gemini 2.5 Flash`) for day-to-day package generation.
- Optional fallback/escalation model: stronger reasoning tier (`GPT-5.1`) for regeneration or edge cases.

Why:
- Structured output support for strict JSON contracts is first-class on both stacks.
- Cost profile is materially lower on mini/flash tiers for frequent daily generation.

Selection method (required before final lock):
1. Run a fixed benchmark set of 50 prompts.
2. Score for schema adherence, scripture-reference validity, tone fit, and latency.
3. Select lowest-cost model that meets quality thresholds.

## Offline Behavior Contract
1. On app startup and connectivity restoration, prefetch daily package content for today (+ optional tomorrow) for all active journeys.
2. If offline:
- User can view cached package content and log completion/reflection.
- User cannot start a new journey.
3. If package generation fails online, fall back to deterministic local template generation.

## Data/Memory Contract
1. Strong per-journey memory:
- summary
- wins summary
- blockers summary
- preferred tone
2. Progress event log:
- package generated
- step completed
- journey completed
3. Daily package cache:
- package content for journey + day
- source metadata (`remote`, `template`, `cache`)

## Analytics (PostHog) Plan
Initial event taxonomy:
- `onboarding_started`
- `onboarding_completed`
- `onboarding_wow_seen`
- `review_prompt_shown`
- `journey_created`
- `daily_package_generated`
- `small_step_completed`
- `journey_completed`
- `paywall_shown`

Privacy baseline:
- No raw prayer text in analytics payloads.
- Use coarse metadata and IDs only.

## Monetization (RevenueCat) Plan
1. Integrate SDK for entitlement status and restore support.
2. Configure weekly and annual SKUs in RevenueCat offerings.
3. Honor first-3-day no-paywall app policy in app logic.
4. After day 3, evaluate paywall triggers and entitlement.
5. Free trial terms shown must match App Store Connect metadata shown in payment sheet.

## Experiment Plan (post-MVP gate)
1. A/B test timing and copy of paywall.
2. Keep product IDs and subscription group strategy explicit to avoid eligibility confusion.
3. Track experiment assignment in PostHog and include variant in paywall conversion events.

## Parallelization Contract With Gemini
Gemini can proceed immediately on UI if it only consumes:
- `JourneyCreationPolicy`
- `ConnectivityService`
- `JourneyContentService`
- `JourneyMemoryService`
- `JourneyProgressService`

Gemini should not refactor these services directly.

## External references used for this RFC
- OpenAI model and pricing docs:
  - https://developers.openai.com/api/docs/models/gpt-5.1
  - https://developers.openai.com/api/docs/models/gpt-5-mini
  - https://developers.openai.com/api/docs/pricing
- OpenAI Responses API reference:
  - https://platform.openai.com/docs/api-reference/responses/compacted-object
- Gemini structured output docs:
  - https://ai.google.dev/gemini-api/docs/structured-output
- Anthropic tool/strict tool-use docs:
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/implement-tool-use
- PostHog iOS SDK docs:
  - https://posthog.com/docs/libraries/ios
- RevenueCat setup and offer docs:
  - https://www.revenuecat.com/docs/getting-started/quickstart
  - https://www.revenuecat.com/docs/subscription-guidance/subscription-offers
- Apple subscription offer and review guidance:
  - https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions
  - https://developer.apple.com/app-store/review/guidelines/
