#!/bin/bash
# Copyright (C) 2023-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# generate_confapp_assets.sh
# Mirrors lib/src/ Dart sources into confapp/assets/rohd_src/ so the confapp
# can bundle them as Flutter text assets for the ROHD Source tab and
# cross-probing via FLC.
#
# Run from the repo root:
#   bash tool/generate_confapp_assets.sh
#
# The asset directory is .gitignored — regenerate after checkout or when
# source files change.
#
# 2026 April

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$REPO_ROOT/lib/src"
ASSET_DIR="$REPO_ROOT/confapp/assets/rohd_src"

mkdir -p "$ASSET_DIR"

rsync -a --delete --include='*/' --include='*.dart' --exclude='*' \
  "$SRC_DIR/" "$ASSET_DIR/"

copied=$(find "$ASSET_DIR" -name '*.dart' | wc -l)
echo "Synced $copied .dart files from lib/src/ -> confapp/assets/rohd_src/"

MODULE_SOURCE_ASSETS="$REPO_ROOT/confapp/lib/hcl/module_source_assets.dart"
missing_assets=0
while IFS= read -r source_asset; do
  if [[ ! -f "$REPO_ROOT/confapp/assets/$source_asset" ]]; then
    echo "Missing generated ROHD source asset: $source_asset" >&2
    missing_assets=1
  fi
done < <(
  grep -oE "'rohd_src/[^']+'" "$MODULE_SOURCE_ASSETS" |
    tr -d "'" |
    sort -u
)

if [[ "$missing_assets" -ne 0 ]]; then
  exit 1
fi

PUBSPEC="$REPO_ROOT/confapp/pubspec.yaml"

rohd_entries=$(find "$ASSET_DIR" -type d \
  | sed "s|$REPO_ROOT/confapp/|    - |" \
  | sed 's|$|/|' \
  | sort)

tmpfile=$(mktemp)
awk -v entries="$rohd_entries" '
  /^  assets:/ {
    print
    print entries
    in_assets = 1
    next
  }
  in_assets && /^    - assets\/rohd_src/ { next }
  in_assets && /^[^ ]/ { in_assets = 0 }
  { print }
' "$PUBSPEC" > "$tmpfile"
mv "$tmpfile" "$PUBSPEC"

dirs=$(echo "$rohd_entries" | wc -l)
echo "Updated pubspec.yaml with $dirs asset directories."
