#!/usr/bin/env bash
set -euo pipefail

SRC="design/app-icon/source/app-icon-1024.png"
OUT="WalkWorthy/Resources/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "$SRC" ]]; then
  for candidate in \
    "design/app-icon/light_icon_large_tend.png" \
    "design/app-icon/dark_icon_large_tend.png" \
    "design/app-icon/transparent_icon_large_tend.png"
  do
    if [[ -f "$candidate" ]]; then
      mkdir -p "$(dirname "$SRC")"
      cp "$candidate" "$SRC"
      echo "Auto-selected icon source: $candidate"
      break
    fi
  done
fi

if [[ ! -f "$SRC" ]]; then
  echo "Missing source icon: $SRC"
  exit 1
fi

WIDTH=$(sips -g pixelWidth "$SRC" | awk '/pixelWidth/ {print $2}')
HEIGHT=$(sips -g pixelHeight "$SRC" | awk '/pixelHeight/ {print $2}')
if [[ "$WIDTH" != "1024" || "$HEIGHT" != "1024" ]]; then
  echo "Source icon must be 1024x1024, got ${WIDTH}x${HEIGHT}: $SRC"
  exit 1
fi

mkdir -p "$OUT"

make_icon() {
  local size="$1"
  local name="$2"
  sips -z "$size" "$size" "$SRC" --out "$OUT/$name" >/dev/null
}

make_icon 40 "Icon-20@2x.png"
make_icon 60 "Icon-20@3x.png"
make_icon 58 "Icon-29@2x.png"
make_icon 87 "Icon-29@3x.png"
make_icon 80 "Icon-40@2x.png"
make_icon 120 "Icon-40@3x.png"
make_icon 120 "Icon-60@2x.png"
make_icon 180 "Icon-60@3x.png"
cp "$SRC" "$OUT/Icon-1024.png"

echo "Generated AppIcon assets in $OUT"
