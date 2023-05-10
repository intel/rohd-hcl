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
DEBIAN_FRONTEND=noninteractive apt-get install -y \
	       build-essential \
	       clang \
	       bison \
	       flex \
	       libreadline-dev \
	       gawk \
	       tcl-dev \
	       libffi-dev \
	       git \
	       pkg-config \
	       python3 \
	       python3-dev \
	       python3-pip \
	       python3-setuptools \
	       python3-wheel \
	       python3-tk

git clone https://github.com/YosysHQ/yosys.git
cd yosys
make -j$(nproc)
