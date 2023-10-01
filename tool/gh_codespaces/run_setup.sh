#!/bin/bash

# Copyright (C) 2023 Intel Corporation
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

# Install Pub dependencies.
tool/gh_actions/install_dependencies.sh

<<<<<<< HEAD
# Install Synthesis tool (yosys).
tool/gh_actions/install_synthesis.sh
=======
# Install CAD Suite (includes yosys)
tool/gh_actions/install_opencadsuite.sh

# Install D3 Schematic viewer
tool/gh_actions/install_d3_hwschematic.sh
>>>>>>> 861c4ad955af5ac6f2099eb3e1270fe83f40ac26
