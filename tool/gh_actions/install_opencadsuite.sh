#!/bin/bash

# Copyright (C) 2023-2024 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# install_opencadsuite.sh
# GitHub Actions step: Install project dependencies.
#
# 2023 May 09
# Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

set -euo pipefail

sudo apt-get update
sudo apt-get install -y \
	git \
	npm \
	python3-pip

cd /
sudo  wget -O oss-cad-suite-build.tgz https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2023-05-12/oss-cad-suite-linux-x64-20230512.tgz

sudo tar -xzf oss-cad-suite-build.tgz

# Trim if needed
