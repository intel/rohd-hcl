#!/bin/bash

# Copyright (C) 2023-2024 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# run_setup.sh
# GitHub Codespaces setup: Setting up the development environment.
#
# 2023 February 5
# Author: Chykon

set -euo pipefail

# Initialize submodules
git submodule update --init --recursive

# Install Dart SDK.
tool/gh_codespaces/install_dart.sh

# Install Pub dependencies.
tool/gh_actions/install_dependencies.sh

# Install CAD Suite (includes yosys)
tool/gh_actions/install_opencadsuite.sh

# Install SystemVerilog to Verilog converter
tool/gh_actions/install_sv2v.sh

# Install D3 Schematic viewer
tool/gh_actions/install_d3_hwschematic.sh

# Install Flutter
tool/gh_codespaces/install_flutter.sh