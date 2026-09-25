#!/bin/bash

# Copyright (C) 2023-2024 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# hcl_site_generation_build.sh
# GitHub Actions step: Generate ROHD-HCL static site.
#
# 2023 August 01
# Author: Yao Jing Quek <yao.jing.quek@intel.com>

set -euo pipefail

cd confapp

# Use profile instead of release to avoid certain module names being replaced.
# Keep the production site on the WASM-compatible web target.
flutter build web --wasm --profile --base-href /rohd-hcl/confapp/
