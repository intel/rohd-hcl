#!/bin/bash
# Copyright (C) 2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# Check the actual Pub archive preview, not just ignore-file patterns.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
output="$(mktemp)"
trap 'rm -f "$output"' EXIT

cd "$repo_root"
if ! dart pub publish --dry-run --ignore-warnings >"$output" 2>&1; then
  cat "$output" >&2
  exit 1
fi

if grep -Eq '^[^[:space:]]*── (confapp|pubspec_overrides\.yaml)(/|[[:space:]]|$)' "$output"; then
  echo "The published package unexpectedly includes Confapp or its workspace override:" >&2
  grep -E '^[^[:space:]]*── (confapp|pubspec_overrides\.yaml)(/|[[:space:]]|$)' "$output" >&2
  exit 1
fi
if ! grep -Eq '^[^[:space:]]*── pubspec\.yaml[[:space:]]' "$output"; then
  echo "Could not find the package manifest in the Pub archive preview." >&2
  exit 1
fi
echo "Pub archive excludes Confapp and the workspace override."
