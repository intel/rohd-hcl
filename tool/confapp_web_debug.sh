#!/usr/bin/env bash
# Copyright (C) 2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
port="${CONFAPP_WEB_PORT:-8080}"
flutter_bin="${CONFAPP_FLUTTER_BIN:-flutter}"

if [[ "$#" -ne 0 ]]; then
  echo "Usage: $0" >&2
  echo "Select dependency sources separately with tool/confapp_dev_mode.sh." >&2
  exit 2
fi

flutter_bin="$(command -v "$flutter_bin")" || {
  echo "Flutter executable is unavailable." >&2
  exit 1
}

cd "$repo_root"
"$flutter_bin" pub get
cd confapp
exec "$flutter_bin" run \
  --no-pub \
  -d web-server \
  --web-hostname=127.0.0.1 \
  --web-port="$port"
