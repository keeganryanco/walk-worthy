# App Icon Handoff

Place your final icon source file at:

- `design/app-icon/source/app-icon-1024.png`

## Requirements
- Size: `1024x1024`
- Format: PNG
- No transparency (recommended for App Store consistency)
- Single-color prayer icon in approved brand direction

## Generate iOS icon set
Run:

```bash
./scripts/generate_app_icons.sh
```

This will create all required iPhone + App Store icon sizes in:

- `WalkWorthy/Resources/Assets.xcassets/AppIcon.appiconset`

## Auto-fallback behavior
If `design/app-icon/source/app-icon-1024.png` is missing, the script will auto-select the first available large icon in this order:
1. `design/app-icon/light_icon_large_tend.png`
2. `design/app-icon/dark_icon_large_tend.png`
3. `design/app-icon/transparent_icon_large_tend.png`
