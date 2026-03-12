#!/usr/bin/env bash
set -euo pipefail

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing xcodegen via Homebrew..."
  brew install xcodegen
fi

echo "Generating project from project.yml..."
xcodegen generate

echo "Attempting to ensure iOS simulator runtime is installed..."
if ! xcrun simctl list runtimes | grep -q "iOS"; then
  echo "No iOS simulator runtime detected. Starting install (large download)..."
  xcodebuild -downloadPlatform iOS || true
fi

./scripts/xcode_ready_check.sh || true

cat <<MSG

Next steps:
1. Open WalkWorthy.xcodeproj in Xcode.
2. Select scheme WalkWorthy + any iPhone simulator runtime.
3. Press Run.

MSG
