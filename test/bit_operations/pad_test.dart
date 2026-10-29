// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

/// Expected output of [Pad] for input [v] of width [w] widened to [atLeast].
int _expectedPad(int v, int w, int atLeast,
    {required bool lsbs, required bool fill}) {
  final outW = w > atLeast ? w : atLeast;
  final padW = outW - w;
  final padBits = fill ? (1 << padW) - 1 : 0;
  return lsbs ? (v << padW) | padBits : v | (padBits << w);
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  for (final lsbs in [true, false]) {
    for (final fill in [false, true]) {
      final side = lsbs ? 'lsb' : 'msb';
      final bit = fill ? 'ones' : 'zeros';
      test('pad $side with $bit widens width 4 to 6', () async {
        final inp = Logic(name: 'inp', width: 4);
        final dut = Pad(inp, atLeast: 6, lsbs: lsbs, fill: fill);
        await dut.build();

        final vectors = [
          for (final v in [0x0, 0xF, 0x5, 0xA])
            Vector({
              'inp': v
            }, {
              'result': _expectedPad(v, 4, 6, lsbs: lsbs, fill: fill),
            }),
        ];

        await SimCompare.checkFunctionalVector(dut, vectors);
        if (lsbs && fill) {
          SimCompare.checkIverilogVector(dut, vectors);
        }
      });
    }
  }

  test('pad returns the input unchanged when already wide enough', () async {
    final inp = Logic(name: 'inp', width: 4);
    final dut = Pad(inp, atLeast: 3, fill: true);
    await dut.build();

    final vectors = [
      for (final v in [0x0, 0xF, 0x9]) Vector({'inp': v}, {'result': v}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
  });
}
