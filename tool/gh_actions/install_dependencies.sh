#!/bin/bash

# Copyright (C) 2022-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# install_dependencies.sh
# Installs dependencies for the complete pub workspace.
#
# 2022 October 7
# Author: Chykon

set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is required to resolve this pub workspace because confapp" >&2
  echo "declares SDK dependencies from Flutter." >&2
  exit 1
fi

flutter pub get
