// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// absolute_value_test.dart
// Tests for absolute value.
//
// 2026 October 28
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('computes exact signed magnitudes including the minimum value',
      () async {
    const inputWidth = 4;
    final dut = AbsoluteValue(Logic(width: inputWidth));

    expect(dut.outputWidth, inputWidth + 1);
    expect(dut.result.width, inputWidth + 1);

    await dut.build();

    final vectors = [
      for (var raw = 0; raw < (1 << inputWidth); raw++)
        Vector(
          {'value': raw},
          {
            'result': BigInt.from(raw).toSigned(inputWidth).abs(),
          },
        ),
    ];

    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });
}
