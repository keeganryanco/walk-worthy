# Tend Agent Handoff (2026-03-26)

Use this as the initial prompt for a fresh agent with repo access.

## Prompt Start

You are taking over active development for the iOS app in this repository.

### Mission for today
Deliver a practical, execution-first plan and then implement items in this order:
1. RevenueCat operational readiness (paywall control, packages, offering metadata, app behavior alignment).
2. PostHog onboarding experimentation readiness (feature flags + experiment wiring verification).
3. App Store submission readiness audit (blocking checklist + exact remaining owner actions).
4. Only after those are stable: light UI/AI tweaks requested in-session.

### Product context
- App: **Tend** (iOS-first Christian prayer-to-action app).
- Core loop: Pray -> take one concrete step -> reflect -> track growth/journey.
- Stack: SwiftUI, SwiftData, StoreKit 2, Local notifications, WidgetKit, local-first app + lightweight AI gateway backend in `site/`.
- Monetization: RevenueCat-backed subscriptions, custom SwiftUI paywall (not RevenueCat no-code paywall renderer right now), remote behavior via offering metadata.
- Analytics: PostHog events + onboarding experiment config from feature flags.

### Critical guardrails
- Do **not** reorder or destabilize first-journey generated block in onboarding:
  - `generating`, `tendReflection`, `tendPrayer`, `tendNextStep`, `creationSprout`
- Keep first-person prayer generation rule intact.
- Keep onboarding experiment flexibility only around pre/post journey sections.
- Keep UI behavior stable while prioritizing operational correctness for RevenueCat/PostHog/App Store readiness.

### Repository orientation
- iOS app: `WalkWorthy/`
- Widgets: `TendWidgets/`, `WalkWorthyWidgets/`
- Backend/API gateway: `site/`
- Config: `Config/*.xcconfig`, `~/.codex/config.toml` for MCPs
- Documentation root: `docs/`

Read these first:
1. `docs/README.md`
2. `docs/PARALLEL_BUILD_PLAN.md`
3. `docs/POSTHOG_ONBOARDING_EXPERIMENTS.md`
4. `docs/REVENUECAT_NO_CODE_PAYWALL_SETUP.md`
5. `docs/APP_STORE_SHIPPING_CHECKLIST.md`
6. `docs/APP_STORE_METADATA.md`
7. `docs/XCODE_SETUP.md`
8. `docs/GEMINI_IMPLEMENTATION_BRIEF.md` (for context only; do not blindly re-implement old UI tasks)

### Current known status to verify immediately
- RevenueCat MCP should be configured and usable for API operations.
- PostHog MCP was previously flaky due to auth/handshake setup; re-test from scratch in this session.
- App had prior RevenueCat fetch issues likely tied to App Store Connect setup state, agreements, and product readiness.

### Task 1: RevenueCat operational pass
Use RevenueCat MCP first.

Actions:
1. Verify project/app/offerings/packages/products are correctly connected.
2. Confirm offering metadata is present and matches app-supported keys:
   - `paywall_mode`
   - `paywall_headline`
   - `paywall_subheadline`
   - `paywall_cta`
   - `paywall_annual_badge`
   - `paywall_footnote`
   - `default_package`
3. Validate package/product mapping for weekly/annual products.
4. Produce exact ON/OFF runbook for paywall with expected in-app behavior.
5. Identify what cannot be fully validated until App Store Connect state changes (agreements, review state, etc.).

Deliverable:
- Concise “RevenueCat readiness report” with:
  - green/yellow/red table,
  - exact next steps for user,
  - exact app-side changes needed (if any).

### Task 2: PostHog onboarding experiments pass
Use PostHog MCP if available; if not, use API with proper credentials and document blocker.

Target setup:
- Feature flag: `onboarding_flow_config`
- Variants: `control`, `a`, `b`
- Rollout split: practical default (e.g., 50/25/25 or 34/33/33)
- Payload contract per `docs/POSTHOG_ONBOARDING_EXPERIMENTS.md`
- Experiment events:
  - `onboarding_completed`
  - `small_step_completed`
  - `review_prompt_shown`
  - `paywall_shown`

Validation:
- Confirm app emits assignment event `onboarding_experiment_assigned`.
- Confirm first-journey block remains exempt from reordering.

Deliverable:
- “PostHog experiment readiness report” with:
  - what was created/updated,
  - how user edits test content/flow in PostHog UI,
  - rollback instructions.

### Task 3: App Store submission readiness
Audit readiness for review today.

Specifically answer:
1. Are widgets treated as a separate package/binary or included with app submission?
2. Will current app icon/bundle path show correctly given app already exists in App Store Connect but not yet submitted?
3. Is Apple payout logic with RevenueCat architecture sound (Apple pays developer; RevenueCat manages entitlement/state)?

Deliverable:
- “Submission readiness checklist delta”:
  - done,
  - must-do today before submit,
  - can defer.

### Execution style
- Do concrete checks first, not speculative advice.
- Use MCP tools aggressively where available.
- Keep modifications minimal and safe; avoid unnecessary refactors.
- Update docs for any operational runbook changes.
- End with a short prioritized action list the user can execute immediately.

### Output format required
1. Findings (highest risk first).
2. What you changed.
3. What user must do in Apple/RevenueCat/PostHog UI.
4. What remains optional for later (e.g., localization).

## Prompt End

