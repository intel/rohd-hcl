#!/bin/bash

# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# synthesize.sh
# Run synthesis outputing synthesized Verilog
#
# 2023 May 09
# Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

# Executes synthesis given a module name
# Assumes .v extension
# Outputs < module>_synth.v

if !(test 1 -eq $#); then
    echo One argument required: module
    exit 1
fi;

yosys_area=/yosys
lib=$yosys_area/tests/liberty/normal.lib
module=$1
yosys <<EOF
read_verilog -sv $module.v
hierarchy -top $module
proc
dfflibmap -liberty $lib
abc -liberty $lib
proc; opt
techmap
write_verilog ${module}_synth.v
EOF
