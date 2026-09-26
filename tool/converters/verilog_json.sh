#!/bin/bash

# Copyright (C) 2023-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# verilog_json.sh
# Convert SystemVerilog to a Yosys JSON netlist.
#
# 2023 May 09
# Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <module.sv>" >&2
    exit 1
fi

input=$1
module=$(basename "$input" .sv)
output="${input%.sv}.json"
yosys_bin=${YOSYS_BIN:-/oss-cad-suite/bin/yosys}

"$yosys_bin" -Q -T -q <<EOF
read_verilog -sv "$input"
hierarchy -top $module
proc; opt
write_json -compat-int "$output"
EOF
