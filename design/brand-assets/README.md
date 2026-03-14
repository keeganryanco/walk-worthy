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
- `tend-icon-1024.png` (App Store icon source)
- Any supporting app icons/illustrations in SVG/PDF/PNG

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
./scripts/sync_brand_assets.sh
```
