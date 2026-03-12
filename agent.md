# Agent Working Guide: Walk Worthy

## Mission
Build and ship an iOS app called **Walk Worthy** (subtitle: **Pray & Do**) that is private, local-first, and production-ready.

## Product loop
Pray -> Action -> Reflection -> Timeline

## Required stack
- SwiftUI
- SwiftData
- StoreKit 2
- UserNotifications (local notifications)
- No auth for MVP
- No backend for MVP unless explicitly justified and approved

## Product principles
- Daily completion should be possible in under 30 seconds.
- First meaningful action should happen within 5 seconds of opening the app.
- Keep interaction private and local by default.
- Avoid doctrinal overreach; keep content pastoral and non-absolute.

## Design direction
- Warm alabaster base, sage secondary, sapphire primary
- Editorial serif headers + clean sans body
- Minimal chrome, generous spacing, sincere tone

## App Review guardrails
- No fabricated or misleading scripture quotations
- No unsupported medical/therapeutic claims
- Use StoreKit 2 for digital subscriptions
- Include Privacy Policy URL and Support URL
- Include restore purchases in paywall

## Implementation priorities
1. Data model + daily loop
2. Onboarding -> instant Today card
3. Journey + timeline history
4. Notifications + habit loop
5. Paywall + entitlement state
6. Polishing, accessibility, tests, App Store packaging

## Definition of done for MVP
- Offline-first app works end-to-end with no account
- Free and premium tiers function correctly
- Core flow test coverage and manual QA checklist complete
- App Store Connect metadata and compliance artifacts ready
