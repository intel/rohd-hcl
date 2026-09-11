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

  test('GenericMultiplyAccumulate rejects non-positive output widths', () {
    for (final outputWidth in [0, -1]) {
      final expectedMessage =
          'outputWidth must be positive when provided, got $outputWidth.';
      expect(
          () => GenericMultiplyAccumulate(
              Logic(name: 'a', width: 3),
              Logic(name: 'b', width: 3),
              Logic(name: 'c', width: 6),
              NativeMultiplier.new,
              outputWidth: outputWidth),
          throwsA(isA<RohdHclException>()
              .having((e) => e.message, 'message', expectedMessage)));
    }
  });

  test('MAC definition names include the effective output width', () {
    final a = Logic(width: 3);
    final b = Logic(width: 3);
    final c = Logic(width: 6);

    final genericNarrow = GenericMultiplyAccumulate(
        a, b, c, NativeMultiplier.new,
        outputWidth: 7);
    final genericWide = GenericMultiplyAccumulate(a, b, c, NativeMultiplier.new,
        outputWidth: 8);
    final compressionNarrow =
        CompressionTreeMultiplyAccumulate(a, b, c, outputWidth: 7);
    final compressionWide =
        CompressionTreeMultiplyAccumulate(a, b, c, outputWidth: 8);

    expect(genericNarrow.definitionName, isNot(genericWide.definitionName));
    expect(compressionNarrow.definitionName,
        isNot(compressionWide.definitionName));
  });

  test('StaticOrRuntimeParameter rejects wide runtime configurations', () {
    for (final config in [
      () => StaticOrRuntimeParameter(
          name: 'directConfig', runtimeConfig: Logic(width: 2)),
      () => StaticOrRuntimeParameter.ofDynamic(Logic(width: 2)),
    ]) {
      expect(
          config,
          throwsA(isA<RohdHclException>().having(
              (e) => e.message, 'message', contains('must be 1 bit wide'))));
    }
  });

  test('GenericMultiplyAccumulate forwards runtime signedness', () {
    const width = 3;
    final a = Logic(name: 'a', width: width)..put(7);
    final b = Logic(name: 'b', width: width)..put(2);
    final c = Logic(name: 'c', width: width * 2)..put(63);
    final signedOperands = Logic(name: 'signedOperands')..put(0);
    final signedConfig = StaticOrRuntimeParameter(
        name: 'signedOperands', runtimeConfig: signedOperands);
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

  test('GenericMultiplyAccumulate pipelines runtime signedness with result',
      () async {
    const width = 3;
    const outputWidth = 8;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final c = Logic(name: 'c', width: width * 2);
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic(name: 'reset');
    final signedOperands = Logic(name: 'signedOperands');
    final signedConfig = StaticOrRuntimeParameter(
        name: 'signedOperands', runtimeConfig: signedOperands);
    final mac = GenericMultiplyAccumulate(a, b, c, NativeMultiplier.new,
        clk: clk,
        reset: reset,
        outputWidth: outputWidth,
        signedAddend: signedConfig);
    await mac.build();

    unawaited(Simulator.run());

    reset.put(1);
    signedOperands.put(0);
    await clk.nextPosedge;
    reset.put(0);

    a.put(7);
    b.put(7);
    c.put(15);
    signedOperands.put(0);
    await clk.nextPosedge;
    await clk.nextNegedge;
    expect(mac.accumulate.value.toInt(), equals(64));

    // Change the mode after the result register updates. The current result
    // must retain the mode that was active when it was captured.
    signedOperands.put(1);
    expect(mac.accumulate.value.toInt(), equals(64));
    await clk.nextPosedge;
    await clk.nextNegedge;
    expect(mac.accumulate.value.toInt(), equals(64));

    await Simulator.endSimulation();
  });
}
