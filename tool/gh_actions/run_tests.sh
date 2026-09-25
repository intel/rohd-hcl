#!/bin/bash

# Copyright (C) 2022-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# run_tests.sh
# GitHub Actions step: Run project tests.
#
# 2022 October 10
# Author: Chykon

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

bash "$repo_root/tool/generate_confapp_assets.sh"

flutter test
