// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ceil_divide_test.dart
// Tests for CeilDivide.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('CeilDivide rounds the quotient up for every nonzero divisor', () async {
    // Corner cases on 4-bit operands: zero and full-scale dividends, divisors
    // of 1 (exact), and divisors that leave a remainder. Division by zero is
    // unspecified, so the divisor never reaches 0.
    const width = 4;
    final dividend = Logic(name: 'dividend', width: width);
    final divisor = Logic(name: 'divisor', width: width);
    final dut = CeilDivide(dividend, divisor);
    await dut.build();

    final vectors = [
      for (final x in [0, 1, 7, 15])
        for (final y in [1, 2, 3, 15])
          Vector({'dividend': x, 'divisor': y}, {'quotient': (x + y - 1) ~/ y})
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
  });
}
