# Localization Workflow (2026-04-08)

Use this every time you add or expand app languages.

Current supported app locales:
- `en`
- `es`
- `pt-BR`
- `de`
- `ja`
- `ko`

## 1) String authoring rule
- Add new UI keys to `WalkWorthy/Resources/en.lproj/Localizable.strings` first.
- Copy those keys into every supported locale file (`es.lproj`, `pt-BR.lproj`, future locales).
- Prefer `L10n.string(...)` in SwiftUI for app-level language switching.
- Avoid new hardcoded `Text("...")`, `Button("...")`, `Label("...")`, `TextField("...")`, and `.alert("...")` literals.

## 2) Add a new language (example: Korean)
1. Add `WalkWorthy/Resources/ko.lproj/Localizable.strings`.
2. Add language case to `WalkWorthy/Shared/AppLanguage.swift`.
3. Extend language-dependent logic in:
- `WalkWorthy/Services/Content/DailyJourneyPackage.swift`
- `WalkWorthy/Services/Content/JourneyContentService.swift`
- Backend prompt + validator language routing (`site/`).
4. Add RevenueCat metadata suffix support if needed (for legal lines, keep manual override policy).

## 3) Mandatory coverage check
Run:

```bash
./scripts/check_localization_coverage.sh
```

What it does:
- Fails if any locale is missing keys from `en.lproj`.
- Fails if active UI files still contain hardcoded SwiftUI string literals.
- Ignores legacy `OnboardingFlowView.swift` (inactive path) and debug-only fallback diagnostics.

## 4) Manual QA pass (required)
- Settings language toggle: `English -> Español -> Português (Brasil) -> Deutsch -> 日本語 -> 한국어 -> English`.
- Onboarding (active `ExperimentalOnboardingFlowView`) in each language.
- Home, Journal, Settings, and Paywall labels.
- Verify generated new Tend content language for each locale.
- Verify no clipping at large Dynamic Type sizes.

## 5) Release gate
Do not ship a new language until:
- Coverage script passes.
- Core-screen manual QA pass is complete.

## 6) Next-language playbook (Korean/Japanese/Germanic)
1. Add locale file and wire `AppLanguage`:
- `ko.lproj`, `ja.lproj`, `de.lproj` (or selected Germanic locale).
- Add enum case + `localizationResourceCandidates`.
2. Add/translate all keys in `Localizable.strings`.
3. Extend language routing:
- iOS: `aiLanguageCode`, `remoteLocalizationLocaleCode`.
- Backend: `/api/v1/localize` normalization and prompt target-language handling.
4. Extend language-aware validators/fallbacks for AI package generation.
5. Run:
- `./scripts/check_localization_coverage.sh`
6. Manual QA matrix:
- onboarding + home + journal + settings + paywall
- new content generation
- remote copy translation (PostHog + RevenueCat)
