// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// bitonic_sort_test.dart
// Tests for bitonic sort
//
// 2023 May 3
// Author: Yao Jing Quek <yao.jing.quek@intel.com>
//

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

Future<void> main() async {
  tearDown(() async {
    await Simulator.reset();
  });

  group('Compare Swap', () {
    test('should swap value if ascending and i > j', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic(name: 'reset');

      final inputs = <Logic>[
        Const(8, width: 8),
        Const(3, width: 8),
      ];

      final swapModule = CompareSwap(clk, reset, inputs, 0, 1, 1);
      await swapModule.build();

      Simulator.setMaxSimTime(30);
      unawaited(Simulator.run());

      await clk.nextPosedge;
      expect(swapModule.yList[0].value.toInt(), 3);
      expect(swapModule.yList[1].value.toInt(), 8);

      await Simulator.simulationEnded;
    });

    test('should swap value if descending and i < j', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic(name: 'reset');

      final inputs = <Logic>[
        Const(3, width: 8),
        Const(8, width: 8),
      ];

      final swapModule = CompareSwap(clk, reset, inputs, 0, 1, 0);
      await swapModule.build();

      Simulator.setMaxSimTime(30);
      unawaited(Simulator.run());

      await clk.nextPosedge;
      expect(swapModule.yList[0].value.toInt(), 8);
      expect(swapModule.yList[1].value.toInt(), 3);

      await Simulator.simulationEnded;
    });
  });

  group('Bitonic Merge', () {
    test('should merge the bitonic sequence into ascending list', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic(name: 'reset');

      final bitonicSeq = <Logic>[
        Const(1, width: 8),
        Const(2, width: 8),
        Const(3, width: 8),
        Const(4, width: 8),
        Const(5, width: 8),
        Const(6, width: 8),
        Const(7, width: 8),
        Const(8, width: 8),
        Const(16, width: 8),
        Const(15, width: 8),
        Const(14, width: 8),
        Const(13, width: 8),
        Const(12, width: 8),
        Const(11, width: 8),
        Const(10, width: 8),
        Const(9, width: 8),
      ];

      final bMerge = BitonicMerge(clk, reset, bitonicSeq, 7);
      await bMerge.build();

      WaveDumper(bMerge, outputPath: 'bitonic_merge.vcd');

      Simulator.registerAction(40, () {
        for (var i = 0; i < bMerge.sortedList.length; i++) {
          expect(bMerge.sortedList[i].value.toInt(), i + 1);
        }
      });

      Simulator.setMaxSimTime(50);
      await Simulator.run();
    });
  });

  group('Bitonic Sort', () {
    test('should return the sorted results ', () async {
      const dataWidth = 8;
      const direction = 1;

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

      final topMod = BitonicSort(clk, reset, x, direction, name: 'top_level');
      await topMod.build();

      reset.inject(0);

      Simulator.registerAction(100, () {
        for (var i = 0; i < topMod.yList.length; i++) {
          expect(topMod.yList[i].value.toInt(), i + 1);
        }
      });

      Simulator.setMaxSimTime(100);
      WaveDumper(topMod, outputPath: 'lib/src/sort/recursive_list.vcd');

      await Simulator.run();
    });
  });
}
