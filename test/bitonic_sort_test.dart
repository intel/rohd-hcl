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
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

Future<void> main() async {
  tearDown(() async {
    await Simulator.reset();
  });

  List<int> generateNonDuplicateRand(int seed, int maxLength, int listLength) {
    final rand = Random(seed);
    return List<int>.generate(listLength, (index) {
      int number;
      final duplicateList = <int>[];
      do {
        number = rand.nextInt(maxLength);
      } while (duplicateList.contains(number));
      duplicateList.add(number);
      return number;
    });
  }

  group('Bitonic Sort', () {
    test('should return RohdHclException if inputs is not power of two.',
        () async {
      const dataWidth = 8;
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic(name: 'reset');

      final toSort =
          List.generate(3, (index) => Const(index + 1, width: dataWidth));

      expect(() async {
        BitonicSort(clk, reset, toSort: toSort, name: 'top_level');
      }, throwsA((dynamic e) => e is RohdHclException));
    });
    group('Ascending Order: ', () {
      test(
          'should return the sorted results in ascending order '
          'given descending order.', () async {
        const dataWidth = 8;

        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic(name: 'reset');

        final toSort = List.generate(
            16, (index) => Const(16 - index - 1, width: dataWidth));

        final topMod =
            BitonicSort(clk, reset, toSort: toSort, name: 'top_level');
        await topMod.build();

        reset.inject(0);

        Simulator.registerAction(100, () {
          for (var i = 0; i < topMod.sorted.length; i++) {
            expect(topMod.sorted[i].value.toInt(), i);
          }
        });

        Simulator.setMaxSimTime(100);
        WaveDumper(topMod, outputPath: 'test/recursive_list.vcd');

        await Simulator.run();
      });

      test(
          'should return the sorted results in ascending order given '
          'random seed number with duplicate.', () async {
        const dataWidth = 8;
        final rand = Random(10);

        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic(name: 'reset');

        final toSortInt = <int>[];
        final toSort = List<Logic>.generate(pow(2, 3).toInt(), (index) {
          final number = rand.nextInt(pow(2, 3).toInt() + 1);
          toSortInt.add(number);
          return Const(number, width: dataWidth);
        });

        final topMod =
            BitonicSort(clk, reset, toSort: toSort, name: 'top_level');
        await topMod.build();

        reset.inject(0);

        toSortInt.sort();
        Simulator.registerAction(100, () {
          for (var i = 0; i < topMod.sorted.length; i++) {
            expect(topMod.sorted[i].value.toInt(), toSortInt[i]);
          }
        });

        Simulator.setMaxSimTime(100);
        WaveDumper(topMod, outputPath: 'test/recursive_list.vcd');

        await Simulator.run();
      });

      test(
          'should return the sorted results in ascending order given '
          'random seed number without duplicate.', () async {
        const dataWidth = 8;
        const seed = 10;

        final listLength = pow(2, 3).toInt();
        final maxRandNum = listLength;

        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic(name: 'reset');

        final toSortInt =
            generateNonDuplicateRand(seed, maxRandNum, listLength);

        final toSort = <Logic>[];
        for (final num in toSortInt) {
          toSort.add(Const(num, width: dataWidth));
        }

        final topMod =
            BitonicSort(clk, reset, toSort: toSort, name: 'top_level');
        await topMod.build();

        reset.inject(0);

        toSortInt.sort();
        Simulator.registerAction(100, () {
          for (var i = 0; i < topMod.sorted.length; i++) {
            expect(topMod.sorted[i].value.toInt(), toSortInt[i]);
          }
        });

        Simulator.setMaxSimTime(100);

        await Simulator.run();
      });
    });

    group('Descending Order: ', () {
      test(
          'should return the sorted results in descending order '
          'given ascending order.', () async {
        const dataWidth = 8;

        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic(name: 'reset');

        final toSort =
            List.generate(16, (index) => Const(index + 1, width: dataWidth));

        final topMod = BitonicSort(clk, reset,
            isAscending: false, toSort: toSort, name: 'top_level');
        await topMod.build();

        reset.inject(0);

        Simulator.registerAction(100, () {
          for (var i = 0; i < topMod.sorted.length; i++) {
            expect(topMod.sorted[i].value.toInt(), topMod.sorted.length - i);
          }
        });

        Simulator.setMaxSimTime(100);

        await Simulator.run();
      });

      test(
          'should return the sorted results in descending order given '
          'random seed number with duplicate.', () async {
        const dataWidth = 8;
        final rand = Random(10);

        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic(name: 'reset');

        var toSortInt = <int>[];
        final toSort = List<Logic>.generate(pow(2, 3).toInt(), (index) {
          final number = rand.nextInt(pow(2, 3).toInt() + 1);
          toSortInt.add(number);
          return Const(number, width: dataWidth);
        });

        final topMod = BitonicSort(clk, reset,
            toSort: toSort, name: 'top_level', isAscending: false);
        await topMod.build();

        reset.inject(0);

        toSortInt.sort();
        toSortInt = toSortInt.reversed.toList();
        Simulator.registerAction(100, () {
          for (var i = 0; i < topMod.sorted.length; i++) {
            expect(topMod.sorted[i].value.toInt(), toSortInt[i]);
          }
        });

        Simulator.setMaxSimTime(100);
        WaveDumper(topMod, outputPath: 'test/recursive_list.vcd');

        await Simulator.run();
      });

      test(
          'should return the sorted results in descending order given '
          'random seed number without duplicate.', () async {
        const dataWidth = 8;
        const seed = 10;

        final listLength = pow(2, 3).toInt();
        final maxRandNum = listLength;

        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic(name: 'reset');

        var toSortInt = generateNonDuplicateRand(seed, maxRandNum, listLength);

        final toSort = <Logic>[];
        for (final num in toSortInt) {
          toSort.add(Const(num, width: dataWidth));
        }

        final topMod = BitonicSort(clk, reset,
            toSort: toSort, name: 'top_level', isAscending: false);
        await topMod.build();

        reset.inject(0);

        toSortInt.sort();
        toSortInt = toSortInt.reversed.toList();
        Simulator.registerAction(100, () {
          for (var i = 0; i < topMod.sorted.length; i++) {
            expect(topMod.sorted[i].value.toInt(), toSortInt[i]);
          }
        });

        Simulator.setMaxSimTime(100);

        await Simulator.run();
      });
    });
  });
}
