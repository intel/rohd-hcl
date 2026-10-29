#!/bin/bash

# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# pana_source.sh
# GitHub Actions step: execute pana analysis on project source.
#
# 2025 September 26
# Author: Desmond A. Kirkpatrick

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
flutter_sdk="${FLUTTER_ROOT:-}"
if [[ -z "$flutter_sdk" ]]; then
  flutter_bin="$(command -v flutter)" || {
    echo "Flutter is required to analyze this workspace with pana." >&2
    exit 1
  }
  flutter_sdk="$(cd "$(dirname "$flutter_bin")/.." && pwd)"
fi

if [[ ! -x "$flutter_sdk/bin/flutter" ]]; then
  echo "FLUTTER_ROOT must identify a Flutter SDK, got: $flutter_sdk" >&2
  exit 1
fi

export PATH="$flutter_sdk/bin:$HOME/.pub-cache/bin:$PATH"

cd "$repo_root"
pana \
  --flutter-sdk "$flutter_sdk" \
  --project-root "$repo_root" \
  --exit-code-threshold 0 \
  .
