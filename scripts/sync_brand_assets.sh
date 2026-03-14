#!/usr/bin/env bash
set -euo pipefail

mkdir -p WalkWorthy/Resources/BrandAssets/Logos
mkdir -p WalkWorthy/Resources/BrandAssets/Icons
mkdir -p WalkWorthy/Resources/BrandAssets/Fonts

rsync -av --delete design/brand-assets/logos/ WalkWorthy/Resources/BrandAssets/Logos/
rsync -av --delete design/brand-assets/icons/ WalkWorthy/Resources/BrandAssets/Icons/
rsync -av --delete design/brand-assets/fonts/ WalkWorthy/Resources/BrandAssets/Fonts/

echo "Brand assets synced to WalkWorthy/Resources/BrandAssets"
