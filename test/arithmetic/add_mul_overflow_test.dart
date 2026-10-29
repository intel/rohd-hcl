// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// add_mul_overflow_test.dart
// Tests for UnsignedAddWithOverflow and UnsignedMulWithOverflow.
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

  const width = 4;
  // Corner operand pairs: zeros, identity, all-ones, and a carry or overflow
  // boundary at the edge of the width.
  const pairs = [
    (0, 0),
    (1, 0),
    (15, 1),
    (8, 8),
    (7, 9),
    (15, 15),
  ];

  for (final sumWidth in [width, width + 1]) {
    test('UnsignedAddWithOverflow sumWidth=$sumWidth at corner operands',
        () async {
      final a = Logic(name: 'a', width: width);
      final b = Logic(name: 'b', width: width);
      final dut = UnsignedAddWithOverflow(a, b, sumWidth: sumWidth);
      await dut.build();

      final sumMask = (1 << sumWidth) - 1;
      final vectors = [
        for (final (x, y) in pairs)
          Vector({
            'a': x,
            'b': y
          }, {
            'sum': (x + y) & sumMask,
            'overflow': (x + y) > sumMask ? 1 : 0,
          })
      ];
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
      expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
    });
  }

  for (final productWidth in [width, width * 2]) {
    test(
        'UnsignedMulWithOverflow productWidth=$productWidth at corner operands',
        () async {
      final a = Logic(name: 'a', width: width);
      final b = Logic(name: 'b', width: width);
      final dut = UnsignedMulWithOverflow(a, b, productWidth: productWidth);
      await dut.build();

      final prodMask = (1 << productWidth) - 1;
      final vectors = [
        for (final (x, y) in pairs)
          Vector({
            'a': x,
            'b': y
          }, {
            'product': (x * y) & prodMask,
            'overflow': (x * y) > prodMask ? 1 : 0,
          })
      ];
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
      expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
    });
  }
}
