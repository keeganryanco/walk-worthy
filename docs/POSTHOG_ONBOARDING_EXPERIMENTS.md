# PostHog Onboarding Experiments (Tend)

This app supports **PostHog-controlled onboarding experiments** for:
- onboarding step order,
- onboarding copy overrides.

The first-journey generation block is intentionally fixed and cannot be reordered.

## 1) MCP Setup (Codex)

Run:

```bash
npx @posthog/wizard mcp add
```

If the wizard fails in this terminal UI, equivalent Codex MCP config is:

```toml
[mcp_servers.posthog]
command = "npx"
args = ["-y", "mcp-remote@latest", "https://mcp.posthog.com/mcp"]
type = "stdio"
startup_timeout_ms = 20_000
```

Notes:
- For API-key auth mode, use a **PostHog personal API key** (`phx_...`) and send as Bearer auth header.
- After adding/updating MCP config, **restart Codex** so the PostHog MCP server is loaded.

## 2) What Is Exempt (Fixed Journey Block)

These steps stay in this exact order always:
- `generating`
- `tendReflection`
- `tendPrayer`
- `tendNextStep`
- `creationSprout`

PostHog does not reorder these.

## 3) Flag To Create

Create a feature flag named:

- `onboarding_flow_config`

Add variants, for example:
- `control`
- `a`
- `b`

Set rollout split to match your test plan (examples):
- 50/50 (`control` vs `a`), or
- 34/33/33 (`control`, `a`, `b`).

## 4) Payload Contract (Per Variant)

Set each variant payload as JSON. Example:

```json
{
  "variant": "a",
  "pre_journey_order": [
    "name",
    "bannerName",
    "bannerTruth",
    "bannerChange",
    "method",
    "grounding",
    "prayerIntent",
    "goalIntent"
  ],
  "post_journey_order": [
    "backgroundSelection",
    "review",
    "reminder",
    "widget"
  ],
  "copy_overrides": {
    "intro_title": "Welcome to Tend",
    "default_next_cta": "Next"
  }
}
```

You can provide additional copy keys in `copy_overrides`; missing keys fall back to in-app defaults.

### Localization behavior (Phase B/C)

- Keep `copy_overrides` authored in English in PostHog.
- If app locale is Spanish, Portuguese (Brazil), or Korean, iOS sends `copy_overrides` through the backend localization endpoint and renders translated values.
- If localization fails, app falls back to the original English `copy_overrides` values (no crash, no flow block).

## 5) Allowed Step Tokens

### Pre-journey order (before generation)
- `name`
- `bannerName`
- `bannerTruth`
- `bannerChange`
- `method`
- `grounding`
- `prayerIntent`
- `goalIntent`

### Post-journey order (after generation)
- `backgroundSelection`
- `review`
- `reminder`
- `widget`

App behavior safety:
- step tokens are normalized case-insensitively,
- if a variant provides no custom order, app uses built-in control order,
- missing required pre-journey inputs are re-added in safe order (`name`, `prayerIntent`, `goalIntent`),
- optional pre/post steps can be omitted by not including them in the variant order arrays,
- progress tracker recalculates from the active sequence so step removal/reordering does not break progress UI.

## 6) Experiment Setup In PostHog

Create an experiment using `onboarding_flow_config` and use these events:
- `onboarding_completed`
- `small_step_completed`
- `review_prompt_shown`
- `paywall_shown`

Recommended metric usage:
- Primary: `onboarding_completed`
- Secondary: `small_step_completed`
- Guardrail: `review_prompt_shown`, `paywall_shown`

## 7) Validate Assignment

The app emits:
- `onboarding_experiment_assigned`

with properties:
- `variant`
- `pre_count`
- `post_count`

Use this to verify rollouts are reaching devices as expected.

## 8) Operational Notes

- If PostHog is unavailable, app uses cached config.
- If no cached config exists, app uses built-in control defaults.
- Relaunch app after changing variants/payloads when validating locally.
- Keep experiment ownership clean: PostHog controls onboarding; RevenueCat controls paywall tests.
