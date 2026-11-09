#!/bin/bash
# Copyright (C) 2023-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# Generate an isolated Confapp project with bundled ROHD source assets.

set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "Usage: bash tool/generate_confapp_assets.sh" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$repo_root/build/confapp"
asset_dir="$build_dir/assets/rohd_src"
flutter_bin="${CONFAPP_FLUTTER_BIN:-flutter}"

if [[ -e "$build_dir" && ! -f "$build_dir/.rohd_hcl_generated" ]]; then
  echo "Refusing to overwrite an existing non-generated directory: $build_dir" >&2
  exit 1
fi
mkdir -p "$build_dir/assets" "$asset_dir"
touch "$build_dir/.rohd_hcl_generated"
for entry in lib test web tool dart_test.yaml; do
  if [[ -L "$build_dir/$entry" ]]; then
    if [[ "$(readlink "$build_dir/$entry")" != "$repo_root/confapp/$entry" ]]; then
      echo "Unexpected symlink in generated Confapp project: $build_dir/$entry" >&2
      exit 1
    fi
  elif [[ -e "$build_dir/$entry" ]]; then
    echo "Expected a generated symlink at $build_dir/$entry; refusing to replace it." >&2
    exit 1
  else
    ln -s "$repo_root/confapp/$entry" "$build_dir/$entry"
  fi
done

rsync -a --delete --exclude='/rohd_src/' \
  "$repo_root/confapp/assets/" "$build_dir/assets/"
rsync -a --delete --include='*/' --include='*.dart' --exclude='*' \
  "$repo_root/lib/src/" "$asset_dir/"

missing_assets=0
while IFS= read -r source_asset; do
  if [[ ! -f "$build_dir/assets/$source_asset" ]]; then
    echo "Missing generated ROHD source asset: $source_asset" >&2
    missing_assets=1
  fi
done < <(
  grep -oE "'rohd_src/[^']+'" "$repo_root/confapp/lib/hcl/module_source_assets.dart" |
    tr -d "'" | sort -u
)
if [[ "$missing_assets" -ne 0 ]]; then
  exit 1
fi

if [[ ! -f "$repo_root/pubspec.lock" ]]; then
  echo "Resolve the workspace first: flutter pub get" >&2
  exit 1
fi
dart "$repo_root/tool/generate_confapp_build.dart" "$build_dir"
cp "$repo_root/pubspec.lock" "$build_dir/pubspec.lock"
(
  cd "$build_dir"
  "$flutter_bin" pub get
)
echo "Generated Confapp build project at $build_dir"
