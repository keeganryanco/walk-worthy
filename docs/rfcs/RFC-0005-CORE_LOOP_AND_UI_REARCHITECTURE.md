# RFC-0005: Tend Core Loop + UI Rearchitecture (Pass 2)

## Status
Accepted (implementation in progress)

## Owner
Codex (core contracts) + Gemini (UI/UX layer)

## Date
March 23, 2026

## 1. Goal
Ship a coordinated pass where core product logic is stable and UI can iterate rapidly without breaking behavior.

This RFC locks:
- first-person prayer voice policy,
- multi-reminder data/scheduling contract,
- post-first-tend sequencing primitives (review then paywall),
- support/legal constants,
- UI integration boundaries for Gemini.

## 2. Product Intent (Locked)
- Daily loop: reflection + scripture paraphrase + first-person prayer + one user-entered small step.
- AI orchestration remains mostly hidden from users.
- First-time monetization sequence target: first tend -> review prompt -> paywall.
- Existing journeys remain usable offline; new journey creation remains online-only.

## 3. Core Contracts (Codex Lane)

### 3.1 Prayer Voice Policy
- Prayer text must be first-person (`I/me/my/we/us/our`).
- Enforced in backend normalization and app-side validation.
- Invalid prayer outputs are retried/fallbacked to first-person-safe content.

### 3.2 Small-Step Chip Quality
- Chips must be complete phrase suggestions (no fragments).
- Validation rejects dangling endings and malformed chips.
- Fallback chip generation is deterministic and context-aware.

### 3.3 Reminders Data Contract
- New persistent model: `ReminderSchedule`.
- Supports unlimited reminder rows (`hour`, `minute`, `isEnabled`, `sortOrder`).
- `NotificationService` now supports scheduling/removing multiple reminders.
- Existing single-reminder UX can coexist while Gemini ships full multi-reminder UI.

### 3.4 First-Tend Sequencing Contract
- `AppSettings` milestone fields:
  - `firstTendCompletedAt`
  - `reviewPromptShownAfterFirstTendAt`
  - `paywallShownAfterFirstTendAt`
- Orchestration helpers:
  - `FirstTendMilestoneService`
  - `FirstTendFlowOrchestrator`

### 3.5 Paywall Mode Contract
- New paywall mode surface: `PaywallMode`.
- Resolved from RevenueCat current offering identifier.
- Safe default when offering/config is unavailable: `disabled`.
- Supported modes:
  - `disabled`
  - `firstTendReviewThenPaywall`
  - `sessionGate`

### 3.6 Support/Legal Constants
- `supportEmail`: `tend@keeganryan.co`
- `termsURL`: `https://walk-worthy-kohl.vercel.app/terms`
- `privacyURL`: `https://walk-worthy-kohl.vercel.app/privacy`
- `supportURL`: `https://walk-worthy-kohl.vercel.app/support`

## 4. UI Scope (Gemini Lane)
Gemini owns interaction design and motion on top of these contracts.

Gemini should consume (not redefine):
- first-person prayer rendering from package data,
- reminder model/service contract,
- first-tend flow orchestration state,
- paywall mode policy output.

## 5. Integration Order
1. Codex merges contracts and model/service primitives.
2. Gemini builds/refines UI using those contracts.
3. Codex performs non-UI wiring cleanup and policy checks.
4. Joint QA across onboarding, first tend, journal/home/settings.

## 6. Non-Goals in this pass
- Full widget redesign.
- Custom backend config service beyond RevenueCat offering mode mapping.
- New scripture provider licensing flow.

## 7. Risks
- SwiftData migration edges with new reminder/milestone fields.
- RevenueCat offering naming drift causing wrong paywall mode.
- UI regressions if Gemini bypasses contract APIs.

## 8. Acceptance Criteria
- Website and app support contact reflects `tend@keeganryan.co`.
- Core package prayer is consistently first-person.
- Multiple reminders can be persisted/scheduled by service layer.
- First-tend milestone data can drive review->paywall sequencing.
- RevenueCat mode surface available to policy/UI without crashes when config is missing.
