#!/bin/bash

# Copyright (C) 2022-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# generate_coverage.sh
# Determines code coverage by tests and generates an HTML report and
# optionally an SVG badge.
#
# 2022 May 5
# Author: Max Korbel <max.korbel@intel.com> <max.korbel@intel.com>

### WARNING ###
# The "x" option outputs all script commands. This allows you to track
# the progress of the execution, but MAY REVEAL ANY SECRETS PASSED TO THE SCRIPT!
set -euxo pipefail

#=============#

declare -r coverage_dir='build/coverage'
declare -r html_dir="${coverage_dir}/genhtml"

generate_svg=false
if [ "$#" -gt 0 ]; then
    if [ "$#" -ne 1 ] || [ "$1" != '--generate-svg' ]; then
        echo "Usage: $0 [--generate-svg]" >&2
        exit 1
    fi
    generate_svg=true
fi

mkdir -p "${coverage_dir}"
dart run test:test --coverage-path="${coverage_dir}/lcov.info"

# requires installing "lcov":
# > sudo apt install lcov
genhtml --output-directory=${html_dir} ${coverage_dir}/lcov.info

printf '\n%s\n\n' "Open ${html_dir}/index.html to review code coverage results."

if [ "${generate_svg}" = true ]; then
    if ! summary=$(LC_ALL=C lcov --summary "${coverage_dir}/lcov.info" 2>&1); then
        echo "${summary}" >&2
        exit 1
    fi
    percent=$(printf '%s\n' "${summary}" | awk '/^[[:space:]]*lines[.]*:/ {print $2}')
    if [[ ! "${percent}" =~ ^[0-9]+([.][0-9]+)?%$ ]]; then
        echo "Unable to determine line coverage from LCOV summary:" >&2
        echo "${summary}" >&2
        exit 1
    fi

    value=${percent%\%}
    if awk -v value="${value}" 'BEGIN { exit !(value >= 90) }'; then
        color='#4c1'
    elif awk -v value="${value}" 'BEGIN { exit !(value >= 80) }'; then
        color='#97ca00'
    elif awk -v value="${value}" 'BEGIN { exit !(value >= 70) }'; then
        color='#dfb317'
    elif awk -v value="${value}" 'BEGIN { exit !(value >= 60) }'; then
        color='#fe7d37'
    else
        color='#e05d44'
    fi

    text_width=$((${#percent} * 63))
    label_width=63
    value_width=$((text_width / 10 + 10))
    total_width=$((label_width + value_width))
    cat > "${coverage_dir}/main.svg" << EOF
<svg xmlns="http://www.w3.org/2000/svg" width="${total_width}" height="20" role="img" aria-label="coverage: ${percent}">
  <title>coverage: ${percent}</title>
  <clipPath id="r"><rect width="${total_width}" height="20" rx="3"/></clipPath>
  <g clip-path="url(#r)">
    <rect width="${label_width}" height="20" fill="#555"/>
    <rect x="${label_width}" width="${value_width}" height="20" fill="${color}"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" font-size="110">
    <text x="325" y="140" transform="scale(.1)" textLength="530">coverage</text>
    <text x="$((label_width * 10 + value_width * 5))" y="140" transform="scale(.1)" textLength="${text_width}">${percent}</text>
  </g>
</svg>
EOF
    printf 'Line coverage: %s\nBadge: %s/main.svg\n' "${percent}" "${coverage_dir}"
fi
