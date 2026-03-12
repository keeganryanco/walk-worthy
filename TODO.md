# TODO

## Phase 0: Planning complete
- [x] Reformat `Prayer App Overview.md`
- [x] Draft RFC and architecture docs
- [x] Define App Store metadata and shipping checklist
- [x] Define initial test plan and risk register
- [x] Extract skill documentation into `docs/skills/`
- [x] Capture product-owner decisions (name, monetization direction, AI direction)

## Phase 1: Project scaffold
- [x] Create Xcode project (`WalkWorthy`) with iOS deployment target
- [x] Add feature-first folder structure
- [x] Add design tokens (color, type, spacing, motion)
- [x] Add SwiftData model container and seed path
- [x] Add in-repo `site/` Next.js legal/support pages and deploy instructions

## Phase 2: Core experience
- [x] Build onboarding flow with 4-5 questions
- [x] Generate first Today card instantly
- [x] Build Today card completion flow (<30 sec path)

## Phase 3: Journeys and timeline
- [x] Journey create and detail flow (edit/archive pending)
- [x] Daily entries attached to journeys
- [x] Answered prayer timeline UI (filters pending)

## Phase 4: Monetization
- [x] Implement StoreKit 2 products and purchase flow scaffold
- [x] Implement restore purchases
- [x] Gate premium features and enforce free-tier limits

## Phase 5: Notifications and settings
- [x] Reminder scheduling/cancellation scaffold
- [ ] Notification time window from onboarding
- [x] Settings screen with subscription and support actions

## Phase 6: Quality hardening
- [ ] Add unit, integration, and UI tests
- [ ] Accessibility pass (Dynamic Type, VoiceOver, contrast, touch targets)
- [ ] Performance pass (startup and interaction smoothness)

## Phase 7: Release prep
- [ ] App Store Connect metadata completion
- [ ] Screenshots and icon finalization
- [ ] Privacy questionnaire and review notes
- [ ] TestFlight smoke pass

## Open blockers requiring owner decision
- [ ] Final recurring subscription prices
- [ ] Scripture licensing/source policy final sign-off
- [ ] Final icon file export
- [ ] Final privacy/support URLs after Vercel deploy
