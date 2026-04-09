#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOURCES_DIR="$ROOT_DIR/WalkWorthy/Resources"
BASE_LOCALE="${1:-en}"
BASE_FILE="$RESOURCES_DIR/${BASE_LOCALE}.lproj/Localizable.strings"

if [[ ! -f "$BASE_FILE" ]]; then
  echo "Base localization file not found: $BASE_FILE" >&2
  exit 1
fi

extract_keys() {
  local file="$1"
  grep -E '^[[:space:]]*".*"[[:space:]]*=' "$file" \
    | sed -E 's/^[[:space:]]*"(([^"\\]|\\.)*)"[[:space:]]*=.*/\1/' \
    | LC_ALL=C sort -u
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

base_keys_file="$tmp_dir/base.keys"
extract_keys "$BASE_FILE" > "$base_keys_file"

failed=0
echo "== Localization key parity check (base: $BASE_LOCALE) =="
for locale_file in "$RESOURCES_DIR"/*.lproj/Localizable.strings; do
  locale_dir="$(basename "$(dirname "$locale_file")")"
  locale="${locale_dir%.lproj}"

  locale_keys_file="$tmp_dir/$locale.keys"
  extract_keys "$locale_file" > "$locale_keys_file"

  missing_file="$tmp_dir/$locale.missing"
  extra_file="$tmp_dir/$locale.extra"

  comm -23 "$base_keys_file" "$locale_keys_file" > "$missing_file"
  comm -13 "$base_keys_file" "$locale_keys_file" > "$extra_file"

  missing_count="$(wc -l < "$missing_file" | tr -d ' ')"
  extra_count="$(wc -l < "$extra_file" | tr -d ' ')"

  if [[ "$missing_count" -gt 0 ]]; then
    failed=1
    echo "[$locale] Missing keys: $missing_count"
    sed 's/^/  - /' "$missing_file"
  else
    echo "[$locale] Missing keys: 0"
  fi

  if [[ "$extra_count" -gt 0 ]]; then
    echo "[$locale] Extra keys (informational): $extra_count"
  fi

done

echo
echo "== Hardcoded SwiftUI string scan (active UI) =="
hardcoded_matches="$(
  rg -n \
    'Text\("[^"]+"\)|Button\("[^"]+"\)|Label\("[^"]+"\)|TextField\("[^"]+"\)|alert\("[^"]+"\)|navigationTitle\("[^"]+"\)|accessibilityLabel\("[^"]+"\)|accessibilityHint\("[^"]+"\)' \
    "$ROOT_DIR/WalkWorthy" \
  | rg -v '(^|:)\s*//' \
  | rg -v 'OnboardingFlowView\.swift' \
  | rg -v 'Text\("Plant asset missing"\)|Text\("themeSuffix=' \
  | rg -v 'Text\(".*\\\(.*"\)' \
  | rg -v 'Text\(" \\\(text\\\)"\)' \
  || true
)"

if [[ -n "$hardcoded_matches" ]]; then
  echo "$hardcoded_matches"
  echo
  echo "Hardcoded-string check failed: localize the active UI strings listed above." >&2
  failed=1
else
  echo "No hardcoded active UI strings detected."
fi

if [[ "$failed" -ne 0 ]]; then
  echo
  echo "Localization coverage check failed: at least one locale is missing keys from ${BASE_LOCALE}.lproj." >&2
  exit 1
fi

echo
echo "Localization coverage check passed."
