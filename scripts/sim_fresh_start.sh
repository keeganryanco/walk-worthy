#!/usr/bin/env bash
set -euo pipefail

DEVICE_NAME="${1:-iPhone 17}"
APP_BUNDLE_ID="co.keeganryan.walkworthy"
UI_TEST_RUNNER_BUNDLE_ID="co.keeganryan.walkworthy.uitests.xctrunner"

echo "Shutting down simulators..."
xcrun simctl shutdown all || true

echo "Booting simulator: ${DEVICE_NAME}"
xcrun simctl boot "${DEVICE_NAME}" || true

# Ensure Simulator app is frontmost for reliability.
open -a Simulator >/dev/null 2>&1 || true

echo "Removing app + UI test runner from booted simulator..."
xcrun simctl uninstall booted "${APP_BUNDLE_ID}" || true
xcrun simctl uninstall booted "${UI_TEST_RUNNER_BUNDLE_ID}" || true

echo "Cleaning DerivedData for this project..."
rm -rf ~/Library/Developer/Xcode/DerivedData/WalkWorthy-*

echo "Regenerating project..."
xcodegen generate >/dev/null

echo "Done. Open Xcode and press Cmd+R on scheme WalkWorthy."
