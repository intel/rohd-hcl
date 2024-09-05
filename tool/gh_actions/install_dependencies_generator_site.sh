#!/bin/bash

# Copyright (C) 2023-2024 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# install_dependencies_generator_site.sh
# GitHub Actions step: Install project dependencies.
#
# 2023 August 01
# Author: Yao Jing Quek <yao.jing.quek@intel.com>
#

set -euo pipefail

flutter pub get
