# RFC-0003: Monetization and Experimentation

- **Status:** Draft
- **Date:** March 12, 2026
- **Owner:** Product + Engineering

## Context
MVP will launch with a hard paywall and 3-day free trial. Product owner wants ongoing A/B/C testing for trial and pricing strategy.

## Decision
1. MVP default experience:
- Hard paywall after early engagement events
- Annual plan with 3-day intro trial enabled in StoreKit

2. Post-MVP experimentation:
- Test paywall trigger timing variants
- Test copy variants
- Test pricing/trial offer variants where App Store offer setup allows

3. Analytics baseline for experimentation:
- Track impressions, starts, conversions, trial-to-paid, cancellations, refunds
- Use App Store Connect analytics plus local event logging immediately
- Add remote analytics SDK only after privacy review and explicit sign-off

## Rationale
This balances immediate monetization with clear path to data-driven optimization.

## Open items
- Final recurring price points
- Decision on analytics vendor (or App Store-only for early phase)
