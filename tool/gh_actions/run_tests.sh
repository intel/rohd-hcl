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

# Match the Dart SDK used by Flutter to resolve this workspace, while invoking
# package:test directly for this package's pure-Dart tests.
flutter_bin_dir="$(dirname "$(readlink -f "$(command -v flutter)")")"
"$flutter_bin_dir/dart" run test:test
