# App Store Shipping Checklist

## Build and signing
- [x] App ID and bundle identifier finalized
- [x] Signing certificates/profiles valid
- [x] Version and build numbers set correctly
- [ ] Release build archived and validated in Xcode Organizer

## Required in-app compliance
- [x] StoreKit 2 subscriptions configured and retrievable
- [x] Restore Purchases action visible and functional
- [x] Subscription terms visible in paywall
- [x] First-launch paywall and free-trial flow are reviewable and explained clearly in App Review notes
- [x] Launch pricing decision is propagated correctly:
  - annual product repriced to `$49.99/year` in App Store Connect
  - secondary plan migrated from weekly to monthly at `$7.99/month`
  - RevenueCat offerings verified against the final launch catalog
- [x] Free-trial cancellation downsell is planned before launch:
  - target offer is `$2.99/month for 3 months`
  - Apple subscription offer type and RevenueCat mapping are documented
  - app-side eligibility/UI work is scoped, even if implementation is deferred

## Required external links
- [x] Privacy Policy URL live (HTTPS)
- [x] Support URL live (HTTPS)
- [x] Both URLs added in App Store Connect metadata

## Content and safety review
- [x] No fabricated/misquoted scripture
- [x] No unsupported medical or outcome claims
- [x] No inflammatory denominational commentary
- [x] Religious language is respectful and non-coercive

## Accessibility
- [x] Dynamic Type works on all core flows
- [x] VoiceOver labels and actions complete for interactive elements
- [x] Contrast checks pass in all key screens
- [x] 44pt touch target minimum respected
- [x] Reduce Motion setting honored

## Functional QA
- [x] Onboarding completes and generates first Today card
- [x] Today card completes in < 30 seconds path
- [x] Journey create/edit/archive flows pass
- [x] Timeline entries render and filter correctly
- [x] Notification permission + reminder schedule path works
- [ ] Offline cold start and offline full usage verified
- [x] Purchase and restore flows tested with StoreKit config
- [x] Subscription state QA covers:
  - active premium
  - trial active + renewing
  - trial active + canceled / non-renewing
  - expired / lapsed user

## App Store Connect metadata
- [x] App name, subtitle, and promo text finalized
- [x] Description finalized
- [x] Keyword list finalized
- [x] Screenshots for required device sizes uploaded
- [x] App icon uploaded
- [x] Category and age rating configured
- [x] Privacy Nutrition Label completed

## Review notes
- [x] Explain local-first/offline behavior clearly
- [x] Explain subscription unlock boundaries clearly
- [x] Provide reviewer path for testing premium flow
- [x] Provide any demo instructions if needed

### App Review Notes (paste into App Store Connect)
```
Tend does not require account creation or login. All core screens are accessible without credentials.

First-launch flow:
1) Complete onboarding and first journey setup.
2) User then sees post-journey setup steps (background, widget preview, reminders, review prompt).
3) Paywall appears after onboarding completion and offers a 3-day free trial with monthly/annual plans.
4) Restore Purchases is available in the paywall and in Settings > Subscription.

Subscription behavior:
- Entitlement is managed via RevenueCat + StoreKit 2.
- Premium status updates automatically after purchase/restore.
- Current review build can run paywall in dismissable mode via RevenueCat metadata for reviewer convenience.

Connectivity/offline behavior:
- Existing journeys remain usable offline from locally stored data/cached daily package records.
- Creating a brand-new journey requires internet (AI bootstrap endpoint).
- If offline during new journey creation, the app shows a clear offline message and allows continuing existing journeys.

Premium flow testing path:
- Launch app, complete onboarding, and use the paywall shown at onboarding completion.
- Use StoreKit sandbox test account for purchases.
- Use Restore Purchases in paywall footer or Settings > Subscription.

No demo account is required.
```

## Final pre-submit
- [x] TestFlight smoke pass on clean install
- [x] Crash-free startup checks complete
- [x] Known issues log reviewed and acceptable
- [ ] Submit for review
