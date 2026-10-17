#!/bin/bash

# Copyright (C) 2023-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# analyze_flutter_source.sh
# GitHub Actions step: Analyze project source for confapp.
#
# 2022 October 9
# Author: Max Korbel <max.korbel@intel.com

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

bash "$repo_root/tool/generate_confapp_assets.sh"

cd "$repo_root/confapp"

flutter analyze --fatal-infos
