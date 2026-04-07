# PATCH-011: Core + UI Weeds Pass 2 (Contracts First)

## Summary
Pass 2 first integration slice: core contracts and policy surfaces were added/updated so UI iteration can proceed safely in parallel.

## Scope in this patch
- Support/legal constants alignment.
- First-person prayer enforcement in backend + app validation.
- Small-step chip fallback hardening.
- Multi-reminder model + multi-request scheduling service.
- First-tend milestone/paywall sequencing contract surfaces.
- RevenueCat-driven paywall mode mapping surface.
- Gemini handoff docs and RFC.

## Files touched (contract layer)
- `WalkWorthy/Shared/AppConstants.swift`
- `WalkWorthy/Domain/Models/AppSettings.swift`
- `WalkWorthy/Domain/Models/ReminderSchedule.swift`
- `WalkWorthy/Services/Notifications/NotificationService.swift`
- `WalkWorthy/Services/Monetization/PaywallMode.swift`
- `WalkWorthy/Services/Monetization/SubscriptionService.swift`
- `WalkWorthy/Domain/Policies/MonetizationPolicy.swift`
- `WalkWorthy/Domain/Policies/JourneyCreationPolicy.swift`
- `WalkWorthy/Services/Milestones/FirstTendMilestoneService.swift`
- `WalkWorthy/Services/Milestones/FirstTendFlowOrchestrator.swift`
- `WalkWorthy/Services/Content/DailyJourneyPackage.swift`
- `site/lib/ai/prompt.ts`
- `site/lib/ai/bootstrap.ts`
- `site/lib/ai/validate.ts`

## Gemini-facing notes
Gemini should now build Step 2 UI against the new reminder, milestone, and paywall mode surfaces without redefining policy in views.

## QA checklist
- [ ] Website support email is `tend@keeganryan.co`
- [ ] API prayer output stays first-person in bootstrap and daily package
- [ ] Reminder scheduler accepts >1 reminder row
- [ ] Paywall mode defaults safely when RC config is unavailable
- [ ] No release-only exposure of RC diagnostics in shipped UI
