#!/bin/bash

# Copyright (C) 2023-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# run_flutter_tests.sh
# Runs tests for the ROHD-HCL static flutter page.
#
# 2023 September 21
# Author: Max Korbel <max.korbel@intel.com>

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

bash "$repo_root/tool/generate_confapp_assets.sh"

cd "$repo_root/confapp"

# The later web build validates the browser side of conditional imports.
flutter test
