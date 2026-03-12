# Minimal Architecture (Rapid Production)

## Objective
Ship a stable, polished MVP quickly with low operational complexity.

## Architectural style
- Single iOS app target
- Feature-first foldering
- Local-first domain layer
- Thin service adapters for StoreKit and Notifications

## Proposed project structure
```text
WalkWorthy/
  App/
    WalkWorthyApp.swift
    AppContainer.swift
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
    UseCases/
    Policies/
  Data/
    SwiftData/
      Schemas/
      Repositories/
  Services/
    Notifications/
    Monetization/
    Content/
  Shared/
    Extensions/
    Utilities/
  Resources/
    Assets.xcassets
    Localizable.strings
WalkWorthyTests/
WalkWorthyUITests/
```

## Domain layer contracts
- `TodayCardGenerator`
  - Produces daily prompt + action step from onboarding profile + recent journey context
- `JourneyLimitPolicy`
  - Enforces free-tier active journey cap
- `EntitlementService`
  - Provides premium status from StoreKit transactions
- `ReminderScheduler`
  - Schedules/cancels local notifications

## Persistence strategy
- SwiftData models as source of truth
- Repository wrappers for testability
- Lightweight migration handling for schema evolution

## UI navigation
- `NavigationStack` with tab or segmented root:
  - Today
  - Journeys
  - Timeline
  - Settings

## Asynchrony and performance
- Use `Task` only at feature boundaries (StoreKit sync, notifications, startup hydration)
- Keep writes batched and avoid heavy main-thread work
- Target app launch under 1 second on modern devices

## Monetization architecture
- `StoreKitManager` handles products, purchase flow, restore purchases
- Entitlements cached locally for offline startup resilience
- Paywall gate checks centralized in `JourneyLimitPolicy` + feature flags

## Security and privacy
- No user accounts
- No external analytics SDK required for MVP
- Optional local event log for debugging only (non-identifying)

## Why this is optimized for rapid production
- Minimal abstraction count
- Local data avoids backend scope
- Feature boundaries map directly to QA flows
- Clear upgrade path for post-MVP cloud sync if needed
