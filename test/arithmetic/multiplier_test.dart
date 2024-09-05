// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// multiplier_test.dart
// Test Multiplier and MultiplerAccumulate:  CompressionTree implementations
//
// 2024 August 7
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
    final multiplyOnly = mod is MutiplyOnly;
    await mod.build();
    final signed = mod.signed;
    final value = Random(47);
    for (var i = 0; i < iterations; i++) {
      final bA = signed
          ? value.nextLogicValue(width: width).toBigInt().toSigned(width)
          : value.nextLogicValue(width: width).toBigInt().toUnsigned(width);
      final bB = signed
          ? value.nextLogicValue(width: width).toBigInt().toSigned(width)
          : value.nextLogicValue(width: width).toBigInt().toUnsigned(width);
      final bC = multiplyOnly
          ? BigInt.zero
          : signed
              ? value.nextLogicValue(width: width).toBigInt().toSigned(width)
              : value.nextLogicValue(width: width).toBigInt().toUnsigned(width);
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
    final multiplyOnly = mod is MutiplyOnly;

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

typedef MultiplyAccumulateCallback = MultiplyAccumulate Function(
    Logic a, Logic b, Logic c);

typedef MultiplierCallback = Multiplier Function(Logic a, Logic b);

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  MultiplierCallback curryCompressionTreeMultiplier(
          int radix,
          ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
              ppTree,
          {required bool signed}) =>
      (a, b) => CompressionTreeMultiplier(a, b, radix,
          ppTree: ppTree, signed: signed);

  MultiplyAccumulateCallback curryMultiplierAsMultiplyAccumulate(
          int radix,
          ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
              ppTree,
          {required bool signed}) =>
      (a, b, c) => MutiplyOnly(a, b, c,
          curryCompressionTreeMultiplier(radix, ppTree, signed: signed));

  MultiplyAccumulateCallback curryMultiplyAccumulate(
          int radix,
          ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
              ppTree,
          {required bool signed}) =>
      (a, b, c) => CompressionTreeMultiplyAccumulate(a, b, c, radix,
          ppTree: ppTree, signed: signed);

  group('Curried Test of Compression Tree Multiplier', () {
    for (final signed in [false, true]) {
      for (final radix in [2, 16]) {
        for (final width in [5, 6]) {
          for (final ppTree in [KoggeStone.new, BrentKung.new]) {
            testMultiplyAccumulateRandom(
                width,
                10,
                curryMultiplierAsMultiplyAccumulate(radix, ppTree,
                    signed: signed));
          }
        }
      }
    }
  });

  group('Curried Test of Compression Tree Multiplier Accumulate', () {
    for (final signed in [false, true]) {
      for (final radix in [2, 16]) {
        for (final width in [5, 6]) {
          for (final ppTree in [KoggeStone.new, BrentKung.new]) {
            testMultiplyAccumulateRandom(width, 10,
                curryMultiplyAccumulate(radix, ppTree, signed: signed));
          }
        }
      }
    }
  });

  test('single mac', () async {
    const width = 8;
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

      final mod = CompressionTreeMultiplyAccumulate(a, b, c, 4, signed: signed);
      checkMultiplyAccumulate(mod, bA, bB, bC);
    }
  });

  test('single rectangular mac', () async {
    const widthA = 6;
    const widthB = 9;
    final a = Logic(name: 'a', width: widthA);
    final b = Logic(name: 'b', width: widthB);
    final c = Logic(name: 'c', width: widthA + widthB);

    const av = 0;
    const bv = 0;
    const cv = -512;
    for (final signed in [true, false]) {
      final bA = signed
          ? BigInt.from(av).toSigned(widthA)
          : BigInt.from(av).toUnsigned(widthA);
      final bB = signed
          ? BigInt.from(bv).toSigned(widthB)
          : BigInt.from(bv).toUnsigned(widthB);
      final bC = signed
          ? BigInt.from(cv).toSigned(widthA + widthB)
          : BigInt.from(cv).toUnsigned(widthA + widthB);

      // Set these so that printing inside module build will have Logic values
      a.put(bA);
      b.put(bB);
      c.put(bC);

      final mod = CompressionTreeMultiplyAccumulate(a, b, c, 4, signed: signed);
      checkMultiplyAccumulate(mod, bA, bB, bC);
    }
  });
  test('trivial compression tree multiply-accumulate test', () async {
    const widthA = 6;
    const widthB = 6;
    const radix = 8;
    final a = Logic(name: 'a', width: widthA);
    final b = Logic(name: 'b', width: widthB);
    final c = Logic(name: 'c', width: widthA + widthB);

    a.put(15);
    b.put(3);
    c.put(5);

    final multiplier =
        CompressionTreeMultiplyAccumulate(a, b, c, radix, signed: true);
    final accumulate = multiplier.accumulate;
    expect(accumulate.value.toBigInt(), equals(BigInt.from(15 * 3 + 5)));
  });
}
