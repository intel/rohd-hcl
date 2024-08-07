// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// compressor.dart
// Column compression of partial prodcuts
//
// 2024 June 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

// Inner test of a multipy accumulate unit
void checkMultiplyAccumulate(
    MultiplyAccumulate mod, BigInt bA, BigInt bB, BigInt bC) {
  final golden = bA * bB + bC;
  // ignore: invalid_use_of_protected_member
  mod.a.put(bA);
  // ignore: invalid_use_of_protected_member
  mod.b.put(bB);
  // ignore: invalid_use_of_protected_member
  mod.c.put(bC);
  // print('$bA, $bB, $bC');

  final result = mod.signed
      ? mod.accumulate.value.toBigInt().toSigned(mod.accumulate.width)
      : mod.accumulate.value.toBigInt().toUnsigned(mod.accumulate.width);
  expect(result, equals(golden));
}

// Random testing of a mutiplier or multiplier/accumulate unit
void testMultiplyAccumulateRandom(int width, int iterations,
    MultiplyAccumulate Function(Logic a, Logic b, Logic c) fn) {
  final a = Logic(name: 'a', width: width);
  final b = Logic(name: 'b', width: width);
  final c = Logic(name: 'c', width: width * 2);
  final mod = fn(a, b, c);
  test('random_${mod.name}_S${mod.signed}_W${width}_I$iterations', () async {
    final multiplyOnly = mod is MultiplyOnly;
    await mod.build();
    final signed = mod.signed;
    for (var i = 0; i < iterations; i++) {
      final bA = signed
          ? Random().nextLogicValue(width: width).toBigInt().toSigned(width)
          : Random().nextLogicValue(width: width).toBigInt().toUnsigned(width);
      final bB = signed
          ? Random().nextLogicValue(width: width).toBigInt().toSigned(width)
          : Random().nextLogicValue(width: width).toBigInt().toUnsigned(width);
      final bC = multiplyOnly
          ? BigInt.zero
          : signed
              ? Random().nextLogicValue(width: width).toBigInt().toSigned(width)
              : Random()
                  .nextLogicValue(width: width)
                  .toBigInt()
                  .toUnsigned(width);
      checkMultiplyAccumulate(mod, bA, bB, bC);
    }
  });
}

// Exhaustive testing of a mutiplier or multiplier/accumulate unit
void testMultiplyAccumulateExhaustive(
    int width, MultiplyAccumulate Function(Logic a, Logic b, Logic c) fn) {
  final a = Logic(name: 'a', width: width);
  final b = Logic(name: 'b', width: width);
  final c = Logic(name: 'c', width: 2 * width);
  final mod = fn(a, b, c);
  test('exhaustive_${mod.name}_S${mod.signed}_W$width', () async {
    await mod.build();
    final signed = mod.signed;
    final multiplyOnly = mod is MultiplyOnly;

    final cLimit = multiplyOnly ? 1 : (1 << (2 * width));

    for (var aa = 0; aa < (1 << width); ++aa) {
      for (var bb = 0; bb < (1 << width); ++bb) {
        for (var cc = 0; cc < cLimit; ++cc) {
          final bA = signed
              ? BigInt.from(aa).toSigned(width)
              : BigInt.from(aa).toUnsigned(width);
          final bB = signed
              ? BigInt.from(bb).toSigned(width)
              : BigInt.from(bb).toUnsigned(width);
          final bC = multiplyOnly
              ? BigInt.zero
              : signed
                  ? BigInt.from(cc).toSigned(2 * width)
                  : BigInt.from(cc).toUnsigned(2 * width);

          checkMultiplyAccumulate(mod, bA, bB, bC);
        }
      }
    }
  });
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  // Use MAC tester for Multiply

  // First curry the Multiplier
  Multiplier currySignedMultiplier(Logic a, Logic b) =>
      CompressionTreeMultiplier(a, b, 4, KoggeStone.new, signed: true);

  Multiplier curryUnsignedMultiplier(Logic a, Logic b) =>
      CompressionTreeMultiplier(a, b, 4, KoggeStone.new, signed: true);

  // Now treat the multiplier as a MAC with a zero input addend [c]
  MultiplyAccumulate currySignedMultiplierAsMAC(Logic a, Logic b, Logic c) =>
      MultiplyOnly(a, b, c, currySignedMultiplier);

  MultiplyAccumulate curryUnsignedMultiplierAsMAC(Logic a, Logic b, Logic c) =>
      MultiplyOnly(a, b, c, curryUnsignedMultiplier);

  group('test Compression Tree Multiplier Randomly', () {
    for (final width in [4, 5, 6, 11]) {
      testMultiplyAccumulateRandom(width, 30, currySignedMultiplierAsMAC);
      testMultiplyAccumulateRandom(width, 30, curryUnsignedMultiplierAsMAC);
    }
  });
  group('test Compression Tree Multiplier Exhaustive', () {
    for (final width in [4, 5]) {
      testMultiplyAccumulateExhaustive(width, currySignedMultiplierAsMAC);
      testMultiplyAccumulateExhaustive(width, curryUnsignedMultiplierAsMAC);
    }
  });

  MultiplyAccumulate currySignedCompressionTreeMultiplyAccumulate(
          Logic a, Logic b, Logic c) =>
      CompressionTreeMultiplyAccumulate(a, b, c, 4, KoggeStone.new,
          signed: true);
  MultiplyAccumulate curryUnsignedCompressionTreeMultiplyAccumulate(
          Logic a, Logic b, Logic c) =>
      CompressionTreeMultiplyAccumulate(a, b, c, 4, KoggeStone.new);

  group('test Multiply Accumulate Random', () {
    for (final width in [4, 5, 6, 11]) {
      testMultiplyAccumulateRandom(
          width, 30, currySignedCompressionTreeMultiplyAccumulate);
      testMultiplyAccumulateRandom(
          width, 30, curryUnsignedCompressionTreeMultiplyAccumulate);
    }
  });
  group('test Multiply Accumulate Exhaustive', () {
    for (final width in [3, 4]) {
      testMultiplyAccumulateExhaustive(
          width, currySignedCompressionTreeMultiplyAccumulate);
      testMultiplyAccumulateExhaustive(
          width, curryUnsignedCompressionTreeMultiplyAccumulate);
    }
  });

  test('single mac', () async {
    const width = 6;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final c = Logic(name: 'c', width: 2 * width);

    const av = 0;
    const bv = 0;
    const cv = -512;
    for (final signed in [true, false]) {
      final bA = signed
          ? BigInt.from(av).toSigned(width)
          : BigInt.from(av).toUnsigned(width);
      final bB = signed
          ? BigInt.from(bv).toSigned(width)
          : BigInt.from(bv).toUnsigned(width);
      final bC = signed
          ? BigInt.from(cv).toSigned(2 * width)
          : BigInt.from(cv).toUnsigned(width * 2);

      // Set these so that printing inside module build will have Logic values
      a.put(bA);
      b.put(bB);
      c.put(bC);

      final mod = CompressionTreeMultiplyAccumulate(a, b, c, 4, KoggeStone.new,
          signed: signed);
      checkMultiplyAccumulate(mod, bA, bB, bC);
    }
  });
}
