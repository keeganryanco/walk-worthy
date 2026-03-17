# Onboarding Video Drop Folder

Place the onboarding intro loop file here before running asset prep:

- Preferred filename: `onboarding_intro_loop_alpha.mov`
- Accepted extensions: `.mov`, `.mp4`, `.m4v`
- Alternate names also accepted: `onboarding_intro_loop.*`
- Legacy alias also accepted: `tend_logo_loop_alpha.*`

Then run:

```bash
./scripts/prepare_assets_for_ios.sh
xcodegen generate
```

The script copies the file into app resources as:

- `WalkWorthy/Resources/BrandAssets/Videos/OnboardingIntroLoop.<ext>`
