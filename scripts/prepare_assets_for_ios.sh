#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# Clean macOS metadata that can cause noisy diffs.
find design -name '.DS_Store' -type f -delete || true

# Canonicalize copied resources used at runtime.
./scripts/sync_brand_assets.sh
./scripts/generate_app_icons.sh

ASSET_ROOT="WalkWorthy/Resources/Assets.xcassets"
mkdir -p "$ASSET_ROOT/TendMark.imageset"
mkdir -p "$ASSET_ROOT/OnboardingReminderClock.imageset"
mkdir -p "$ASSET_ROOT/OnboardingNotificationsStack.imageset"
mkdir -p "$ASSET_ROOT/OnboardingNotificationsPhone.imageset"

if [[ -f design/app-icon/transparent_icon_large_tend.png ]]; then
  cp design/app-icon/transparent_icon_large_tend.png "$ASSET_ROOT/TendMark.imageset/tend-mark.png"
else
  cp design/app-icon/light_icon_med_tend.png "$ASSET_ROOT/TendMark.imageset/tend-mark.png"
fi
cp design/brand-assets/icons/reminders_transparent_light_mode.png "$ASSET_ROOT/OnboardingReminderClock.imageset/reminder-clock.png"
cp design/brand-assets/icons/notifications.png "$ASSET_ROOT/OnboardingNotificationsStack.imageset/notifications-stack.png"
cp design/brand-assets/icons/iphone_notifications.png "$ASSET_ROOT/OnboardingNotificationsPhone.imageset/notifications-phone.png"

write_imageset() {
  local path="$1"
  local filename="$2"
  cat > "$path/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "$filename",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
}

write_imageset "$ASSET_ROOT/TendMark.imageset" "tend-mark.png"
write_imageset "$ASSET_ROOT/OnboardingReminderClock.imageset" "reminder-clock.png"
write_imageset "$ASSET_ROOT/OnboardingNotificationsStack.imageset" "notifications-stack.png"
write_imageset "$ASSET_ROOT/OnboardingNotificationsPhone.imageset" "notifications-phone.png"

echo "Prepared iOS assets and updated app icon + onboarding images."
