# PATCH-001: iOS Scaffold

- **Status:** Implemented (first pass)
- **Date:** March 12, 2026

## Goal
Create production-lean SwiftUI iOS scaffold with SwiftData, StoreKit 2, and notification service abstractions.

## Scope
- Xcode project and target setup
- Domain models
- Feature folders and base views
- StoreKit manager skeleton
- Notification manager skeleton
- Unit/UI test target scaffolding

## Acceptance
- App builds locally in Xcode
- Core navigation and placeholder screens run
- SwiftData container initializes cleanly

## Notes
- Project generated with `xcodegen`.
- Local compile could not be validated in CI shell because iOS simulator platform is not installed on this machine's current Xcode components.
