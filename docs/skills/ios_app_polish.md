# skill: ios_app_polish

## Purpose
Ensure the iOS app feels native, premium, and App Store ready.

## Principles
- SwiftUI-first architecture
- Minimal view hierarchy
- Prefer system components when possible
- Smooth transitions
- Instant responsiveness

## Design rules
- No clutter
- Every screen has one clear primary action
- Use large touch targets (44pt minimum)
- Prioritize vertical flow

## Engineering rules
- SwiftUI
- SwiftData for persistence
- StoreKit 2 for purchases
- Local-first architecture
- No backend for MVP

## Performance rules
- Avoid heavy frameworks
- Avoid unnecessary async complexity
- App launch < 1s
- No blocking operations on main thread

## UX rules
- First action should be achievable within 5 seconds of opening the app
- Avoid modal spam
- Avoid tutorial slideshows
- Prefer progressive discovery

## App Store readiness
- Privacy policy link
- Support URL
- Restore purchases button
- Clear subscription explanation
