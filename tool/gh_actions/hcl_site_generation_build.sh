#!/bin/bash

# Copyright (C) 2023-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# hcl_site_generation_build.sh
# GitHub Actions step: Generate ROHD-HCL static site.
#
# 2023 August 01
# Author: Yao Jing Quek <yao.jing.quek@intel.com>

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

# The source assets are intentionally generated and ignored by Git. Build
# them here so deployment jobs work from a fresh checkout.
bash "$repo_root/tool/generate_confapp_assets.sh"

cd "$repo_root/confapp"

# Use profile instead of release to avoid certain module names being replaced.
# Keep the production site on the WASM-compatible web target.
flutter build web --wasm --profile --base-href /rohd-hcl/confapp/
