// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// clock_divider_test.dart
// Tests for divided-rate clock enables.
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

  for (final divisor in [1, 2, 3, 5]) {
    test('divider $divisor emits an enable every $divisor cycles', () async {
      final divider =
          ClockDivider(clk: Logic(), reset: Logic(), divisor: divisor);
      await divider.build();
      final vectors = [
        Vector({'clk': 0, 'reset': 1}, {'enable': 0}),
        Vector({'clk': 1, 'reset': 1}, {}),
        for (var cycle = 0; cycle < divisor * 3; cycle++) ...[
          Vector({'clk': 0, 'reset': 0},
              {'enable': cycle % divisor == divisor - 1 ? 1 : 0}),
          Vector({'clk': 1, 'reset': 0}, {}),
        ],
        Vector({'clk': 0, 'reset': 1}, {'enable': 0}),
        Vector({'clk': 1, 'reset': 1}, {}),
        Vector({'clk': 0, 'reset': 0}, {'enable': divisor == 1 ? 1 : 0}),
      ];
      await SimCompare.checkFunctionalVector(divider, vectors);
      SimCompare.checkIverilogVector(divider, vectors);
    });
  }

  test('rejects a nonpositive divisor', () {
    expect(() => ClockDivider(clk: Logic(), reset: Logic(), divisor: 0),
        throwsArgumentError);
  });

  test('reset during a period restarts the full interval', () async {
    final divider = ClockDivider(clk: Logic(), reset: Logic(), divisor: 3);
    await divider.build();
    final vectors = [
      Vector({'clk': 0, 'reset': 1}, {'enable': 0}),
      Vector({'clk': 1, 'reset': 1}, {}),
      Vector({'clk': 0, 'reset': 0}, {'enable': 0}),
      Vector({'clk': 1, 'reset': 0}, {}),
      Vector({'clk': 0, 'reset': 1}, {'enable': 0}),
      Vector({'clk': 1, 'reset': 1}, {}),
      for (var cycle = 0; cycle < 3; cycle++) ...[
        Vector({'clk': 0, 'reset': 0}, {'enable': cycle == 2 ? 1 : 0}),
        Vector({'clk': 1, 'reset': 0}, {}),
      ],
    ];
    await SimCompare.checkFunctionalVector(divider, vectors);
    SimCompare.checkIverilogVector(divider, vectors);
  });
}
