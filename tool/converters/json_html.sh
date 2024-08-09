#!/bin/bash

# Copyright (C) 2023-2024 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# jsonToHtml.sh
# Splice a json file into an HTML form for D3 schematic display
#
# 2023 May 09
# Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>
#
#
# This script inserts a JSON file in the middle of an HTML file that drives
# a D3 schematic viewer.

if !(test 1 -eq $#); then
    echo One argument required: JSON file
    exit 1
fi;

json=`cat $1 | sed -e 's/\\\\/_/g'`
pre='<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>d3-hwschematic</title>
</head>
<body>
  </script>
  <script type="text/javascript" src="d3-hwschematic-assets/d3/dist/d3.js"></script>
  <!-- <script type="text/javascript" src="d3-hwschematic-assets/d3/dist/d3.min.js"></script>  -->
  <script type="text/javascript" src="d3-hwschematic-assets/elkjs/lib/elk.bundled.js"></script>
  <script type="text/javascript" src="d3-hwschematic-assets/d3-hwschematic.js"></script>
  <link href="d3-hwschematic-assets/d3-hwschematic.css" rel="stylesheet">
  <style>
  	body {
	   margin: 0;
    }
  </style>
</head>
<body>
    <svg id="scheme-placeholder"></svg>
    <script>
        // schematic rendering script
        function viewport() {
          var e = window,
            a = '\'inner\'';
          if (!(''innerWidth'' in window)) {
            a = '\'client\'';
            e = document.documentElement || document.body;
          }
          return {
            width: e[a + '\'Width\''],
            height: e[a + '\'Height\'']
          }
        }
      var exmpl = `'

post='`;
        var width = viewport().width,
            height = viewport().height;

        var svg = d3.select("#scheme-placeholder")
            .attr("width", width)
            .attr("height", height);

        var orig = document.body.onresize;
        document.body.onresize = function(ev) {
            if (orig)
        	    orig(ev);

            var w = viewport();
            svg.attr("width", w.width);
			svg.attr("height", w.height);
        }

        var hwSchematic = new d3.HwSchematic(svg);
        var zoom = d3.zoom();
        zoom.on("zoom", function applyTransform(ev) {
        	hwSchematic.root.attr("transform", ev.transform)
        });

        // disable zoom on doubleclick
        // because it interferes with component expanding/collapsing
        svg.call(zoom)
           .on("dblclick.zoom", null)

      graph = JSON.parse(exmpl);
      if ("creator" in graph) {
	  graph = d3.HwSchematic.fromYosys(graph);
      }
      if (graph.hwMeta && graph.hwMeta.name) {
          document.title = graph.hwMeta.name;
	  hwSchematic.bindData(graph);
      }
    </script>
</body>
</html>
'
echo "${pre}${json}${post}"
