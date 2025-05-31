#!/bin/bash

# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# install_sv2v.sh
# GitHub Actions step: Install project dependencies.
#
# 2025 April 27
# Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

set -euo pipefail

curl -sSL https://get.haskellstack.org/ | sh 

cd /tmp/
git clone https://github.com/zachjs/sv2v.git
cd sv2v
make
cp ./bin/sv2v  /usr/local/bin