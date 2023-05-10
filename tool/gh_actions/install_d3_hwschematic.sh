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

apt-get update
apt-get install -y \
	git \
	npm \
	python3-pip

git clone https://github.com/Nic30/d3-hwschematic.git
cd d3-hwschematic
npm install
npm install --only=dev
nom run build

