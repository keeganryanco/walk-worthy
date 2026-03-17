# Minimal Architecture (Rapid Production)

## Objective
Ship a stable, polished MVP quickly with low operational complexity.

## Architectural style
- Single iOS app target
- Feature-first foldering
- Local-first domain layer
- Thin service adapters for StoreKit/RevenueCat, Notifications, Analytics, and AI generation

## Proposed project structure
```text
WalkWorthy/
  App/
    WalkWorthyApp.swift
    RootView.swift
  DesignSystem/
    ColorTokens.swift
    TypographyTokens.swift
    SpacingTokens.swift
    Components/
  Features/
    Onboarding/
    Today/
    Journeys/
    Timeline/
    Paywall/
    Settings/
  Domain/
    Models/
    Policies/
  Services/
    Notifications/
    Monetization/
    Analytics/
    Content/
  Shared/
    ConnectivityService.swift
  Resources/
    Assets.xcassets
    Localizable.strings
WalkWorthyTests/
WalkWorthyUITests/
```

## Domain layer contracts
- `JourneyContentService`
  - Orchestrates daily package generation and cache resolution (`remote` vs `template` vs `cache`)
- `JourneyCreationPolicy`
  - Enforces offline/paywall/free-tier creation rules
- `JourneyMemoryService`
  - Maintains per-journey memory snapshots for personalization continuity
- `JourneyProgressService`
  - Persists package-generated/completion progress events
- `SubscriptionService`
  - Provides premium status and purchase/restore flows
- `NotificationService`
  - Schedules/cancels local reminders
- `AnalyticsTracking`
  - Event taxonomy and dispatch boundary (PostHog implementation pending)

## Persistence strategy
- SwiftData models as source of truth
- Model-backed service helpers for query/update logic
- Lightweight migration handling for schema evolution

## UI navigation
- `NavigationStack` inside tab root
- Current to target transition:
  - Today/Journeys/Timeline/Settings -> Home/Journal/Settings (UI track in progress)

## Asynchrony and performance
- Use `Task` only at feature boundaries (StoreKit sync, notifications, startup hydration)
- Keep writes batched and avoid heavy main-thread work
- Target app launch under 1 second on modern devices

## Monetization architecture
- `SubscriptionService` handles products, purchase flow, restore purchases
- Entitlements cached locally for offline startup resilience
- Paywall gate checks centralized in `MonetizationPolicy` + `JourneyCreationPolicy`
- First-launch 3-day no-paywall window enforced in policy layer

## Security and privacy
- No user accounts
- Local-first storage with minimal telemetry payloads
- External analytics permitted via PostHog, excluding raw prayer text

## Why this is optimized for rapid production
- Minimal abstraction count
- Local data avoids backend scope
- Feature boundaries map directly to QA flows
- Clear upgrade path for post-MVP cloud sync if needed
