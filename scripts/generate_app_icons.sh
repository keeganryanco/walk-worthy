#!/usr/bin/env bash
set -euo pipefail

SRC="design/app-icon/source/app-icon-1024.png"
OUT="WalkWorthy/Resources/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "$SRC" ]]; then
  echo "Missing source icon: $SRC"
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
