# RFC: Walk Worthy MVP

- **Status:** Draft (Pre-implementation)
- **Date:** March 12, 2026
- **Platform:** iOS-first
- **Subtitle:** Pray & Do

## 1. Overview
Walk Worthy is a private, local-first Christian prayer app that creates a repeatable daily practice:

**Pray -> Do one concrete step -> Reflect -> See what changed over time.**

The MVP is intentionally offline-first, accountless, and backend-free. It prioritizes depth of habit over breadth of features.

## 2. Problem
Many users pray consistently in moments but struggle to translate prayer into specific daily action and long-term reflection. Existing apps often emphasize content consumption over disciplined follow-through.

## 3. Goals
- Enable daily spiritual follow-through in < 60 seconds.
- Make first value immediate after onboarding (instant Today card).
- Preserve user privacy via local-first data model.
- Provide monetization with clear free vs premium value.
- Reach App Review-ready quality from day one.

## 4. Non-goals (MVP)
- Social/community prayer wall
- Church management features
- Backend sync and multi-device merge
- Account system
- AI-generated scripture quotations

## 5. User personas
- Individual Christians who want more faithful daily discipline.
- Users who prefer private reflection over social sharing.
- Busy users needing short, concrete steps, not long sessions.

## 6. Product requirements
### Core features
1. Onboarding
- What are you praying about?
- How do you want to grow?
- When do you want to show up?
- What gets in the way?
- Generate first Today card instantly

2. Today card
- Short prayer prompt
- One concrete action step
- Optional reflection
- Completion possible in under 30 seconds

3. Prayer journeys
- Tagged prayer projects
- Daily entries
- Answered prayer timeline

4. Monetization
- Free tier with limited active journeys
- Premium unlocks unlimited journeys, templates, export, widgets
- StoreKit 2 subscriptions + restore purchases

5. App Review readiness
- Privacy-first local data
- No misleading religious claims/quotes
- Review notes + demo path if needed

### UX/design constraints
- Editorial, warm, contemporary visual language
- One clear primary action per screen
- 44pt touch targets minimum
- Minimal modal friction

## 7. Architecture decision
Use a local-only architecture:
- **SwiftUI** for app/navigation/presentation
- **SwiftData** for domain persistence
- **StoreKit 2** for entitlements
- **UserNotifications** for reminder loop

No backend in MVP. This keeps scope tight, reduces privacy risk, and speeds shipping.

## 8. Data model (MVP)
- `PrayerJourney`
  - `id`, `title`, `category`, `createdAt`, `isArchived`, `colorToken`
- `PrayerEntry`
  - `id`, `journeyID`, `date`, `prompt`, `actionStep`, `reflection`, `completedAt`
- `AnsweredPrayer`
  - `id`, `journeyID`, `linkedEntryID`, `notes`, `date`
- `OnboardingProfile`
  - growth goals, preferred reminder window, friction tags
- `AppSettings`
  - notification settings, premium entitlement cache, content policy toggles

## 9. Monetization model
- Free:
  - 1-2 active journeys
  - Base Today flow
- Premium:
  - Unlimited journeys
  - Timeline history depth
  - Templates
  - Export
  - Widgets

Paywall trigger candidates:
- After 2 completed sessions
- On creation of 2nd/3rd journey
- On timeline access attempt

## 10. Privacy and compliance
- All user-generated content stored on device
- No account required
- No hidden tracking SDKs in MVP
- Required external pages:
  - Privacy Policy URL
  - Support URL

Religious content safeguards:
- Avoid fabricated quotations
- Do not present paraphrase as direct scripture quote
- Avoid inflammatory or denomination-combat framing

## 11. Accessibility baseline
- Dynamic Type support across all primary screens
- VoiceOver labels/traits for all controls
- Sufficient color contrast in all themes
- Reduce Motion support for animation alternatives
- Minimum touch target sizing (44pt)

## 12. Test strategy summary
- Unit tests for domain logic and limits
- Integration tests for StoreKit entitlement flow
- UI tests for onboarding -> today card -> completion
- Manual QA checklist for notifications, paywall, and offline behavior

## 13. Milestones (rapid production)
1. Project scaffold + design tokens + domain models
2. Onboarding and Today card flow
3. Journey list/detail + timeline
4. Subscriptions + entitlement gating
5. Notifications + settings
6. Accessibility + testing hardening
7. App Store packaging

## 14. Open decisions required from product owner
See [RESOURCE_REQUESTS.md](./RESOURCE_REQUESTS.md).
