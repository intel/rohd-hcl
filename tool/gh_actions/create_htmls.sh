#!/bin/bash

# Scavenged from Nic30:d3-hwschematic
#cp -r doc/d3-hwschematic-assets doc/api/

# Generate components and produce Verilog

dart gen/generate.dart

# Convert Verilog into an HTML-based schematic for each
for i in build/*.v
do
    example=`basename $i .v`
    ./tool/converters/verilog_html.sh $example
    cp build/$example.html doc/home/$example.html
done
