#!/bin/bash

cp -r doc/d3-hwschematic-assets doc/api/

for i in build/*.v
do
    example=`basename $i .v`
    ./tool/converters/verilog_html.sh $example
    cp build/$example.html doc/api/$example.html
done
