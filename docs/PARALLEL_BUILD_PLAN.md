# Parallel Build Plan (Gemini UI + Codex Core)

## Goal
Run two simultaneous tracks with minimal merge conflict:
1. Gemini: UI/UX and animation polish.
2. Codex: AI content, memory, journey mechanics, analytics, monetization plumbing.

## Ownership split

## Gemini-owned files/folders (primary)
- `WalkWorthy/Features/Onboarding/*`
- `WalkWorthy/Features/Today/*` (or new Home UI files)
- `WalkWorthy/Features/Journeys/*`
- `WalkWorthy/Features/Timeline/*` (if used for Journal UX)
- `WalkWorthy/Features/Settings/*` (UI only)
- `WalkWorthy/DesignSystem/*` (visual tokens/components/motion helpers)
- UI-facing docs and patch notes

## Codex-owned files/folders (primary)
- `WalkWorthy/Domain/Models/*` (memory/progression fields)
- `WalkWorthy/Domain/Policies/*`
- `WalkWorthy/Services/Content/*`
- `WalkWorthy/Services/Monetization/*`
- `WalkWorthy/Services/Analytics/*` (new)
- `WalkWorthy/Shared/*` core contracts/config
- architecture/RFC docs for AI/offline/analytics/revenue flows

## Shared touchpoints (coordinate)
- `WalkWorthy/App/RootView.swift`
- `WalkWorthy/App/MainTabView.swift`
- `project.yml`
- `WalkWorthy/Resources/Info.plist`
- `WalkWorthy/Features/Onboarding/OnboardingFlowView.swift` (Gemini owns flow, Codex added intro-loop media hook)

Rule: when shared files change, integrate via small, frequent merges and keep one owner at a time.

## Dependency order

## Step 1 (Codex first, small)
Codex defines stable contracts:
- Daily content payload model
- Journey memory model
- Progress/watering event model
- Provider interfaces for AI/analytics/monetization

Gemini can start UI immediately using mock/sample data if contracts are not yet merged.

## Step 2 (parallel)
- Gemini implements new UX screens/animations and wires to mock view models.
- Codex implements real domain/services behind protocols.

## Step 3 (integration)
- Swap mock providers for real providers in feature view models.
- Resolve shared tab/navigation changes.
- Full regression test pass.

## Step 4 (stabilization)
- Dark mode/accessibility pass.
- Analytics event validation.
- Documentation and patch logs complete.

## Milestones
1. M1: Contracts merged + mock data available.
2. M2: Gemini UI pass complete with transitions and onboarding review page.
3. M3: AI generation + memory + journey progression wired.
4. M4: PostHog + RevenueCat integrated with 3-day no-paywall gating logic.
5. M5: QA, docs, release checklist refresh.

## Current status
- M1: Complete
- M2: In progress (Gemini-owned)
- M3: In progress (Codex-owned)
- M4: Partial (StoreKit in place; RevenueCat/PostHog pending)
- M5: Pending
