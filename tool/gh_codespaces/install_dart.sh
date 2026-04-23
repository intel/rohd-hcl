#!/bin/bash

# Copyright (C) 2023-2024 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# install_dart.sh
# GitHub Codespaces setup: Install Dart SDK according to the instructions from https://dart.dev/get-dart#install-using-apt-get.
#
# 2023 February 5
# Author: Chykon

# Testing new script suggest by AI:  Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

set -euo pipefail

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# Keyring location (modern Debian/Ubuntu practice)
sudo install -d -m 0755 /etc/apt/keyrings

# Dart repo signing key (fixes NO_PUBKEY FD533C07C264648F)
curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub \
  | sudo gpg --dearmor -o /etc/apt/keyrings/dart.gpg
sudo chmod a+r /etc/apt/keyrings/dart.gpg

# Repo entry using signed-by
echo "deb [signed-by=/etc/apt/keyrings/dart.gpg] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main" \
  | sudo tee /etc/apt/sources.list.d/dart_stable.list > /dev/null

sudo apt-get update
sudo apt-get install -y dart
