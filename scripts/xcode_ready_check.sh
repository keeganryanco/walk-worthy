#!/usr/bin/env bash
set -euo pipefail

PROJECT="WalkWorthy.xcodeproj"
SCHEME="WalkWorthy"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "❌ Xcode command line tools not found."
  exit 1
fi

echo "== Xcode =="
xcodebuild -version

echo
if [[ ! -d "$PROJECT" ]]; then
  echo "❌ Missing $PROJECT. Run: xcodegen generate"
  exit 1
fi

echo "== Project & Scheme =="
xcodebuild -project "$PROJECT" -list

echo
RUNTIMES=$(xcrun simctl list runtimes | grep -E "iOS .*\(.*\)" || true)
if [[ -z "$RUNTIMES" ]]; then
  echo "❌ No iOS simulator runtimes installed."
  echo "   Install with: xcodebuild -downloadPlatform iOS"
  echo "   Or Xcode > Settings > Components > iOS Simulator"
  exit 2
fi

echo "== iOS Simulator Runtimes =="
echo "$RUNTIMES"

echo
# Pick any available iPhone simulator destination from xcodebuild output.
DESTS=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showdestinations 2>/dev/null | grep -E "platform:iOS Simulator" || true)
if [[ -z "$DESTS" ]]; then
  echo "⚠️  No simulator destination currently available for scheme $SCHEME."
  echo "    Open Xcode once after runtime install to finish setup."
else
  echo "== Available Simulator Destinations =="
  echo "$DESTS"
fi

echo
echo "✅ Ready check complete."
