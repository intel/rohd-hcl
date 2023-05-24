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

    while (randList.length < listLength) {
      final randNum = rand.nextInt(10);

      if (randList.contains(randNum) == false) {
        randList.add(randNum);
      }
    }

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
        'is difference between each other in the list.', () async {
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

      test(
          'should return sorted results after latency of the'
          ' sorting completed for all random numbers in ascending, pipeline.',
          () async {
        const dataWidth = 10;

        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic(name: 'reset');

        final a = Logic(name: 'in_1', width: dataWidth);
        final b = Logic(name: 'in_2', width: dataWidth);
        final c = Logic(name: 'in_3', width: dataWidth);
        final d = Logic(name: 'in_4', width: dataWidth);
        final toSort = <Logic>[a, b, c, d];

        final topMod =
            BitonicSort(clk, reset, toSort: toSort, name: 'top_level');

        await topMod.build();

        Simulator.setMaxSimTime(1000);
        unawaited(Simulator.run());

        Future<void> waitCycles(int numCycles) async {
          for (var i = 0; i < numCycles; i++) {
            await clk.nextPosedge;
          }
        }

        final inputs = List.generate(
            10, (index) => List.generate(4, (index) => Random().nextInt(10)));

        for (final input in inputs) {
          a.put(input[0]);
          b.put(input[1]);
          c.put(input[2]);
          d.put(input[3]);

          input.sort();

          await waitCycles(topMod.latency).then((value) {
            for (var i = 0; i < topMod.sorted.length; i++) {
              expect(topMod.sorted[i].value.toInt(), input[i]);
            }
          });

          await clk.nextNegedge;
        }

        await Simulator.simulationEnded;
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

      test(
          'should return sorted results after latency of the sorting'
          ' completed for all random numbers in descending, pipeline.',
          () async {
        const dataWidth = 10;

        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic(name: 'reset');

        final a = Logic(name: 'in_1', width: dataWidth);
        final b = Logic(name: 'in_2', width: dataWidth);
        final c = Logic(name: 'in_3', width: dataWidth);
        final d = Logic(name: 'in_4', width: dataWidth);
        final toSort = <Logic>[a, b, c, d];

        final topMod = BitonicSort(clk, reset,
            toSort: toSort, name: 'top_level', isAscending: false);

        await topMod.build();

        Simulator.setMaxSimTime(1000);
        unawaited(Simulator.run());

        Future<void> waitCycles(int numCycles) async {
          for (var i = 0; i < numCycles; i++) {
            await clk.nextPosedge;
          }
        }

        final inputs = List.generate(
            10, (index) => List.generate(4, (index) => Random().nextInt(10)));

        for (var input in inputs) {
          a.put(input[0]);
          b.put(input[1]);
          c.put(input[2]);
          d.put(input[3]);

          input.sort();

          input = input.reversed.toList();

          await waitCycles(topMod.latency).then((value) {
            for (var i = 0; i < topMod.sorted.length; i++) {
              expect(topMod.sorted[i].value.toInt(), input[i]);
            }
          });
          await clk.nextNegedge;
        }

        await Simulator.simulationEnded;
      });
    });
  });
}
