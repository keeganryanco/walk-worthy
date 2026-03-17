# PATCH-007: Onboarding Intro Loop Hook

## Summary
Added a first-screen onboarding media hook for a transparent logo video loop with fallback behavior and documented drop-in workflow for parallel Gemini work.

## Changes
- Added `OnboardingIntroLoopView` with:
  - AVPlayerLooper-backed seamless looping.
  - Surface background card to preserve brand color.
  - Fallback to `TendMark` if video asset is missing.
- Wired intro screen to use this component:
  - `OnboardingFlowView` step `.intro`.
- Added video asset sync support:
  - `scripts/sync_brand_assets.sh` now looks for `design/brand-assets/video/onboarding_intro_loop_alpha.*` and copies to app resources as `OnboardingIntroLoop.*`.
- Added drop folder instructions:
  - `design/brand-assets/video/README.md`.
- Added Gemini coordination note:
  - `docs/GEMINI_IMPLEMENTATION_BRIEF.md` section 5.4.
  - `docs/PARALLEL_BUILD_PLAN.md` shared touchpoint note.

## Validation
- `xcodegen generate`
- `xcodebuild -project WalkWorthy.xcodeproj -scheme WalkWorthy -destination 'generic/platform=iOS Simulator' build`
- `xcodebuild -project WalkWorthy.xcodeproj -scheme WalkWorthy -destination 'platform=iOS Simulator,name=iPhone 17' test`
