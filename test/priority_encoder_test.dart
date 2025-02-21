// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// priority_encoder_test.dart
// Tests for priority encoders.
//
// 2025 February 13
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void testPriorityEncoder(int n, PriorityEncoder Function(Logic a) fn) {
  final inp = Logic(name: 'inp', width: n);
  final mod = fn(inp);
  test('priority_encoder_${n}_${mod.name}', () async {
    await mod.build();

    int computePriorityEncoding(int j) {
      for (var i = 0; i < n; ++i) {
        if (((1 << i) & j) != 0) {
          return i;
        }
      }
      return 0;
    }

    for (var j = 1; j < (1 << n); ++j) {
      final golden = computePriorityEncoding(j);
      inp.put(j);
      final result = mod.out.value.toInt();
      // print('priority_encoder: $j $result $golden');
      expect(result, equals(golden));
    }
  });
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  final generators = [Ripple.new, Sklansky.new, KoggeStone.new, BrentKung.new];
  test('RecursivePriorityEncoder quick test', () {
    final inp = Logic(width: 4)..put(8);
    final valid = Logic();
    final dut = RecursivePriorityEncoder(inp, valid: valid);
    expect(dut.out.value.toInt(), equals(3));
    expect(valid.value.toBool(), equals(true));
  });
  test('RecursivePriorityModuleEncoder quick test', () async {
    final inp = Logic(width: 87)..put(8);
    final valid = Logic();
    final dut = RecursiveModulePriorityEncoder(inp, valid: valid);
    await dut.build();
    File('recur.sv').writeAsStringSync(dut.generateSynth());
    expect(dut.out.value.toInt(), equals(3));
    expect(valid.value.toBool(), equals(true));
  });

  group('Prefix Priority Encoder tests', () {
    for (final n in [7, 8, 9]) {
      for (final ppGen in generators) {
        testPriorityEncoder(
            n, (inp) => ParallelPrefixPriorityEncoder(inp, ppGen: ppGen));
      }
    }
  });
  group('Prefix Priority Encoder tests', () {
    for (final n in [7, 8, 9]) {
      testPriorityEncoder(n, RecursivePriorityEncoder.new);
      testPriorityEncoder(n, RecursiveModulePriorityEncoder.new);
    }
  });
  test('PrefixPriorityEncoder simple test', () {
    final val = Logic(width: 5);
    // ignore: cascade_invocations
    val.put(3);
    expect(ParallelPrefixPriorityEncoder(val).out.value.toInt(), equals(0));
    expect(ParallelPrefixPriorityEncoder(val.reversed).out.value.toInt(),
        equals(3));

    final valid = Logic();
    ParallelPrefixPriorityEncoder(val, valid: valid);
    expect(valid.value.toBool(), equals(true));
  });
  test('PrefixPriorityEncoder simple test', () {
    final bitVector = Logic(width: 5);
    // ignore: cascade_invocations
    bitVector.put(8);
    final valid = Logic();
    final encoder = ParallelPrefixPriorityEncoder(bitVector,
        ppGen: BrentKung.new, valid: valid);

    expect(encoder.out.value.toInt(), equals(3));
  });
  test('PrefixPriorityEncoder return beyond width if zero', () {
    final val = Logic(width: 5);
    // ignore: cascade_invocations
    val.put(0);
    expect(ParallelPrefixPriorityEncoder(val).out.value.toInt(),
        equals(val.width + 1));
    expect(ParallelPrefixPriorityEncoder(val.reversed).out.value.toInt(),
        equals(val.width + 1));
    final valid = Logic();
    ParallelPrefixPriorityEncoder(val, valid: valid);
    expect(valid.value.toBool(), equals(false));
  });
}
