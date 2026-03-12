# App Store Shipping Checklist

## Build and signing
- [ ] App ID and bundle identifier finalized
- [ ] Signing certificates/profiles valid
- [ ] Version and build numbers set correctly
- [ ] Release build archived and validated in Xcode Organizer

## Required in-app compliance
- [ ] StoreKit 2 subscriptions configured and retrievable
- [ ] Restore Purchases action visible and functional
- [ ] Subscription terms visible in paywall
- [ ] Free tier usable without forced payment wall on first launch

## Required external links
- [ ] Privacy Policy URL live (HTTPS)
- [ ] Support URL live (HTTPS)
- [ ] Both URLs added in App Store Connect metadata

## Content and safety review
- [ ] No fabricated/misquoted scripture
- [ ] No unsupported medical or outcome claims
- [ ] No inflammatory denominational commentary
- [ ] Religious language is respectful and non-coercive

## Accessibility
- [ ] Dynamic Type works on all core flows
- [ ] VoiceOver labels and actions complete for interactive elements
- [ ] Contrast checks pass in all key screens
- [ ] 44pt touch target minimum respected
- [ ] Reduce Motion setting honored

## Functional QA
- [ ] Onboarding completes and generates first Today card
- [ ] Today card completes in < 30 seconds path
- [ ] Journey create/edit/archive flows pass
- [ ] Timeline entries render and filter correctly
- [ ] Notification permission + reminder schedule path works
- [ ] Offline cold start and offline full usage verified
- [ ] Purchase and restore flows tested with StoreKit config

## App Store Connect metadata
- [ ] App name, subtitle, and promo text finalized
- [ ] Description finalized
- [ ] Keyword list finalized
- [ ] Screenshots for required device sizes uploaded
- [ ] App icon uploaded
- [ ] Category and age rating configured
- [ ] Privacy Nutrition Label completed

## Review notes
- [ ] Explain local-first/offline behavior clearly
- [ ] Explain subscription unlock boundaries clearly
- [ ] Provide reviewer path for testing premium flow
- [ ] Provide any demo instructions if needed

## Final pre-submit
- [ ] TestFlight smoke pass on clean install
- [ ] Crash-free startup checks complete
- [ ] Known issues log reviewed and acceptable
- [ ] Submit for review
