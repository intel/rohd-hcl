// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

/// Expected output of [SetBits] for input [v] of width [w] and [count].
int _expectedSet(int v, int w, int count,
    {required bool lsbs, required bool fill}) {
  final full = (1 << w) - 1;
  final c = count > w ? w : count;
  final selected = lsbs ? (1 << c) - 1 : full & ~((1 << (w - c)) - 1);
  return fill ? (v | selected) & full : v & ~selected & full;
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  for (final lsbs in [true, false]) {
    for (final fill in [false, true]) {
      final side = lsbs ? 'lsbs' : 'msbs';
      final bit = fill ? 'ones' : 'zeros';
      test('set $side to $bit over width 4 at counts 0, 1, 4, and 7', () async {
        final inp = Logic(name: 'inp', width: 4);
        final count = Logic(name: 'count', width: 3);
        final dut = SetBits(inp, count, lsbs: lsbs, fill: fill);
        await dut.build();

        final vectors = [
          for (final v in [0x0, 0xF, 0x5, 0xA])
            for (final c in [0, 1, 4, 7])
              Vector({
                'inp': v,
                'count': c
              }, {
                'result': _expectedSet(v, 4, c, lsbs: lsbs, fill: fill),
              }),
        ];

        await SimCompare.checkFunctionalVector(dut, vectors);
        if (lsbs && fill) {
          SimCompare.checkIverilogVector(dut, vectors);
        }
      });
    }
  }
}
