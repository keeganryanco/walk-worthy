# Tend Brand Asset Drop Zone

Put your source brand files here. I will ingest and wire them into the app.

## Logos
- Source drop: `design/brand-assets/logos/`
- iOS runtime copy target: `WalkWorthy/Resources/BrandAssets/Logos/`

Recommended files:
- `tend-logo-primary.svg` or `tend-logo-primary.pdf`
- `tend-wordmark.svg` or `tend-wordmark.pdf`
- `tend-mark.svg` or `tend-mark.pdf`

## Icons
- Source drop: `design/brand-assets/icons/`
- iOS runtime copy target: `WalkWorthy/Resources/BrandAssets/Icons/`

Recommended files:
- `notification_card_1.png`
- `notification_card_2.png`
- `notifications.png`
- `iphone_notifications.png`
- `reminders_transparent_light_mode.png`

## Fonts
- Source drop: `design/brand-assets/fonts/`
- iOS runtime copy target: `WalkWorthy/Resources/BrandAssets/Fonts/`

Required families for current design system:
- Plus Jakarta Sans (700/500)
- Inter (400)

Accepted formats: `.ttf`, `.otf`

## After you add files
Run:

```bash
./scripts/prepare_assets_for_ios.sh
```

This command will:
1. Sync and normalize brand assets into `WalkWorthy/Resources/BrandAssets/`.
2. Generate `AppIcon.appiconset`.
3. Refresh onboarding image assets in `Assets.xcassets`.
