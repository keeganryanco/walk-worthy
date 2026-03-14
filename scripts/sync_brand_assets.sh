#!/usr/bin/env bash
set -euo pipefail

mkdir -p WalkWorthy/Resources/BrandAssets/Logos
mkdir -p WalkWorthy/Resources/BrandAssets/Icons
mkdir -p WalkWorthy/Resources/BrandAssets/Fonts

rsync -av --delete --exclude '.DS_Store' design/brand-assets/logos/ WalkWorthy/Resources/BrandAssets/Logos/

rm -rf WalkWorthy/Resources/BrandAssets/Icons/*
mkdir -p WalkWorthy/Resources/BrandAssets/Icons
for source in design/brand-assets/icons/*; do
  [[ -f "$source" ]] || continue
  filename=$(basename "$source")
  case "$filename" in
    12_notification_1.png) filename="notification_card_1.png" ;;
    12_notification_2.png) filename="notification_card_2.png" ;;
  esac
  cp "$source" "WalkWorthy/Resources/BrandAssets/Icons/$filename"
done

rm -rf WalkWorthy/Resources/BrandAssets/Fonts/*
mkdir -p WalkWorthy/Resources/BrandAssets/Fonts
while IFS= read -r font; do
  cp "$font" "WalkWorthy/Resources/BrandAssets/Fonts/$(basename "$font")"
done < <(find design/brand-assets/fonts -type f \( -iname '*.ttf' -o -iname '*.otf' \) | sort)

echo "Brand assets synced to WalkWorthy/Resources/BrandAssets"
