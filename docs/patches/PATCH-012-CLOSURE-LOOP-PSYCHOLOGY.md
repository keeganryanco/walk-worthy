# PATCH-012: Closure Loop Psychology Pass

## Scope
Implements the Tend closure loop so users answer follow-through at the start of the next tend, and ties growth progression to integrity signals instead of a flat increment.

## Product behavior shipped
- Added closure prompt contract:
  - `Did you do the step you committed to yesterday?`
  - options: `Yes`, `Partially`, `No`
- Added growth mapping:
  - `Yes = +2`
  - `Partially = +1`
  - `No = +0`
  - first tend with no prior commitment keeps `+1` baseline
- Added reinforcement framing:
  - `"This grew because you followed through."`
- Added gentle reframing when follow-through is partial/no with smaller-step direction.

## Core implementation details
- Extended `PrayerEntry` with follow-through persistence:
  - `followThroughStatusRaw` (`yes | partial | no | unanswered`)
  - `followThroughAnsweredAt`
  - `followThroughForEntryID`
- Added `FollowThroughService`:
  - pending closure detection
  - growth point mapping
  - follow-through recording
  - latest answered follow-through context for AI payloads
- Added `JourneyProgressEventType.followThroughAnswered`.
- Updated tend completion flow:
  - closure answer required when pending prior commitment exists
  - growth increments now use mapped points
  - completion suggestion threshold still uses completed tend count (not growth points)

## AI contract updates
- Added `followThroughContext` to app and site request payload contracts:
  - `previousCommitmentText`
  - `previousFollowThroughStatus`
  - `daysSinceCommitment`
- Updated AI prompt rules:
  - if follow-through is partial/no, produce gentler smaller next steps
- Updated fallback/validation logic:
  - partial/no follow-through now receives smaller/easier fallback chips and question tone

## UI contract support for Gemini
- Closure-loop logic and state hooks are now in place for UI styling/polish.
- Updated Gemini docs to emphasize:
  - evidence-not-decoration framing
  - required closure gating
  - commitment framing continuity in paywall messaging

## Files touched
- `WalkWorthy/Domain/Models/PrayerEntry.swift`
- `WalkWorthy/Domain/Models/JourneyProgressEvent.swift`
- `WalkWorthy/Features/Home/HomeView.swift`
- `WalkWorthy/Features/Paywall/PaywallView.swift`
- `WalkWorthy/Services/Content/FollowThroughService.swift`
- `WalkWorthy/Services/Content/BackendDailyJourneyPackageProvider.swift`
- `WalkWorthy/Services/Content/DailyJourneyPackage.swift`
- `site/lib/ai/types.ts`
- `site/lib/ai/prompt.ts`
- `site/lib/ai/fallback.ts`
- `site/lib/ai/validate.ts`
- `site/README.md`
- `docs/GEMINI_IMPLEMENTATION_BRIEF.md`
- `docs/GEMINI_WORKORDER_PASS2.md`
