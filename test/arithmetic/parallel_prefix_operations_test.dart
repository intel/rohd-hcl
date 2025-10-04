// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// parallel_prefix_operations.dart
// Implementation of operations using various parallel-prefix trees.
//
// 2023 Sep 29
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/parallel_prefix_operations.dart';
import 'package:test/test.dart';

void testOrScan(int n, ParallelPrefixOrScan Function(Logic a) fn) {
  final inp = Logic(name: 'inp', width: n);
  final mod = fn(inp);
  test('or_scan_${n}_${mod.name}', () async {
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

    for (var j = 0; j < (1 << n); ++j) {
      final golden = computeOrScan(j);
      inp.put(j);
      final result = mod.out.value.toInt();
      expect(result, equals(golden));
    }
  });
}

void testPriorityFinder(
    int n, ParallelPrefixPriorityFinder Function(Logic a) fn) {
  final inp = Logic(name: 'inp', width: n);
  final mod = fn(inp);
  test('priority_finder_${n}_${mod.name}', () async {
    await mod.build();

    int computePriorityLocation(int j) {
      for (var i = 0; i < n; ++i) {
        if (((1 << i) & j) != 0) {
          return 1 << i;
        }
      }
      return 0;
    }

    // put/expect testing

    for (var j = 0; j < (1 << n); ++j) {
      final golden = computePriorityLocation(j);
      inp.put(j);
      final result = mod.out.value.toInt();
      expect(result, equals(golden));
    }
  });
}

void testIncr(int n, ParallelPrefixIncr Function(Logic a) fn) {
  final inp = Logic(name: 'inp', width: n);
  final mod = fn(inp);
  test('incr_${n}_${mod.name}', () async {
    await mod.build();

    int computeIncr(int aa) => (aa + 1) & ((1 << n) - 1);

    // put/expect testing

    for (var aa = 0; aa < (1 << n); ++aa) {
      final golden = computeIncr(aa);
      inp.put(aa);
      final result = mod.out.value.toInt();
      expect(result, equals(golden));
    }
  });
}

void testDecr(int n, ParallelPrefixDecr Function(Logic a) fn) {
  final inp = Logic(name: 'inp', width: n);
  final mod = fn(inp);
  test('decr_${n}_${mod.name}', () async {
    await mod.build();

    int computeDecr(int aa) => (aa - 1) % (1 << n);

    // put/expect testing

    for (var aa = 0; aa < (1 << n); ++aa) {
      final golden = computeDecr(aa);
      inp.put(aa);
      final result = mod.out.value.toInt();
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
        testOrScan(n, (inp) => ParallelPrefixOrScan(inp, ppGen: ppGen));
      }
    }
  });

  group('priority_finder', () {
    for (final n in [7, 8, 9]) {
      for (final ppGen in generators) {
        testPriorityFinder(
            n, (inp) => ParallelPrefixPriorityFinder(inp, ppGen: ppGen));
      }
    }
  });

  group('incr', () {
    for (final n in [7, 8, 9]) {
      for (final ppGen in generators) {
        testIncr(n, (inp) => ParallelPrefixIncr(inp, ppGen: ppGen));
      }
    }
  });

  group('decr', () {
    for (final n in [7, 8, 9]) {
      for (final ppGen in generators) {
        testDecr(n, (inp) => ParallelPrefixDecr(inp, ppGen: ppGen));
      }
    }
  });

  // Note:  all ParallelPrefixAdders are tested in adder_test.dart
  // Note:  all ParallelPrefixPriorityEncoders are tested in
  // priority_encoder_test.dart
}
