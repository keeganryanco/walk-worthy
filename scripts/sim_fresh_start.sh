#!/usr/bin/env bash
set -euo pipefail

DEVICE_NAME="${1:-iPhone 17}"
APP_BUNDLE_IDS=(
  "co.keeganryan.tend"
  "co.keeganryan.walkworthy"
)
UI_TEST_RUNNER_BUNDLE_IDS=(
  "co.keeganryan.tend.uitests.xctrunner"
  "co.keeganryan.walkworthy.uitests.xctrunner"
)

echo "Shutting down simulators..."
xcrun simctl shutdown all || true

echo "Booting simulator: ${DEVICE_NAME}"
xcrun simctl boot "${DEVICE_NAME}" || true

# Ensure Simulator app is frontmost for reliability.
open -a Simulator >/dev/null 2>&1 || true

echo "Removing app + UI test runner from booted simulator..."
for bundle_id in "${APP_BUNDLE_IDS[@]}"; do
  xcrun simctl uninstall booted "${bundle_id}" || true
done
for bundle_id in "${UI_TEST_RUNNER_BUNDLE_IDS[@]}"; do
  xcrun simctl uninstall booted "${bundle_id}" || true
done

echo "Cleaning DerivedData for this project..."
rm -rf ~/Library/Developer/Xcode/DerivedData/WalkWorthy-*

echo "Regenerating project..."
xcodegen generate >/dev/null

echo "Done. Open Xcode and press Cmd+R on scheme WalkWorthy."
