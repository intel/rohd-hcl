#!/bin/bash

# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# hcl_site_generation_build.sh
# GitHub Actions step: Generate ROHD-HCL static site.
#
# 2023 August 01
# Author: Yao Jing Quek <yao.jing.quek@intel.com>
#

set -euo pipefail

cd doc/confapp_flutter

flutter build web --release --web-renderer html --base-href /rohd-hcl/


