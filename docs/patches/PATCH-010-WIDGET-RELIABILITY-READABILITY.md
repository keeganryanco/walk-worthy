# PATCH-010: Widget Reliability + Readability (Small/Medium)

## Scope
- Move widget art loading to extension-local assets for deterministic rendering.
- Harden small and medium widget layouts so content remains readable and never appears blank.
- Add safe reload trigger when widget snapshot state changes materially.

## Implemented
- Added extension-only widget asset catalog at `TendWidgets/Assets.xcassets` with:
  - `WidgetArtSmallLight.imageset`
  - `WidgetArtSmallDark.imageset`
  - `WidgetArtMediumLight.imageset`
  - `WidgetArtMediumDark.imageset`
- Updated `TendSnapshotWidgetView` to:
  - bind art explicitly by family + color scheme,
  - prefer extension-local assets,
  - render gradient fallback background when an asset cannot be resolved,
  - reserve a right-side safe text zone for medium widget with readability scrim,
  - prioritize scripture + step readability over journey title.
- Added DEBUG logging in widget provider for snapshot load state and asset lookup failures.
- Updated widget kind constant usage via `AppConstants.Widget.snapshotKind`.
- Updated `WidgetSyncService` to trigger an additional targeted timeline reload when snapshot state changes materially.

## Manual QA Cache Reset Guidance
If widget previews/home rendering look stale while testing:
1. Remove all Tend widgets from Home Screen.
2. Quit the app.
3. In Simulator: run `xcrun simctl spawn booted killall SpringBoard`.
4. Relaunch app and trigger snapshot publication (open Home and generate/complete a tend).
5. Re-add small and medium Tend widgets.

## Validation Checklist
- Small and medium render art in widget gallery and on Home Screen.
- Light/dark mode selects matching artwork.
- Medium text stays in right-side safe area and remains readable on top of art.
- No active journey and no cached snapshot states show intentional fallback UI.
- Tap still deep-links to `tend://home`.
