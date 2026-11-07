#!/bin/bash

# Copyright (C) 2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# Build the standalone schematic viewer used by API documentation.

set -euo pipefail

cd doc/schematic_viewer
flutter pub get
flutter build web \
    --release \
    --base-href /rohd-hcl/schematic_viewer/
