// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// first_match_prefix_test.dart
// Tests for eligible first-match selection.
//
// 2026 November 14
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(Simulator.reset);

  test('selects the first eligible match and preserves its prefix', () async {
    const width = 4;
    final dut = FirstMatchPrefix(
      eligibleMask: Logic(width: width),
      matchMask: Logic(width: width),
    );
    await dut.build();
    final vectors = <Vector>[];
    for (var eligible = 0; eligible < 1 << width; eligible++) {
      for (var matches = 0; matches < 1 << width; matches++) {
        var keep = 0;
        var selected = 0;
        var count = 0;
        for (var lane = 0; lane < width; lane++) {
          final bit = 1 << lane;
          if ((eligible & bit) == 0) {
            continue;
          }
          keep |= bit;
          count++;
          if ((matches & bit) != 0) {
            selected = bit;
            break;
          }
        }
        vectors.add(Vector({
          'eligibleMask': eligible,
          'matchMask': matches
        }, {
          'keepMask': keep,
          'selectedMask': selected,
          'keptCount': count,
          'anyMatch': selected == 0 ? 0 : 1,
        }));
      }
    }
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });
}
