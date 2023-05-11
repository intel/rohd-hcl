// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// bitonic_sort_test.dart
// Tests for bitonic sort
//
// 2023 May 3
// Author: Yao Jing Quek <yao.jing.quek@intel.com>
//

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

Future<void> main() async {
  tearDown(() async {
    await Simulator.reset();
  });

  group('Bitonic Sort', () {
    test(
        'should return the sorted results in ascending order '
        'given descending order', () async {
      const dataWidth = 8;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic(name: 'reset');

      final x = <Logic>[
        Const(16, width: dataWidth),
        Const(15, width: dataWidth),
        Const(14, width: dataWidth),
        Const(13, width: dataWidth),
        Const(12, width: dataWidth),
        Const(11, width: dataWidth),
        Const(10, width: dataWidth),
        Const(9, width: dataWidth),
        Const(8, width: dataWidth),
        Const(7, width: dataWidth),
        Const(6, width: dataWidth),
        Const(5, width: dataWidth),
        Const(4, width: dataWidth),
        Const(3, width: dataWidth),
        Const(2, width: dataWidth),
        Const(1, width: dataWidth),
      ];

      final topMod = BitonicSort(clk, reset, toSort: x, name: 'top_level');
      await topMod.build();

      reset.inject(0);

      Simulator.registerAction(100, () {
        for (var i = 0; i < topMod.sorted.length; i++) {
          expect(topMod.sorted[i].value.toInt(), i + 1);
        }
      });

      Simulator.setMaxSimTime(100);
      // WaveDumper(topMod, outputPath: 'lib/src/sort/recursive_list.vcd');

      await Simulator.run();
    });

    test(
        'should return the sorted results in descending order '
        'given ascending order', () async {
      const dataWidth = 8;
      const direction = 0;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic(name: 'reset');

      final x = <Logic>[
        Const(1, width: dataWidth),
        Const(2, width: dataWidth),
        Const(3, width: dataWidth),
        Const(4, width: dataWidth),
        Const(5, width: dataWidth),
        Const(6, width: dataWidth),
        Const(7, width: dataWidth),
        Const(8, width: dataWidth),
        Const(9, width: dataWidth),
        Const(10, width: dataWidth),
        Const(11, width: dataWidth),
        Const(12, width: dataWidth),
        Const(13, width: dataWidth),
        Const(14, width: dataWidth),
        Const(15, width: dataWidth),
        Const(16, width: dataWidth),
      ];

      final topMod = BitonicSort(clk, reset,
          isAscending: false, toSort: x, name: 'top_level');
      await topMod.build();

      reset.inject(0);

      Simulator.registerAction(100, () {
        for (var i = 0; i < topMod.sorted.length; i++) {
          expect(topMod.sorted[i].value.toInt(), topMod.sorted.length - i);
        }
      });

      Simulator.setMaxSimTime(100);
      // WaveDumper(topMod, outputPath: 'lib/src/sort/recursive_list.vcd');

      await Simulator.run();
    });
  });
}
