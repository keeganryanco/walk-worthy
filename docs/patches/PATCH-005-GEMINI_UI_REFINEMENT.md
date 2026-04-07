# PATCH 005: Gemini UI Refinement (Tend)

**Date:** March 17, 2026
**Author:** Gemini (UI/UX)
**Focus:** Onboarding UX, Home Tab Conversion, Dark Mode Polish

## Objective
Implement Phase A-C from the `GEMINI_IMPLEMENTATION_BRIEF.md`, focusing purely on user experience, responsive layout scalability, and interaction polish without touching Codex-owned AI logic.

## Changes Included
1. **Onboarding Layout Scaling:** Removed the static 590x1278 Figma canvas constraints in `OnboardingFlowView.swift`. Used dynamic font sizing and standard SwiftUI relative layout elements to provide native letterbox-free scaling on all device sizes.
2. **Onboarding Wow Moment:** Implemented the `creationSprout` onboarding step. When the user finishes their setup, they receive a visually pleasing glowing sprout animation before proceeding.
3. **Onboarding Review Request:** Added a `review` step offering users a quick thumb-up/thumb-down mechanism to rate the onboarding flow immediately after creating their first journey.
4. **Dark Mode Colors:** Refactored `WWColor.swift` to use `UIColor` dynamic providers under the hood, translating the `static let` constant semantic colors (like `white`, `surface`, `muted`, `nearBlack`) natively for dark mode.
5. **Navigational Tab Reduction:** Simplified the `MainTabView.swift` architecture down to 3 tabs: `Home`, `Journal`, and `Settings`. Removed obsolete `TimelineView`, `TodayView`, and `JourneysView` root directories.
6. **HomeView Journey Hub:** Built `HomeView.swift` to present "plant-centric active journeys," utilizing the `PrayerJourney` dynamic state. Journeys graphically show plant maturity (🌱 -> 🌿 -> 🪴) based on completion counts.
7. **Daily Check Indicators:** Included 7-dot participation indicators for each journey on the Home tab. 
8. **Journal Tab Refactoring:** Built `JournalView.swift` to consolidate active and past memory entries, integrating `JourneyDetailView` and generic timeline components together.
9. **Settings Pass:** Aligned the `SettingsView.swift` status fields to use `WWColor.growGreen` ensuring compatibility with the active design language.

## Rationale for UX Experiments
- **Responsive Geometry:** We deviated heavily from precise Figma padding because statically scaling constraints caused heavy letterboxing that felt unpolished on wider devices (e.g. iPad) or shorter devices (e.g. iPhone SE). By employing Apple's standard dynamic margins, we maintain the "book-like" padding with reliable edge adherence.
- **Sprout Growth Pulse:** The `creationSprout` step leverages a continuous heartbeat glow and soft spring scale to give the interface an "alive", un-robotic feel—supporting the faith action metaphor instead of loud gamification.

## Verification
- Project builds cleanly under `xcodegen generate`
- `xcodebuild test` continues to pass as standard logic wasn't modified
- Safe integration with all `Codex` interfaces (`JourneyContentService`, `JourneyMemorySnapshot`).

## Update: March 23, 2026 - Phase 5 Targeted Handoff Execution
**Focus:** Onboarding Flow Orchestration, RootView Inline Generation, Home/Journal Enhancements, Streak Overlays.

### Changes Included
1. **Widget Scaling:** Fixed snapshot model constructor argument ordering and corrected image rendering layout dimensions so artwork scales full-canvas on small/medium sizes without letterboxing or text overlap.
2. **Onboarding Typography & Inputs:** Streamlined the journey setup phase by dropping redundant keyboard submit toolbars. Styled the multi-line "What do you want to pray about?" inputs using native `TextField(axis: .vertical)` encapsulating premium dark-mode borders.
3. **Onboarding Reminder List:** Translated the legacy DatePicker input to match Settings logic exactly, constructing a dynamic SwiftData `List` enabling limitless schedule additions, default 8:00 AM configurations, and swipe-to-delete behaviors securely.
4. **Onboarding Inline Orchestration:** Restructured `RootView.swift` to pass `.generateJourneyInline` callbacks gracefully to `ExperimentalOnboardingFlowView`. This directly renders the First Tend components natively inline without abandoning the Onboarding sequence prematurely.
5. **DuoLingo-Style Streak Overlay:** Hooked post-tend execution logic to a new immersive `StreakOverlayView`. Taps into global `WidgetSyncService` streak algorithms to populate consecutive milestone stats above an oversized Sun visual when users commit actions on the Home screen.
6. **Immersive Journal List:** Added an internal navigation bar to `JournalView.swift`, placing Journey creation behind a trailing plus icon to strip out overbearing buttons. Seeded plant thumbnails elegantly back into the timeline layout constraint.
7. **Journal Full-Day Tend History:** Appended a `HistoricalTendDetailView` module to `JournalView.swift` to recreate the beautiful dark-mode interface of the modal Tend interaction card, dynamically loading static action steps and reflection prayers generated during past records into an easily accessible list format.

### Verification
- Full app lifecycle compilation passes with strict typing requirements checked.
- No `Codex` models or services were deleted or overridden.
