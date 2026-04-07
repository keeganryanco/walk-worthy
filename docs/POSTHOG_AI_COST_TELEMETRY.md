# PostHog AI Cost Telemetry Setup (Tend)

This repo now emits server-side AI usage telemetry to PostHog for:
- `journey_bootstrap` calls
- `journey_package` calls

Event name:
- `ai_generation_usage`

## What Is Captured

Each AI API call sends:
- `provider` (`openai`, `gemini`, `template`)
- `model`
- `input_tokens`
- `output_tokens`
- `total_tokens`
- `estimated_cost_usd` (if cost env vars are configured)
- `endpoint` (`journey_bootstrap` or `journey_package`)
- `distinct_id` (from iOS `analytics.distinct_id`)
- app metadata (`app_version`, `app_build_number`, `app_platform`)
- context flags (`has_follow_through_context`, etc.)

## Required Env Vars (Vercel `site` project)

Set:
- `POSTHOG_API_KEY` = your PostHog project API key (`phc_...`)
- `POSTHOG_HOST` = `https://us.i.posthog.com` (or your region host)

Optional but recommended for cost estimates:
- `OPENAI_INPUT_COST_PER_1M_TOKENS`
- `OPENAI_OUTPUT_COST_PER_1M_TOKENS`
- `GEMINI_INPUT_COST_PER_1M_TOKENS`
- `GEMINI_OUTPUT_COST_PER_1M_TOKENS`

Optional model overrides:
- `OPENAI_GPT_5_MINI_INPUT_COST_PER_1M_TOKENS`
- `OPENAI_GPT_5_MINI_OUTPUT_COST_PER_1M_TOKENS`
- etc. (`<PROVIDER>_<MODEL>_<INPUT|OUTPUT>_COST_PER_1M_TOKENS`)

If rates are unset, token counts still track, but `estimated_cost_usd` is `0`/empty.

## PostHog Insights To Create

## 1) `cost_per_active_user_month`

Create a **Trends** insight:
- Numerator: `sum(estimated_cost_usd)` on event `ai_generation_usage`
- Denominator: `unique users` on event `ai_generation_usage`
- Interval: `Month`

Formula:
- `sum(estimated_cost_usd) / unique_users(ai_generation_usage)`

## 2) `cost_per_completed_tend`

Create a **Trends** insight:
- Numerator: `sum(estimated_cost_usd)` on event `ai_generation_usage`
- Denominator: `count` of event `small_step_completed`

Formula:
- `sum(estimated_cost_usd from ai_generation_usage) / count(small_step_completed)`

Notes:
- `small_step_completed` is emitted by iOS analytics.
- `ai_generation_usage` is emitted by server API routes.
- Both use the same `distinct_id` key from app install identity.

## Verification Checklist

1. Complete onboarding and generate a journey.
2. Open PostHog → Events and confirm `ai_generation_usage` appears.
3. Validate token fields populate (`input_tokens`, `output_tokens`, `total_tokens`).
4. Confirm `small_step_completed` is still being captured.
5. Build insights above and verify non-zero values after usage.

