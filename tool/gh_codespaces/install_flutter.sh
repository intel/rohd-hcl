#!/bin/bash

# Copyright (C) 2023-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# install_flutter.sh
# GitHub Codespaces setup: Install Flutter SDK following this Dockerfile recipe:
#    https://github.com/appleboy/flutter-docker/blob/master/Dockerfile
# or this git area
#    https://github.com/yostane/flutter2-desktop
#
# 2024 February 12
# Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

set -euo pipefail

declare -r flutter_version='3.47.2'

wget -O /tmp/flutter_linux.tar.xz \
  "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${flutter_version}-stable.tar.xz"
cd /usr/local
sudo tar -xf /tmp/flutter_linux.tar.xz
echo 'export PATH="$PATH:/usr/local/flutter/bin"' >> ~/.bashrc

rm /tmp/flutter_linux.tar.xz
