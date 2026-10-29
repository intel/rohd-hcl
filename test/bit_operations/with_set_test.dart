// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// with_set_test.dart
// Tests for WithSet.
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

  test('WithSet writes a slice, dropping bits past the subject width',
      () async {
    // Corner cases on a 6-bit subject with a 3-bit value. Starts of 0 and 5
    // fit the subject; a start of 7 is past the width, so every value bit is
    // dropped and the subject is unchanged.
    const subjectWidth = 6;
    const valueWidth = 3;
    const full = (1 << subjectWidth) - 1;

    final subject = Logic(name: 'subject', width: subjectWidth);
    final start = Logic(name: 'start', width: 3);
    final value = Logic(name: 'value', width: valueWidth);
    final dut = WithSet(subject, start, value);
    await dut.build();

    final vectors = [
      for (final s in [0x00, 0x3F, 0x2A])
        for (final st in [0, 5, 7])
          for (final v in [0x0, 0x7, 0x5])
            () {
              final mask = ((1 << valueWidth) - 1) << st & full;
              final aligned = (v << st) & full;
              return Vector({'subject': s, 'start': st, 'value': v},
                  {'result': (s & ~mask & full) | (aligned & mask)});
            }()
    ];

    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
  });
}
