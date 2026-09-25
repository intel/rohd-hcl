#!/bin/bash

# Copyright (C) 2022-2024 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# analyze_source.sh
# GitHub Actions step: Analyze project source.
#
# 2022 October 9
# Author: Chykon

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

bash "$repo_root/tool/generate_confapp_assets.sh"

cd "$repo_root"

dart analyze --fatal-infos
