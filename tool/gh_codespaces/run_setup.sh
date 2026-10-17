#!/bin/bash

# Copyright (C) 2023-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# run_setup.sh
# GitHub Codespaces setup: Setting up the development environment.
#
# 2023 February 5
# Author: Chykon

set -euo pipefail

# Install Dart SDK.
tool/gh_codespaces/install_dart.sh

# Install Flutter
tool/gh_codespaces/install_flutter.sh

# Make Flutter available to this setup process before resolving dependencies.
export PATH="/usr/local/flutter/bin:$PATH"

# Install Pub workspace dependencies.
tool/gh_actions/install_dependencies.sh

# Install CAD Suite (includes yosys)
tool/gh_actions/install_opencadsuite.sh