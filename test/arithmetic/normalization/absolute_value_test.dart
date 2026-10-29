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

  test('widens by one bit so the most-negative value does not wrap', () async {
    // Corners at width 4: zero, one, the largest positive value, the
    // most-negative value (-8 -> 8), and -1 (-> 1).
    const inputWidth = 4;
    final dut = AbsoluteValue(Logic(width: inputWidth));

    expect(dut.outputWidth, inputWidth + 1);
    expect(dut.result.width, inputWidth + 1);

    await dut.build();

    final vectors = [
      for (final raw in [0, 1, 7, 8, 9, 15])
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
