// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  // Corner operand pairs at width 4: identical, complementary, single-bit
  // difference, and alternating patterns.
  const width = 4;
  const corners = [
    (0x0, 0x0),
    (0xF, 0xF),
    (0x0, 0xF),
    (0x5, 0xA),
    (0x1, 0x0),
    (0x8, 0x7),
  ];

  int onesCount(int value) {
    var count = 0;
    for (var v = value; v != 0; v >>= 1) {
      count += v & 1;
    }
    return count;
  }

  test('XOR popcount produces the Hamming distance', () async {
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final dut = XorPopcount(a, b);

    await dut.build();

    final vectors = [
      for (final (x, y) in corners)
        Vector(
          {'a': x, 'b': y},
          {'count': onesCount(x ^ y)},
        ),
    ];

    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('XNOR popcount counts equal corresponding bits', () async {
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final dut = XnorPopcount(a, b);

    await dut.build();

    final vectors = [
      for (final (x, y) in corners)
        Vector(
          {'a': x, 'b': y},
          {'count': width - onesCount(x ^ y)},
        ),
    ];

    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('XOR popcount with radix 3 counts the same unequal bits', () async {
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final dut = XorPopcount(a, b, radix: 3);

    await dut.build();

    final vectors = [
      for (final (x, y) in corners)
        Vector(
          {'a': x, 'b': y},
          {'count': onesCount(x ^ y)},
        ),
    ];

    await SimCompare.checkFunctionalVector(dut, vectors);
  });

  test('bitwise popcount rejects operands of unequal width', () {
    expect(
      () => XorPopcount(Logic(width: 4), Logic(width: 3)),
      throwsA(isA<RohdHclException>()),
    );
  });
}
