// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// log2_ceil_test.dart
// Tests for Log2Ceil.
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

  test('Log2Ceil matches ceil(log2(x)) at powers of two and their neighbours',
      () async {
    // 0 and 1 map to 0. Each power of two is checked with the value just
    // below and just above it.
    const width = 4;
    final inp = Logic(name: 'inp', width: width);
    final dut = Log2Ceil(inp);
    await dut.build();

    final vectors = [
      for (final x in [0, 1, 2, 3, 4, 5, 8, 9, 15])
        Vector({'inp': x}, {'log': x <= 1 ? 0 : (x - 1).bitLength})
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
  });
}
