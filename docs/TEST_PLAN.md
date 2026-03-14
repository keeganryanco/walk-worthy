# Test Plan (MVP)

## Scope
Validate that Tend delivers a stable offline-first daily loop, accurate entitlement behavior, and App Review-safe UX/content behavior.

## Test layers
1. Unit tests
- Today card generation logic
- Journey limit gating (free vs premium)
- Reflection persistence and retrieval
- Timeline ordering and filtering

2. Integration tests
- SwiftData repository writes/reads/migrations
- StoreKit 2 purchase + restore + entitlement cache behavior
- Notification scheduling and cancellation behavior

3. UI tests
- First launch -> onboarding -> Today card generation
- Complete Today flow in under 30 seconds path
- Create/edit/archive journey
- Access timeline and view answered prayer entries
- Paywall trigger and restore flow

4. Manual QA
- Offline mode from fresh install
- App relaunch persistence
- Notification permission denied path
- Dynamic Type XL/XXL layout behavior
- VoiceOver traversal

## Environments
- iOS latest public release + previous major release
- iPhone small display and large display class
- StoreKit local configuration and Sandbox account

## Exit criteria
- No P0/P1 defects open
- No crash in core loop during smoke tests
- Entitlements update correctly in purchase and restore flows
- Accessibility baseline checklist passes

## Regression checklist for each release
- Onboarding answers persist
- Today card content appears at app launch
- Free-tier limit still enforced
- Premium unlocks propagate without restart
- Timeline remains accurate after date boundary
