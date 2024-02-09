#!/bin/bash

# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# install_dart.sh
# GitHub Codespaces setup: Install Dart SDK according to the instructions from https://dart.dev/get-dart#install-using-apt-get.
#
# 2023 February 5
# Author: Chykon

set -euo pipefail

wget -O /tmp/flutter_linux.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.9-stable.tar.xz
cd /usr/local
sudo tar -xf /tmp/flutter_linux.tar.xz
echo 'export PATH="$PATH:/usr/local/flutter/bin"' >> ~/.bashrc

rm /tmp/flutter_linux.tar.xz
