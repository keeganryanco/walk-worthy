# PATCH-008: Onboarding No-Scroll Layout + App Store Review Prompt Clarification

## Summary
Refactored onboarding to be no-scroll across iPhone viewports via adaptive layout metrics and replaced onboarding sentiment-style review UX with an App Store review prompt pattern.

## Changes
- Reworked onboarding layout container:
  - Removed `ScrollView` from onboarding flow.
  - Added geometry-based `LayoutMetrics` to scale typography, spacing, media sizes, and grid density by viewport height.
- Updated onboarding option-selection pages:
  - Added adaptive single/two-column pill layout for dense option screens.
  - Reduced compact-device pill sizing while preserving style.
- Updated onboarding review step:
  - Changed from thumbs-up/down onboarding survey concept to App Store review prompt intent.
  - Added `Rate Tend` action using `requestReview()` and `Not now` option.
  - Kept completion path clear via CTA.
- Updated intro media and fallback behavior:
  - Removed fallback highlight-card framing so logo/video sits flush with onboarding background.
  - Renamed local loop file to expected naming and expanded script alias support.

## Docs updated for Gemini coordination
- `docs/GEMINI_IMPLEMENTATION_BRIEF.md`
  - Added no-scroll requirement.
  - Added explicit App Store review-step intent clarification.
  - Added do-not-break integration guardrails.
- `docs/PARALLEL_BUILD_PLAN.md`
  - Added onboarding no-scroll + review intent notes under shared touchpoints.

## Validation
- `./scripts/prepare_assets_for_ios.sh`
- `xcodebuild -project WalkWorthy.xcodeproj -scheme WalkWorthy -destination 'generic/platform=iOS Simulator' build`
