# Xcode Setup and Run Guide

## Minimum needed to run in Xcode
1. Xcode installed and selected (`xcode-select -p`).
2. iOS Simulator runtime installed (from Xcode Components or CLI).
3. Generated project (`WalkWorthy.xcodeproj`).

## Fast path
Run from repo root:

```bash
./scripts/bootstrap_xcode.sh
```

Then open:

```bash
open WalkWorthy.xcodeproj
```

## If simulator runtime is missing
Install via CLI:

```bash
xcodebuild -downloadPlatform iOS
```

Or in Xcode:
- `Xcode > Settings > Components`
- Install latest `iOS Simulator` runtime

## Verify readiness

```bash
./scripts/xcode_ready_check.sh
```

## Run in Xcode
1. Open `WalkWorthy.xcodeproj`.
2. Scheme: `WalkWorthy`.
3. Destination: iPhone simulator (e.g., latest iPhone runtime).
4. Press Run (`Cmd+R`).

## StoreKit local testing
Use the product IDs already scaffolded in app code:
- `co.keeganryan.walkworthy.premium.weekly`
- `co.keeganryan.walkworthy.premium.annual`

You can attach a StoreKit config file to the scheme in Xcode:
- `Product > Scheme > Edit Scheme... > Run > Options > StoreKit Configuration`

## App icon handoff
Place icon source at:
- `design/app-icon/source/app-icon-1024.png`

Generate icon variants:

```bash
./scripts/generate_app_icons.sh
```
