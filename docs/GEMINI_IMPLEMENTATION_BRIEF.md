# Gemini Implementation Brief: Tend (UI/UX + Core Loop)

## 1. Objective
Implement the next production pass of Tend focused on:
1. A polished onboarding wow moment.
2. Core app loop centered on prayer-to-action with visual reward.
3. Safe, testable, repo-hygienic delivery in this codebase.

This brief captures current brainstorming decisions and constraints.

## 1.1 Scope ownership (Gemini vs Codex)
- Gemini owns: UI/UX implementation and interaction polish.
- Codex owns: AI/content engine, memory logic, journey progression logic, analytics plumbing, monetization plumbing.
- Gemini should consume Codex interfaces/contracts and avoid changing core AI/memory business logic files.

### 1.1.1 Core interfaces now available from Codex
Gemini should integrate against these existing services/contracts:
- `JourneyContentService` for daily package retrieval/prefetch behavior.
- `JourneyMemoryService` for journey memory snapshot updates.
- `JourneyProgressService` for package-generated / step-completed / journey-completed event logging.
- `JourneyCreationPolicy` for offline/paywall/free-tier creation gating.
- `ConnectivityService` for online/offline state-aware UI behavior.

## 1.2 Mandatory startup checklist for Gemini
Before coding, review:
1. `README.md`
2. `docs/README.md`
3. `docs/skills/*` (relevant product/design skills)
4. `docs/BRAND_GUIDELINES.md`
5. `docs/PARALLEL_BUILD_PLAN.md`

Gemini should summarize understanding in docs before implementation starts.

## 2. Product Direction (Current)
- App name: `Tend`
- Core promise: prayer -> small action -> reflection -> visible growth over time.
- Tone: sincere, grounded, contemporary.
- UX anchor: plant-growth metaphor as reinforcement, not gamification overload.
- Platform: iOS-first, SwiftUI, SwiftData, local-first.

## 3. UX Concept To Implement

### 3.1 Onboarding wow moment
- Generated from onboarding answers.
- Initial result should be a generic but personalized baseline.
- Visually rewarding moment: first journey starts as a sprout.
- Add tasteful animation (sprout emergence, subtle glow, or progress pulse).
- Keep latency low: fast render, no long blank states.
- Add an onboarding review/rating request page near onboarding completion.

### 3.1.1 Onboarding layout guardrail
- Do not heavily alter the existing onboarding core layout that is already in place.
- New onboarding pages (e.g., first-journey reveal/review page) can be more experimental.
- Onboarding must remain no-scroll on supported iPhones; adapt typography/layout/components per viewport instead of introducing vertical scroll.

### 3.2 Journey reward loop
- Each journey is represented by a plant state (seed -> sprout -> young plant -> mature plant).
- Daily participation (prayer + chosen step completion) can "water" the plant.
- Journey completion (user indicates they generally attained desired outcome) mints a "memory plant" in history.
- Reward should feel reflective and meaningful, not arcade-like.

### 3.3 Home/navigation structure
- Move toward 3 tabs total:
1. `Home`: vertically scrollable active journeys with plant state, name, and small daily check indicators (few past + few upcoming).
2. `Journal`: active + past journeys in log/list format (tap into details/history).
3. `Settings`.

### 3.4 Motion/animation expectations
- Creative freedom is encouraged for animation and transitions on new surfaces.
- Good candidates:
  - staggered fade-ins
  - slide-ins for tab transitions/home modules
  - loading animations that feel warm and alive
  - subtle state transitions for plant growth
- Avoid overwhelming motion; preserve readability and responsiveness.

## 4. AI Content Mechanism (Brainstorming Baseline)

## 4.1 Daily generated package (per user request/day)
LLM should generate one structured package:
1. Reflection thought
2. Scripture reference (exact ref, e.g. `Philippians 4:6-7`)
3. Scripture paraphrase (no translation label shown in UI)
4. Prayer text
5. Small-step prompt: "What small step could you take today?"
6. Suggested small steps (2-4 concise options)

Suggested response contract:

```json
{
  "reflectionThought": "string",
  "scriptureReference": "Book X:Y[-Z]",
  "scriptureParaphrase": "string",
  "prayer": "string",
  "smallStepQuestion": "What small step could you take today?",
  "suggestedSteps": ["string", "string", "string"]
}
```

### 4.2 Memory behavior
- Strong memory per journey:
  - Journey goal
  - recent entries/check-ins
  - wins, blockers, prior step patterns
  - tone preference
- Light memory across journeys:
  - broad preferences only (few tags + short summary)
  - avoid heavy cross-context bleed
- Goal: personal relevance without obvious "this is AI-generated" feel.

### 4.3 Guardrails
- No fabricated verse references.
- Scripture text shown as paraphrase + reference.
- Avoid unsupported promises/claims.
- Keep outputs practical, specific, and short.

## 5. Brand and Asset Requirements

