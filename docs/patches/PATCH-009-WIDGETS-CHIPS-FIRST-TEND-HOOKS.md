# PATCH-009: Widgets + Chip Quality + First-Tend Hooks

## Scope
Implemented Tend Weeds Pass 1 across iOS app + AI gateway:
- WidgetKit extension (`systemSmall`, `systemMedium`) with App Group snapshot sharing.
- AI step-chip quality hardening and contextual fallback chips.
- First-tend milestone persistence and helper hooks (logic-only, no new flow UI).

## iOS Changes
- Added new widget extension target source: `TendWidgets/*`.
- Added app/extension entitlements with App Group: `group.co.keeganryan.tend`.
- Added shared widget snapshot contract/store:
  - `WalkWorthy/Shared/Widget/TendWidgetSnapshot.swift`
- Added widget sync service usage in app lifecycle:
  - bootstrap success
  - daily package generation
  - tend completion
- Added deep link route handler in app root:
  - `tend://home` selects Home tab.
- Added persistent first-tend milestone fields + helpers:
  - `AppSettings.firstTendCompletedAt`
  - `AppSettings.reviewPromptShownAfterFirstTendAt`
  - `FirstTendMilestoneService`
- Added first-tend progress event type:
  - `JourneyProgressEventType.firstTendCompleted`

## AI Gateway Changes
- Updated chip prompt rules to require complete/actionable chips.
- Removed hard 4-word truncation strategy.
- Added validation-first chip normalization:
  - min/max words
  - dedupe
  - dangling ending rejection
  - fragment-start rejection
- Added deterministic contextual fallback chip generation based on:
  - journey theme
  - category/profile/recent signals
- Applied normalization context in both daily package and bootstrap package generation paths.

## Notes for Gemini
- Widget and first-tend hooks are now available; no onboarding/home sequencing UI change was made in this patch.
- Future review/paywall timing UI can be connected safely to milestone helpers without touching core completion persistence logic.
