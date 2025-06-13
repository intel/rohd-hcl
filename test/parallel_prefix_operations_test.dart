// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// parallel-prefix_operations.dart
// Implementation of operations using various parallel-prefix trees.
//
// 2023 Sep 29
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/parallel_prefix_operations.dart';
import 'package:test/test.dart';

void testOrScan(int n, ParallelPrefixOrScan Function(Logic a) fn) {
  test('or_scan_$n', () async {
    final inp = Logic(name: 'inp', width: n);
    final mod = fn(inp);
    await mod.build();

    int computeOrScan(int j) {
      var result = 0;
      var found = false;
      for (var i = 0; i < n; ++i) {
        if (found || ((1 << i) & j) != 0) {
          result |= 1 << i;
          found = true;
        }
      }
      return result;
    }

    // put/expect testing

    for (var j = 0; j < (1 << n); ++j) {
      final golden = computeOrScan(j);
      inp.put(j);
      final result = mod.out.value.toInt();
      //print("$j ${result} ${golden}");
      expect(result, equals(golden));
    }
  });
}

void testPriorityEncoder(
    int n, ParallelPrefixPriorityEncoder Function(Logic a) fn) {
  test('priority_encoder_$n', () async {
    final inp = Logic(name: 'inp', width: n);
    final mod = fn(inp);
    await mod.build();

    int computePriorityEncoding(int j) {
      for (var i = 0; i < n; ++i) {
        if (((1 << i) & j) != 0) {
          return 1 << i;
        }
      }
      return 0;
    }

    // put/expect testing

    for (var j = 0; j < (1 << n); ++j) {
      final golden = computePriorityEncoding(j);
      inp.put(j);
      final result = mod.out.value.toInt();
      // print("priority_encoder: $j ${result} ${golden}");
      expect(result, equals(golden));
    }
  });
}

void testAdder(int n, ParallelPrefixAdder Function(Logic a, Logic b) fn) {
  test('adder_$n', () async {
    final a = Logic(name: 'a', width: n);
    final b = Logic(name: 'b', width: n);

    final mod = fn(a, b);
    await mod.build();

    int computeAdder(int aa, int bb) => (aa + bb) & ((1 << n) - 1);

    // put/expect testing

    for (var aa = 0; aa < (1 << n); ++aa) {
      for (var bb = 0; bb < (1 << n); ++bb) {
        final golden = computeAdder(aa, bb);
        a.put(aa);
        b.put(bb);
        final result = mod.out.value.toInt();
        //print("adder: $aa $bb $result $golden");
        expect(result, equals(golden));
      }
    }
  });
}

void testAdderRandom(
    int n, int nSamples, ParallelPrefixAdder Function(Logic a, Logic b) fn) {
  test('adder_$n', () async {
    final a = Logic(name: 'a', width: n);
    final b = Logic(name: 'b', width: n);

    final mod = fn(a, b);
    await mod.build();

    LogicValue computeAdder(LogicValue aa, LogicValue bb) =>
        (aa + bb) & LogicValue.ofBigInt(BigInt.from((1 << n) - 1), n);
    // put/expect testing

    for (var i = 0; i < nSamples; ++i) {
      final aa = Random().nextLogicValue(width: n);
      final bb = Random().nextLogicValue(width: n);
      final golden = computeAdder(aa, bb);
      a.put(aa);
      b.put(bb);
      final result = mod.out.value;
      expect(result, equals(golden));
    }
  });
}

void testIncr(int n, ParallelPrefixIncr Function(Logic a) fn) {
  test('incr_$n', () async {
    final inp = Logic(name: 'inp', width: n);
    final mod = fn(inp);
    await mod.build();

    int computeIncr(int aa) => (aa + 1) & ((1 << n) - 1);

    // put/expect testing

    for (var aa = 0; aa < (1 << n); ++aa) {
      final golden = computeIncr(aa);
      inp.put(aa);
      final result = mod.out.value.toInt();
      //print("incr: $aa $result $golden");
      expect(result, equals(golden));
    }
  });
}

void testDecr(int n, ParallelPrefixDecr Function(Logic a) fn) {
  test('decr_$n', () async {
    final inp = Logic(name: 'inp', width: n);
    final mod = fn(inp);
    await mod.build();

    int computeDecr(int aa) => (aa - 1) % (1 << n);

    // put/expect testing

    for (var aa = 0; aa < (1 << n); ++aa) {
      final golden = computeDecr(aa);
      inp.put(aa);
      final result = mod.out.value.toInt();
      //print("decr: $aa $result $golden");
      expect(result, equals(golden));
    }
  });
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('largest_pow2_less_than', () {
    test('largest_pow2_less_than', () async {
      expect(largestPow2LessThan(5), equals(4));
      expect(largestPow2LessThan(4), equals(2));
      expect(largestPow2LessThan(3), equals(2));
    });
  });

  final generators = [Ripple.new, Sklansky.new, KoggeStone.new, BrentKung.new];

  group('or_scan', () {
    for (final n in [7, 8, 9]) {
      for (final ppGen in generators) {
        testOrScan(n, (inp) => ParallelPrefixOrScan(inp, ppGen));
      }
    }
  });

  group('priority_encoder', () {
    for (final n in [7, 8, 9]) {
      for (final ppGen in generators) {
        testPriorityEncoder(
            n, (inp) => ParallelPrefixPriorityEncoder(inp, ppGen));
      }
    }
  });

  group('adder', () {
    for (final n in [3, 4, 5]) {
      for (final ppGen in generators) {
        testAdder(n, (a, b) => ParallelPrefixAdder(a, b, ppGen));
      }
    }
  });

  group('adderRandom', () {
    for (final n in [127, 128, 129]) {
      for (final ppGen in generators) {
        testAdderRandom(n, 10, (a, b) => ParallelPrefixAdder(a, b, ppGen));
      }
    }
  });

  group('incr', () {
    for (final n in [7, 8, 9]) {
      for (final ppGen in generators) {
        testIncr(n, (inp) => ParallelPrefixIncr(inp, ppGen));
      }
    }
  });

  group('decr', () {
    for (final n in [7, 8, 9]) {
      for (final ppGen in generators) {
        testDecr(n, (inp) => ParallelPrefixDecr(inp, ppGen));
      }
    }
  });
}
