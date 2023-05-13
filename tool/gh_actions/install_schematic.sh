#!/bin/bash

# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# install_synthesis.sh
# GitHub Actions step: Install project dependencies.
#
# 2023 May 09
# Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>
#

set -euo pipefail

cd doc/d3-hwschematic
npm install
npm install --only=dev
npm run build

cd ../..
mkdir -p doc/api/d3-hwschematic-assets
cp -r doc/d3-hwschematic/node_modules/d3 doc/api/d3-hwschematic-assets
cp -r doc/d3-hwschematic/node_modules/elkjs doc/api/d3-hwschematic-assets
cp doc/d3-hwschematic/dist/d3-hwschematic.{css,js} doc/api/d3-hwschematic-assets

cd /
sudo  wget -O oss-cad-suite-build.tgz https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2023-05-12/oss-cad-suite-linux-x64-20230512.tgz

sudo tar -xvzf oss-cad-suite-build.tgz

# Trim if needed
