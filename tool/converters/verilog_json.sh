#!/bin/bash

# Copyright (C) 2023-2024 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# verilogToJSON.sh
# Run yosys to convert Verilog to JSON
#
# 2023 May 09
# Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

# Executes synthesis given a module name
# Assumes .v extension
# Outputs <module>.json

if !(test 1 -eq $#); then
    echo One argument required: module
    exit 1
fi;

yosys_bin=/oss-cad-suite/bin/yosys
module=`basename $1 .v`
$yosys_bin -Q -T -q <<EOF
read_verilog -sv $module.v
hierarchy -top $module
proc; opt
write_json -compat-int $module.json
EOF
