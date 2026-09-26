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

# Dependencies are resolved with Flutter because the workspace includes
# confapp. Invoke package:test directly for this package's pure-Dart tests.
dart run test:test
