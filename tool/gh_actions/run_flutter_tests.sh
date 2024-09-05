#!/bin/bash

# Copyright (C) 2023-2024 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# run_flutter_tests.sh
# Runs tests for the ROHD-HCL static flutter page.
#
# 2023 September 21
# Author: Max Korbel <max.korbel@intel.com>

set -euo pipefail

cd confapp

flutter test --platform chrome