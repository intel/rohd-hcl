#!/bin/bash

# Copyright (C) 2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# Generate native ROHD netlists and compatibility redirects for API docs.

set -euo pipefail
shopt -s nullglob

dart run gen/generate.dart

netlists=(build/*.rohd.json)
if [[ ${#netlists[@]} -eq 0 ]]; then
    echo "No ROHD netlists were generated." >&2
    exit 1
fi

mkdir -p doc/api/schematics
cp -- "${netlists[@]}" doc/api/schematics/

# Existing API documentation links point to <Component>.html. Keep those URLs
# stable with redirects; schematic rendering happens in the Flutter viewer.
for netlist in "${netlists[@]}"; do
    name=$(basename "$netlist" .rohd.json)
    cat > "doc/api/${name}.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>${name} - ROHD Schematic</title>
  <meta http-equiv="refresh"
        content="0; url=schematic_viewer/index.html?json=../schematics/${name}.rohd.json">
</head>
<body>
  <p>Redirecting to
    <a href="schematic_viewer/index.html?json=../schematics/${name}.rohd.json">
      ${name} schematic viewer</a>...
  </p>
</body>
</html>
EOF
done

echo "Created schematic assets for ${#netlists[@]} components."
