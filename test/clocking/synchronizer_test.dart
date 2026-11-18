// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// synchronizer_test.dart
// Tests for the destination-clock synchronizer.
//
// 2026 November 8
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(Simulator.reset);

  for (final depth in [2, 3]) {
    test('$depth stages have synchronous reset and destination-edge latency',
        () async {
      final dut = Synchronizer(
        Logic(),
        dataIn: Logic(),
        reset: Logic(),
        resetValue: 1,
        stages: depth,
      );
      await dut.build();
      expect(dut.numStages, depth);
      expect(() => dut.stages, throwsA(isA<RohdHclException>()));
      final vectors = [
        Vector({'clk': 0, 'reset': 1, 'synchronizer_in': 0}, {}),
        Vector({'clk': 1, 'reset': 1, 'synchronizer_in': 0},
            {'synchronizer_out': 1}),
        for (var edge = 1; edge <= depth; edge++) ...[
          Vector({'clk': 0, 'reset': 0, 'synchronizer_in': 0},
              {'synchronizer_out': 1}),
          Vector({'clk': 1, 'reset': 0, 'synchronizer_in': 0},
              {'synchronizer_out': edge == depth ? 0 : 1}),
        ],
        Vector({'clk': 0, 'reset': 1, 'synchronizer_in': 1},
            {'synchronizer_out': 0}),
        Vector({'clk': 1, 'reset': 1, 'synchronizer_in': 1},
            {'synchronizer_out': 1}),
      ];
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }

  test('rejects fewer than two stages', () {
    expect(
      () => Synchronizer(Logic(), dataIn: Logic(), stages: 1),
      throwsA(isA<RohdHclException>()),
    );
  });
}
