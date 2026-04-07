# Gemini Phase 5 Targeted Handoff (Must-Fix Scope)

Last updated: March 23, 2026
Owner: Gemini (UI/UX implementation), Codex (core verification + integration QA)

## Purpose
This is the exact Phase 5 execution brief to finish unresolved work. This document overrides ambiguous interpretation from previous summaries.
For Phase 5, this file is the source of truth and supersedes prior Gemini walkthrough summaries where they conflict.

## Non-Negotiable Constraints
- Do not block on audio. Ignore `.caf`/sound work for now.
- Keep existing Codex core contracts intact (AI, follow-through logic, milestones, paywall mode wiring, reminder model/service).
- Focus this pass on shipping-quality UI/UX completion for widgets, onboarding flow order, home, and journal.

## Current Status Snapshot
- Widgets are partially implemented and wired.
- Closure loop logic is implemented in core.
- Several UX items requested by product are still missing or incorrect.

## Phase 5 Required Work

## 1) Widgets (finish fully)
Priority: P0

Requirements:
- Fix widget gallery/preview reliability so widget previews render before placement.
- Small square widget currently not working: fix rendering and preview.
- Medium rectangle widget works, but artwork does not fill the full widget area naturally.
- Both small and medium widget art must scale/fill to maximize canvas and free text space.
- Keep readability-first text layout.
- Medium text must not overlap unreadably on top of detailed art.

Asset/source references:
- Widget extension asset catalog: `TendWidgets/Assets.xcassets`
- Current widget view: `TendWidgets/TendSnapshotWidget.swift`

Acceptance criteria:
- In widget gallery, both `systemSmall` and `systemMedium` previews show artwork and text (no blank/skeleton only state unless no snapshot fallback intentionally shown).
- After adding to Home Screen, both sizes render correctly in light/dark mode.
- Art appears full-bleed/fill (not tiny/letterboxed appearance).

## 2) Onboarding fixes
Priority: P0

### 2.1 Keyboard / input UX
- Remove the extra keyboard "Next" button that appears when text fields are selected.
- It is currently annoying and non-functional.
- Keep proper keyboard dismissal behavior.

### 2.2 Journey intent text fields
- Improve styling of:
  - "What do you want to pray about?"
  - "What goal are you moving toward..."
- These should match the quality/styling direction of the name field.

### 2.3 Reminder step behavior
- Reminder scheduler screen should mirror Settings reminder section style/behavior.
- Default reminder row at 8:00 AM.
- User can edit, add more, and delete via swipe.
- Notification permission prompt must occur when user tries to continue from reminder step, before navigating to next onboarding page.
- Do not defer this prompt to after onboarding.

### 2.4 Onboarding order (explicit new order)
Use this exact sequence for the core flow segment:
1. User answers two journey questions.
2. Immediately generate first journey.
3. Show loading state while generating.
4. Walk through generated tend in broken-out pages:
   - reflection + verse
   - prayer
   - next step input
5. Show seed planted/growth reward moment.
6. Reminder setup page (with permission request on continue).
7. Widgets informational page.
8. Paywall page.

Notes:
- Keep psychology framing implemented in core: consistency and follow-through evidence.
- Keep onboarding adaptive/no-scroll across supported iPhone sizes.

## 3) Home + Journal corrections
Priority: P0

### 3.1 Tab/navigation visual regression
- Nav buttons should be visible in all tabs.
- Dark mode: inactive icons/text white, selected green.
- Light mode: inactive dark, selected green.

### 3.2 Home screen missing features
- Implement create-new-journey affordance via horizontal paging/swipe at the end of journey cards (terminal page prompt).
- Implement streak visualization.
- Improve home background treatment/dimension as planned.

### 3.3 Journal list and detail
- Journal preview must correctly show current plant image for journey.
- Remove giant "Start New Journey" text button.
- Replace with `+` action at top right of Active Journeys section.
- Journey detail screen must show current plant state.
- Entry list should show date + preview.
- Tapping an entry opens full-day detail page with complete tend content:
  - reflection
  - scripture reference/paraphrase
  - prayer
  - chosen step
  - any relevant follow-through context if available

## 4) Paywall behavior and framing
Priority: P1

- Keep paywall remote-toggle behavior controlled by existing RevenueCat mode wiring.
- Do not hardcode timing logic in UI.
- Keep commitment framing in copy direction.

## 5) Explicitly deferred for this pass
- Audio implementation (`.caf` assets/effects): deferred.
- Do not block release readiness on audio.

## Do-Not-Touch Core Contracts
- `WalkWorthy/Services/Content/*` core generation/orchestration
- `WalkWorthy/Domain/Models/*` behavior contracts unless coordinated
- `WalkWorthy/Services/Milestones/*`
- `WalkWorthy/Services/Monetization/*` policy mapping
- `site/lib/ai/*` API schema/contracts

(UI integration against these is expected; behavioral rewrites are not.)

## Required Gemini Deliverables
- Code implementation for all P0 items above.
- Updated implementation summary doc (can be `walkthrough.md` or patch ticket) with:
  - what changed
  - what remains
  - screenshots for: onboarding journey flow, reminder permission handoff, both widget sizes, home, journal list, journal entry detail
- Patch note added under `docs/patches/` for this phase.

## Codex Follow-Up After Gemini Completes
Codex will:
- Run integration QA against this checklist.
- Verify closure-loop and first-tend sequencing still work after UI updates.
- Validate widget rendering reliability on simulator and device.
- Validate no regressions in onboarding generation flow and reminder permission timing.
- Patch any contract breakages and finalize merge readiness.
