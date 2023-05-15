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
    final randList = <int>[];
    List<int>.generate(listLength, (index) {
      int number;
      do {
        number = rand.nextInt(maxLength);
      } while (randList.contains(number));
      randList.add(number);
      return number;
    });

    return randList;
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

    test('should return RohdHclException if number of elements is 0.',
        () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic(name: 'reset');

      final toSort = <Logic>[];

      expect(() async {
        BitonicSort(clk, reset, toSort: toSort, name: 'top_level');
      }, throwsA((dynamic e) => e is RohdHclException));
    });

    test('should return itself if single element is given.', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic(name: 'reset');

      final toSort = <Logic>[Const(20, width: 8)];

      final topMod = BitonicSort(clk, reset, toSort: toSort, name: 'top_level');
      await topMod.build();

      reset.inject(0);

      Simulator.registerAction(100, () {
        expect(topMod.sorted[0].value.toInt(), 20);
      });

      Simulator.setMaxSimTime(100);

      await Simulator.run();
    });

    test(
        'should return RohdHclException if width '
        'is difference from each other in the list.', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic(name: 'reset');

      final toSort = <Logic>[
        Const(1),
        Const(5, width: 7),
        Const(4, width: 7),
        Const(2, width: 5),
      ];

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

        await Simulator.run();
      });

      test(
          'should return the sorted results in ascending order given '
          'random seed number with duplicate.', () async {
        const dataWidth = 8;
        final rand = Random(10);

        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic(name: 'reset');

        final toSortRes = <int>[];
        final toSort = List<Logic>.generate(pow(2, 3).toInt(), (index) {
          final number = rand.nextInt(pow(2, 3).toInt() + 1);
          toSortRes.add(number);
          return Const(number, width: dataWidth);
        });

        final topMod =
            BitonicSort(clk, reset, toSort: toSort, name: 'top_level');
        await topMod.build();

        reset.inject(0);

        toSortRes.sort();
        Simulator.registerAction(100, () {
          for (var i = 0; i < topMod.sorted.length; i++) {
            expect(topMod.sorted[i].value.toInt(), toSortRes[i]);
          }
        });

        Simulator.setMaxSimTime(100);

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

        final toSortRes =
            generateNonDuplicateRand(seed, maxRandNum, listLength);

        final toSort = <Logic>[];
        for (final num in toSortRes) {
          toSort.add(Const(num, width: dataWidth));
        }

        final topMod =
            BitonicSort(clk, reset, toSort: toSort, name: 'top_level');
        await topMod.build();

        reset.inject(0);

        toSortRes.sort();
        Simulator.registerAction(100, () {
          for (var i = 0; i < topMod.sorted.length; i++) {
            expect(topMod.sorted[i].value.toInt(), toSortRes[i]);
          }
        });

        Simulator.setMaxSimTime(100);

        await Simulator.run();
      });

      test(
          'should return the sorted results in ascending order given '
          'random seed number without duplicate, pipeline.', () async {
        const dataWidth = 8;
        const seed = 10;

        final listLength = pow(2, 2).toInt();
        final maxRandNum = listLength;

        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic(name: 'reset');

        final toSortRes =
            generateNonDuplicateRand(seed, maxRandNum, listLength);

        final a = Logic(name: 'a', width: dataWidth);
        final b = Logic(name: 'b', width: dataWidth);
        final c = Logic(name: 'c', width: dataWidth);
        final d = Logic(name: 'd', width: dataWidth);
        final toSort = <Logic>[a, b, c, d];

        final topMod =
            BitonicSort(clk, reset, toSort: toSort, name: 'top_level');
        await topMod.build();

        reset.inject(0);
        a.inject(toSortRes[0]);
        b.inject(toSortRes[1]);
        c.inject(toSortRes[2]);
        d.inject(toSortRes[3]);

        toSortRes.sort();
        Simulator.registerAction(100, () {
          for (var i = 0; i < topMod.sorted.length; i++) {
            expect(topMod.sorted[i].value.toInt(), toSortRes[i]);
          }
          b.put(10);
          d.put(11);
        });

        Simulator.registerAction(130, () {
          expect(topMod.sorted[0].value.toInt(), 0);
          expect(topMod.sorted[1].value.toInt(), 3);
          expect(topMod.sorted[2].value.toInt(), 10);
          expect(topMod.sorted[3].value.toInt(), 11);
        });

        Simulator.setMaxSimTime(300);

        await Simulator.run();
      });

      test(
          'should return the sorted results in ascending order given '
          'the inputs consists of duplicates.', () async {
        const dataWidth = 8;

        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic(name: 'reset');

        final toSort = <Logic>[
          Const(1, width: dataWidth),
          Const(7, width: dataWidth),
          Const(1, width: dataWidth),
          Const(8, width: dataWidth),
        ];

        final topMod =
            BitonicSort(clk, reset, toSort: toSort, name: 'top_level');
        await topMod.build();

        reset.inject(0);

        final toSortRes = [1, 1, 7, 8];

        Simulator.registerAction(100, () {
          for (var i = 0; i < topMod.sorted.length; i++) {
            expect(topMod.sorted[i].value.toInt(), toSortRes[i]);
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

        var toSortRes = <int>[];
        final toSort = List<Logic>.generate(pow(2, 3).toInt(), (index) {
          final number = rand.nextInt(pow(2, 3).toInt() + 1);
          toSortRes.add(number);
          return Const(number, width: dataWidth);
        });

        final topMod = BitonicSort(clk, reset,
            toSort: toSort, name: 'top_level', isAscending: false);
        await topMod.build();

        reset.inject(0);

        toSortRes.sort();
        toSortRes = toSortRes.reversed.toList();
        Simulator.registerAction(100, () {
          for (var i = 0; i < topMod.sorted.length; i++) {
            expect(topMod.sorted[i].value.toInt(), toSortRes[i]);
          }
        });

        Simulator.setMaxSimTime(100);

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

        var toSortRes = generateNonDuplicateRand(seed, maxRandNum, listLength);

        final toSort = <Logic>[];
        for (final num in toSortRes) {
          toSort.add(Const(num, width: dataWidth));
        }

        final topMod = BitonicSort(clk, reset,
            toSort: toSort, name: 'top_level', isAscending: false);
        await topMod.build();

        reset.inject(0);

        toSortRes.sort();
        toSortRes = toSortRes.reversed.toList();
        Simulator.registerAction(100, () {
          for (var i = 0; i < topMod.sorted.length; i++) {
            expect(topMod.sorted[i].value.toInt(), toSortRes[i]);
          }
        });

        Simulator.setMaxSimTime(100);

        await Simulator.run();
      });

      test(
          'should return the sorted results in descending order given '
          'random seed number without duplicate, pipeline.', () async {
        const dataWidth = 8;
        const seed = 10;

        final listLength = pow(2, 2).toInt();
        final maxRandNum = listLength;

        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic(name: 'reset');

        var toSortRes = generateNonDuplicateRand(seed, maxRandNum, listLength);

        final a = Logic(name: 'a', width: dataWidth);
        final b = Logic(name: 'b', width: dataWidth);
        final c = Logic(name: 'c', width: dataWidth);
        final d = Logic(name: 'd', width: dataWidth);
        final toSort = <Logic>[a, b, c, d];

        final topMod = BitonicSort(clk, reset,
            isAscending: false, toSort: toSort, name: 'top_level');
        await topMod.build();

        reset.inject(0);
        a.inject(toSortRes[0]);
        b.inject(toSortRes[1]);
        c.inject(toSortRes[2]);
        d.inject(toSortRes[3]);

        toSortRes.sort();
        toSortRes = toSortRes.reversed.toList();
        Simulator.registerAction(100, () {
          for (var i = 0; i < topMod.sorted.length; i++) {
            expect(topMod.sorted[i].value.toInt(), toSortRes[i]);
          }
          b.put(10);
          d.put(11);
        });

        Simulator.registerAction(200, () {
          expect(topMod.sorted[0].value.toInt(), 11);
          expect(topMod.sorted[1].value.toInt(), 10);
          expect(topMod.sorted[2].value.toInt(), 3);
          expect(topMod.sorted[3].value.toInt(), 0);
        });

        Simulator.setMaxSimTime(300);
        WaveDumper(topMod, outputPath: 'pipeline_desc.vcd');

        await Simulator.run();
      });

      test(
          'should return the sorted results in descending order given '
          'the inputs consists of duplicates.', () async {
        const dataWidth = 8;

        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic(name: 'reset');

        final toSort = <Logic>[
          Const(1, width: dataWidth),
          Const(7, width: dataWidth),
          Const(1, width: dataWidth),
          Const(8, width: dataWidth),
        ];

        final topMod = BitonicSort(clk, reset,
            toSort: toSort, isAscending: false, name: 'top_level');
        await topMod.build();

        reset.inject(0);

        final toSortRes = [8, 7, 1, 1];

        Simulator.registerAction(100, () {
          for (var i = 0; i < topMod.sorted.length; i++) {
            expect(topMod.sorted[i].value.toInt(), toSortRes[i]);
          }
        });

        Simulator.setMaxSimTime(100);

        await Simulator.run();
      });
    });
  });
}
