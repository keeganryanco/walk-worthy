# Gemini Workorder: Pass 2 UI Integration

## Purpose
Gemini owns UI/UX redesign and motion for Tend on top of stable core contracts already implemented by Codex.

## Ownership Split

### Gemini owns
- Onboarding visual and interaction polish.
- Tend screen hierarchy, spacing, readability, and completion animation.
- Home visual redesign (streak suns, depth, plant presentation, paging affordances).
- Journal redesign (cards, thumbnails, grouped entries, rename flows).
- Settings UI redesign (multi-reminder management UI, support links layout, release-safe copy).
- Paywall visual implementation and first-tend sequence screens.

### Codex owns (already in place)
- AI prayer voice and output normalization contract.
- Reminder persistence + multi-reminder scheduling service.
- First-tend milestone state + orchestration primitives.
- RevenueCat paywall mode mapping from offerings.
- App/web support/legal constants.

## Core Contracts Gemini Must Use

### 1) Prayer package contract
Use `DailyJourneyPackage` fields as-is:
- `reflectionThought`
- `scriptureReference`
- `scriptureParaphrase`
- `prayer` (now enforced first-person)
- `smallStepQuestion`
- `suggestedSteps`
- `completionSuggestion`

Do not add UI-only string slicing that changes semantic meaning of prayer text.

### 2) Reminder contract
- SwiftData model: `ReminderSchedule`
- Scheduler API: `NotificationService.scheduleReminderSchedules(_:)`

Gemini should build multi-reminder add/edit/delete UI against `ReminderSchedule` rows and trigger scheduler sync after mutations.

### 3) First-tend flow contract
- Milestone state is in `AppSettings` via:
  - `firstTendCompletedAt`
  - `reviewPromptShownAfterFirstTendAt`
  - `paywallShownAfterFirstTendAt`
- Helpers:
  - `FirstTendMilestoneService`
  - `FirstTendFlowOrchestrator.nextStep(...)`

Gemini should route onboarding/post-tend UI sequence using these helpers:
- first tend value moment
- review prompt
- paywall

### 4) Paywall mode contract
- `SubscriptionService.paywallMode`
- Mode resolved by RevenueCat offering id.

Gemini should not hardcode paywall timing in view-only conditionals; consume `paywallMode` + milestone helpers.

### 5) Support/legal constants
Use:
- `AppConstants.supportEmail`
- `AppConstants.termsURL`
- `AppConstants.privacyURL`
- `AppConstants.supportURL`

### 6) Closure loop contract
- Closure prompt is required at the start of tend content when a pending prior commitment exists.
- Required question: `Did you do the step you committed to yesterday?`
- Status options: `Yes`, `Partially`, `No`.
- Core hook surfaces:
  - `FollowThroughService.pendingClosureCheck(in:currentEntryID:)`
  - `FollowThroughService.recordFollowThrough(status:for:on:at:)`
  - `JourneyProgressEventType.followThroughAnswered`
- Growth mapping is already wired in core logic; do not alter points in UI.
- Preserve emotional framing:
  - Yes: `"This grew because you followed through."`
  - Partial/No: gentle reframing and smaller-step encouragement.

## Do / Do Not Guardrails

### Do
- Keep no-scroll onboarding behavior on supported iPhone layouts.
- Use adaptive typography/layout to avoid clipping.
- Keep animation tasteful, fast, and reversible under reduce-motion settings.
- Preserve deep link behavior and core completion persistence.
- Preserve closure-loop gating (no completion bypass when closure answer is required).

### Do Not
- Do not change backend request/response schemas in this pass.
- Do not remove first-person prayer enforcement.
- Do not reintroduce release-visible RevenueCat diagnostics.
- Do not bypass `JourneyCreationPolicy` for online/offline/paywall gating.

## Integration Step 2 Notes (extra)
1. Build UI against contract surfaces first, then tune motion.
2. For first-tend sequence screens, call milestone helpers exactly once per state transition.
3. After reminder UI mutations, save SwiftData then call `scheduleReminderSchedules`.
4. Keep Home and Journal using shared journey identity + rename path so titles stay in sync everywhere.
5. If any UI idea needs new backend fields, document it in a small patch note before implementing.
6. Plant growth copy should read as evidence of consistency, not decoration.
7. Paywall copy tone should preserve commitment framing: `Don't break the commitment you just made.`

## QA focus for Gemini handoff
- No clipped text on Tend and onboarding at common dynamic type sizes.
- Reminder interactions are stable with 1..N reminders.
- Post-first-tend review/paywall sequencing is deterministic.
- Home/journal title and plant-state visuals remain synchronized.
- Closure prompt appears only when pending and supports Yes/Partially/No without clipping.
