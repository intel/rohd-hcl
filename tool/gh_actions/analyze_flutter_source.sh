#!/bin/bash

# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# analyze_flutter_source.sh
# GitHub Actions step: Analyze project source for confapp.
#
# 2022 October 9
# Author: Max Korbel <max.korbel@intel.com

set -euo pipefail

cd confapp

flutter analyze --fatal-infos
