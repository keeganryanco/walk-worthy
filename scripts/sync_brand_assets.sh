#!/usr/bin/env bash
set -euo pipefail

mkdir -p WalkWorthy/Resources/BrandAssets/Logos
mkdir -p WalkWorthy/Resources/BrandAssets/Icons
mkdir -p WalkWorthy/Resources/BrandAssets/Fonts
mkdir -p WalkWorthy/Resources/BrandAssets/Videos

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

rm -f WalkWorthy/Resources/BrandAssets/Videos/OnboardingIntroLoop.mov
rm -f WalkWorthy/Resources/BrandAssets/Videos/OnboardingIntroLoop.mp4
rm -f WalkWorthy/Resources/BrandAssets/Videos/OnboardingIntroLoop.m4v

VIDEO_SOURCE_DIR="design/brand-assets/video"
mkdir -p "$VIDEO_SOURCE_DIR"

copied_video=0
for candidate in \
  "$VIDEO_SOURCE_DIR/onboarding_intro_loop_alpha.mov" \
  "$VIDEO_SOURCE_DIR/onboarding_intro_loop_alpha.mp4" \
  "$VIDEO_SOURCE_DIR/onboarding_intro_loop_alpha.m4v" \
  "$VIDEO_SOURCE_DIR/onboarding_intro_loop.mov" \
  "$VIDEO_SOURCE_DIR/onboarding_intro_loop.mp4" \
  "$VIDEO_SOURCE_DIR/onboarding_intro_loop.m4v"
do
  if [[ -f "$candidate" ]]; then
    extension="${candidate##*.}"
    cp "$candidate" "WalkWorthy/Resources/BrandAssets/Videos/OnboardingIntroLoop.$extension"
    copied_video=1
    break
  fi
done

if [[ "$copied_video" -eq 1 ]]; then
  echo "Onboarding loop video synced to WalkWorthy/Resources/BrandAssets/Videos"
else
  echo "No onboarding loop video found in design/brand-assets/video (optional)"
fi

echo "Brand assets synced to WalkWorthy/Resources/BrandAssets"
