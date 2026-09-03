// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// generic_multiply_accumulate_test.dart
// Tests for the configurable generic multiply-accumulate component.
//
// 2026 September 2
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('GenericMultiplyAccumulate computes unsigned corner cases', () {
    const width = 3;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final c = Logic(name: 'c', width: width * 2);
    final mac = GenericMultiplyAccumulate(a, b, c, NativeMultiplier.new);

    for (final vector in [
      (a: 0, b: 0, c: 0, expected: 0),
      (a: 7, b: 7, c: 0, expected: 49),
      (a: 0, b: 7, c: 63, expected: 63),
      (a: 7, b: 7, c: 63, expected: 112),
    ]) {
      a.put(vector.a);
      b.put(vector.b);
      c.put(vector.c);
      expect(mac.accumulate.value.toInt(), equals(vector.expected),
          reason: 'a=${vector.a} b=${vector.b} c=${vector.c}');
    }
  });

  test('GenericMultiplyAccumulate forwards runtime signedness', () {
    const width = 3;
    final a = Logic(name: 'a', width: width)..put(7);
    final b = Logic(name: 'b', width: width)..put(2);
    final c = Logic(name: 'c', width: width * 2)..put(63);
    final signedOperands = Logic(name: 'signedOperands')..put(0);
    final signedConfig = RuntimeConfig(signedOperands, name: 'signedOperands');
    final mac = GenericMultiplyAccumulate(a, b, c, NativeMultiplier.new,
        signedMultiplicand: signedConfig,
        signedMultiplier: signedConfig,
        signedAddend: signedConfig);

    expect(mac.accumulate.value.toInt(), equals(77));

    signedOperands.put(1);
    expect(mac.accumulate.value.toBigInt().toSigned(mac.accumulate.width),
        equals(BigInt.from(-3)));
  });

  test('GenericMultiplyAccumulate preserves a wide signed addend', () {
    const operandWidth = 3;
    const addendWidth = 8;
    const outputWidth = 12;
    final a = Logic(name: 'a', width: operandWidth);
    final b = Logic(name: 'b', width: operandWidth);
    final c = Logic(name: 'c', width: addendWidth);
    final mac = GenericMultiplyAccumulate(a, b, c, NativeMultiplier.new,
        signedMultiplicand: true,
        signedMultiplier: true,
        signedAddend: true,
        outputWidth: outputWidth);

    for (final vector in [
      (a: -4, b: -4, c: -128, expected: -112),
      (a: 3, b: 3, c: 127, expected: 136),
      (a: -4, b: 3, c: -128, expected: -140),
    ]) {
      a.put(BigInt.from(vector.a).toUnsigned(operandWidth));
      b.put(BigInt.from(vector.b).toUnsigned(operandWidth));
      c.put(BigInt.from(vector.c).toUnsigned(addendWidth));
      final actual = mac.accumulate.value.toBigInt().toSigned(outputWidth);
      expect(actual, equals(BigInt.from(vector.expected)),
          reason: 'a=${vector.a} b=${vector.b} c=${vector.c}');
    }
  });

  test('GenericMultiplyAccumulate accepts a compression-tree multiplier', () {
    const width = 4;
    final a = Logic(name: 'a', width: width)..put(3);
    final b = Logic(name: 'b', width: width)..put(5);
    final c = Logic(name: 'c', width: width * 2)..put(1);

    Multiplier multiplierGen(Logic a, Logic b,
            {dynamic signedMultiplicand, dynamic signedMultiplier}) =>
        CompressionTreeMultiplier(a, b,
            signedMultiplicand: signedMultiplicand,
            signedMultiplier: signedMultiplier);

    final mac = GenericMultiplyAccumulate(a, b, c, multiplierGen);
    expect(mac.accumulate.value.toInt(), equals(16));
  });

  test('GenericMultiplyAccumulate pipelines back-to-back inputs', () async {
    const width = 3;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final c = Logic(name: 'c', width: width * 2);
    final clk = SimpleClockGenerator(10).clk;
    final mac =
        GenericMultiplyAccumulate(a, b, c, NativeMultiplier.new, clk: clk);
    await mac.build();

    final vectors = [
      (a: 0, b: 0, c: 0, expected: 0),
      (a: 7, b: 7, c: 63, expected: 112),
      (a: 1, b: 7, c: 0, expected: 7),
      (a: 3, b: 3, c: 1, expected: 10),
    ];

    unawaited(Simulator.run());
    for (final vector in vectors) {
      a.put(vector.a);
      b.put(vector.b);
      c.put(vector.c);
      await clk.nextNegedge;
      expect(mac.accumulate.value.toInt(), equals(vector.expected),
          reason: 'a=${vector.a} b=${vector.b} c=${vector.c}');
    }
    await Simulator.endSimulation();
  });
}
