# Tend Experiments Playbook (PostHog + RevenueCat)

Last updated: 2026-03-26

## 1) Why these are separate systems

We are running two distinct experiment surfaces:

1. **PostHog** controls onboarding flow shape and onboarding copy.
2. **RevenueCat** controls paywall offer presentation (copy now, pricing later).

They are intentionally separate so we can isolate impact:
- onboarding conversion effects vs
- paywall conversion effects.

## 2) At-a-glance difference

| Area | PostHog experiment | RevenueCat experiment |
|---|---|---|
| What we are testing | Onboarding order + onboarding messaging | Paywall messaging (current), paywall pricing (future) |
| Current experiment name | `Onboarding Flow Config v1` (ID `363438`) | Manual setup in RevenueCat UI using offerings (`default`, `paywall_copy_a`, `paywall_copy_b`) |
| Randomization unit | PostHog feature flag variant (`onboarding_flow_config`) | RevenueCat offering assignment |
| Must stay fixed | First-journey block order: `generating -> tendReflection -> tendPrayer -> tendNextStep -> creationSprout` | Purchase plumbing and entitlement mapping |
| Primary success signal | `onboarding_completed` | Revenue / trial start / conversion in RevenueCat |
| Guardrails | `small_step_completed`, `review_prompt_shown`, `paywall_shown` | Trial/purchase conversion quality + restore behavior |

## 3) PostHog onboarding experiment (active)

### 3.1 Configuration

- Feature flag key: `onboarding_flow_config` (ID `623158`)
- Experiment: `Onboarding Flow Config v1` (ID `363438`)
- Status: `running`
- Split:
  - `control`: 34%
  - `a`: 33%
  - `b`: 33%

### 3.2 What each variant is testing

| Variant | What changes | Pre-journey order | Post-journey order | Copy overrides |
|---|---|---|---|---|
| `control` | Baseline full flow | `name, bannerName, bannerTruth, bannerChange, method, grounding, prayerIntent, goalIntent` | `backgroundSelection, review, reminder, widget` | `intro_title=Welcome to Tend`, `default_next_cta=Next` |
| `a` | Leaner onboarding | `name, prayerIntent, goalIntent` | `review, reminder` | `intro_title=Let’s start tending`, `default_next_cta=Continue` |
| `b` | Narrative + selective post steps | `name, bannerName, prayerIntent, method, goalIntent` | `backgroundSelection, review, widget` | `intro_title=Build a daily rule of life`, `default_next_cta=Keep going` |

### 3.3 Safety/guardrail behavior in app

- Fixed first-journey block remains unchanged and non-reorderable.
- Required pre-steps (`name`, `prayerIntent`, `goalIntent`) are auto-re-added if omitted.
- Optional pre/post steps can be removed.
- Progress tracker recalculates from active step sequence, so reorder/remove does not break progress UI.

### 3.4 Metrics wired for this test

- Assignment: `onboarding_experiment_assigned`
- Primary: `onboarding_completed`
- Secondary/guardrail:
  - `small_step_completed`
  - `review_prompt_shown`
  - `paywall_shown`

## 4) RevenueCat paywall experiment (copy test)

### 4.1 Current offering set

| Offering key | Purpose | Current state | Metadata intent |
|---|---|---|---|
| `default` | Baseline paywall copy | current=true | Baseline message |
| `paywall_copy_a` | Copy variant A | current=false | Strong commitment framing |
| `paywall_copy_b` | Copy variant B | current=false | Consistency framing |

All three currently use the same package structure:
- Annual package (`$rc_annual`)
- Weekly package (`$rc_weekly`)
- Same underlying App Store products

This means this is a **copy-only** test (not pricing yet).

### 4.2 Recommended launch split

For the RevenueCat experiment comparing offerings:
1. `default`: 34%
2. `paywall_copy_a`: 33%
3. `paywall_copy_b`: 33%

### 4.3 What this test should answer

- Which paywall messaging increases trial starts/purchases.
- Whether messaging changes hurt restore/purchase reliability.

## 5) Pre-launch change policy (important)

Before Apple launch, **tweak existing variants in place** instead of adding more variants.

### 5.1 PostHog (in-place edits only)

- Keep the same feature flag key: `onboarding_flow_config`.
- Keep variants: `control`, `a`, `b`.
- Allowed tweaks:
  - update `pre_journey_order`
  - update `post_journey_order`
  - update `copy_overrides`
  - adjust split percentages
- Avoid:
  - adding new variant keys right now
  - changing fixed first-journey block behavior

### 5.2 RevenueCat (in-place edits only)

- Keep offering keys: `default`, `paywall_copy_a`, `paywall_copy_b`.
- Allowed tweaks:
  - edit metadata copy (`paywall_headline`, `paywall_subheadline`, `paywall_cta`, etc.)
  - adjust experiment traffic split
- Avoid:
  - creating additional copy offerings before launch unless necessary
  - mixing pricing changes into this copy test

