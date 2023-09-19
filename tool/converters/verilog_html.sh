#!/bin/bash

# Copyright (C) 2023 Intel Corporation
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

cd build/
module=`basename $1 .v`
../tool/converters/verilog_json.sh $1
../tool/converters/json_html.sh ${module}.json > ${module}.html
