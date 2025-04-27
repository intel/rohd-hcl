#!/bin/bash

# Copyright (C) 2022-2024 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# Scavenged from Nic30:d3-hwschematic
#cp -r doc/d3-hwschematic-assets doc/api/

# Generate components and produce Verilog

dart gen/generate.dart

mkdir -p build

# Convert Verilog into an HTML-based schematic for each
for i in build/*.sv
do
    example=`basename $i .sv`
    ./tool/converters/verilog_html.sh $example
    cp build/$example.html doc/api/$example.html
done