## 6) Future experiments plan

### 6.1 Next revenue experiment: Paywall pricing (after copy test)

Goal: isolate price sensitivity without copy confound.

Plan:
1. Reprice the existing annual product in App Store Connect to `$49.99/year`.
2. Replace the current weekly secondary plan with a new monthly product at `$7.99/month`.
3. Import the monthly product into RevenueCat and attach it to packages/offerings.
4. Update app-side package expectations (`weekly` -> `monthly`) in a separate implementation pass.
5. Create pricing offerings (example: `pricing_control`, `pricing_low`, `pricing_high`) with the same copy.
6. Run a separate RevenueCat pricing experiment.

Important note:
- The annual price can be changed on the existing App Store product.
- The move from weekly to monthly is not a simple price change. It requires a new monthly subscription product because duration is part of the product definition.

### 6.2 Planned cancel-downsell offer for free-trial users

Goal: recover users who start the free trial, cancel renewal during the trial window, and are still eligible to be retained before lapse.

Target offer:
- `$2.99/month for 3 months`

Planned audience:
- Users who started the initial free trial
- Users who canceled auto-renew before the trial ended
- Users who are still active during the trial period but are marked as non-renewing

Recommended structure:
1. Add a monthly base subscription product in App Store Connect (`$7.99/month`) in the same subscription group as the annual plan.
2. Create a promotional offer on the monthly product for `3 months at $2.99/month`.
3. Import the monthly product into RevenueCat.
4. Create a dedicated downsell offering in RevenueCat that points to the monthly product and carries downsell-specific metadata/copy.
5. In app, detect the "trial active but will not renew" state and present a dedicated downsell UI instead of the standard paywall.

Important note:
- This should be treated as a promotional-offer / retention path, not as "another intro offer."
- It is a separate flow from the default launch paywall and should not be mixed into the primary copy test.

### 6.3 Apple and RevenueCat owner actions for the downsell

Apple App Store Connect:
1. Create the new monthly auto-renewable subscription product.
2. Put it in the same subscription group as the annual product.
3. Set the monthly base price to `$7.99/month`.
4. Configure the promotional offer for `3 months at $2.99/month`.
5. Complete review metadata and screenshot requirements for the new monthly product / offer as needed.

RevenueCat:
1. Import the monthly product after it exists in App Store Connect.
2. Add a monthly package to the relevant offerings.
3. Create a dedicated downsell offering or experiment branch for the retention path.
4. Keep the default launch paywall offering separate from the cancel-downsell offer.

### 6.4 Next PostHog analytics/experiment tracks

These are high-value and aligned with product goals:

1. Journeys created per user per week
2. Average journey length (create -> complete)
3. Daily return behavior
4. Sessions per day

Implementation note:
- We already emit core conversion events.
- For cleaner retention/session analysis, we should add a dedicated session-start event in app (`app_session_started`) in a follow-up pass.

## 7) Apple launch defaults

Use these as the default launch posture unless there is a clear reason to change.

### 7.1 PostHog onboarding defaults

1. Keep the existing experiment (`Onboarding Flow Config v1`) running at:
   - `control`: 34%
   - `a`: 33%
   - `b`: 33%
2. Keep the fixed first-journey block unchanged.
3. Do not add new variants during launch week; only edit payloads for `control`, `a`, `b`.

Suggested rollback triggers:
- `onboarding_completed` drops by more than 15% vs the pre-launch baseline for 24+ hours.
- `small_step_completed` drops by more than 20% vs baseline for 24+ hours.
- `paywall_shown` spikes unexpectedly due to onboarding-flow regressions.

Recommended rollback action:
1. Set PostHog split to `control=100%`.
2. Keep experiment record and event data for analysis.

### 7.2 RevenueCat paywall defaults

1. Start with copy-only offering experiment:
   - `default`: 34%
   - `paywall_copy_a`: 33%
   - `paywall_copy_b`: 33%
2. Keep packages identical across variants for clean copy measurement.
   - Intended launch catalog: annual + monthly
   - Current RevenueCat catalog still needs to be migrated from annual + weekly before this is true
3. Delay pricing experiment until onboarding and copy behavior are stable after launch.

Suggested rollback triggers:
- Trial start rate drops more than 15% from baseline for 24+ hours.
- Purchase conversion drops more than 15% from baseline for 24+ hours.
- Restore/purchase support tickets increase materially after rollout.

Recommended rollback action:
1. Route 100% traffic to `default` offering (or stop the experiment).
2. Keep the `paywall_copy_a` and `paywall_copy_b` offerings for iterative copy changes.

## 8) Quick rollback paths

### 8.1 PostHog rollback

1. Set `onboarding_flow_config` split to `control=100%`.
2. Keep experiment record for historical analysis.

### 8.2 RevenueCat rollback

1. Set RevenueCat experiment traffic to `default=100%`, or stop experiment.
2. Keep `default` as current offering.