## 5.1 Active brand system
- Colors:
  - `#FFFFFF` white
  - `#4CAF7D` grow green
  - `#F0C060` morning gold
  - `#F5F5F3` surface
  - `#1A1A1A` near black
  - `#0F0F0F` dark background
  - `#888884` muted
- Typography:
  - Plus Jakarta Sans (display/heading)
  - Inter (body/caption)

## 5.2 Asset source-of-truth in this repo
- App icon source: `design/app-icon/source/app-icon-1024.png`
- Transparent in-app mark source: `design/app-icon/transparent_icon_large_tend.png`
- Brand assets drop:
  - `design/brand-assets/logos/`
  - `design/brand-assets/icons/`
  - `design/brand-assets/fonts/`

## 5.3 Required prep commands
Run before UI implementation/testing:

```bash
./scripts/prepare_assets_for_ios.sh
xcodegen generate
```

## 5.4 Onboarding intro loop contract (Codex-implemented)
- Intro screen now supports a transparent logo loop via:
  - `WalkWorthy/Features/Onboarding/OnboardingIntroLoopView.swift`
  - used in `WalkWorthy/Features/Onboarding/OnboardingFlowView.swift` on step `.intro`
- Do not remove this hook while iterating onboarding visuals; style/layout around it is fine.
- Asset source drop folder:
  - `design/brand-assets/video/` (see `README.md` in that folder)
- Runtime filename expected in app bundle:
  - `OnboardingIntroLoop.mov` (or `.mp4` / `.m4v`)
- Sync/update commands:
  - `./scripts/prepare_assets_for_ios.sh`
  - `xcodegen generate`

## 6. Repo-Safe Implementation Workflow

## 6.1 Branching and commits
- Work in small, focused commits.
- Do not mix refactor + feature + asset churn in one commit.
- Keep project generation deterministic (`project.yml` is source of truth).

## 6.2 Non-destructive git hygiene
- Never use `git reset --hard` or discard unrelated local changes.
- If unexpected unrelated file changes appear, stop and review before proceeding.

## 6.3 Xcode/project hygiene
- Always regenerate after project-setting edits:

```bash
xcodegen generate
```

- Use scripts for repeatability:
  - `./scripts/prepare_assets_for_ios.sh`
  - `./scripts/sim_fresh_start.sh`

## 6.4 Build/test commands
- Build:

```bash
xcodebuild -project WalkWorthy.xcodeproj -scheme WalkWorthy -destination 'generic/platform=iOS Simulator' build
```

- Test:

```bash
xcodebuild -project WalkWorthy.xcodeproj -scheme WalkWorthy -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## 6.5 Documentation requirement
- Gemini must document every material change.
- At minimum:
  - update relevant docs in `docs/`
  - add/update patch note(s) in `docs/patches/`
  - include rationale for animation and UX experiments

## 7. Implementation Phases for Gemini

## Phase A: Onboarding wow polish
- Keep current content flow.
- Refine scale/layout consistency across iPhone sizes.
- Add sprout animation on first journey creation.
- Ensure dark mode compatibility in onboarding.
- Add onboarding review page flow.

### 3.1.2 Review step intent (important clarification)
- The onboarding review step is intended to drive an App Store rating/review prompt.
- It is **not** intended to collect onboarding thumbs-up/thumbs-down sentiment.
- Creative freedom is encouraged for this page's visual treatment, but the outcome should be:
  - clear prompt to rate Tend,
  - option to skip,
  - no UX that implies product-survey collection is the primary goal.

### 3.1.3 Do-not-break guardrails
- You can continue refining UI/UX aggressively, motion included.
- Preserve existing Codex integration hooks and contracts unless coordinated:
  - onboarding intro loop media hook,
  - AI/content/memory service contracts,
  - current build/test commands and repo hygiene.
- If a refinement risks breaking existing flow, choose additive changes first and document rationale in patch notes.

## Phase B: Home journey growth view
- Replace current Today-first emphasis with plant-centric active journeys surface.
- Add per-journey daily participation indicators (small recent/pending boxes).
- Wire "mark step complete" => water/progress action.

## Phase C: Journal + Settings tab finalization
- Journal screen for active/past entries and memory plants.
- Settings cleanup and dark mode controls where needed.
- Confirm exactly 3 tabs.

## Phase D: AI daily package + memory
- Out of scope for Gemini (Codex-owned). Gemini may integrate against provided interfaces only.

## 8. Minimum Acceptance Criteria
1. App displays as `Tend` on device/simulator.
2. Onboarding is centered and adaptive across supported iPhones.
3. Onboarding includes a visually rewarding sprout moment.
4. Home tab shows multiple active journeys with distinct plant states.
5. Completing small step updates visual growth state.
6. Journal tab exposes active + past journey history.
7. Dark mode works without unreadable contrast regressions.
8. AI package generation follows structured format and no invalid verse refs.
9. Build + tests pass with repo commands above.

## 9. Notes on Inspiration
- Visual inspiration from premium, high-polish apps (e.g., Opal-like reward feel) is acceptable.
- Do not clone proprietary visual identity one-to-one.
- Preserve Tend’s own brand language and spiritual-product tone.
