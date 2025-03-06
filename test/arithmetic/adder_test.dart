// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// adder_test.dart
// Tests for the Adder interface.
//
// 2024 April 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

// ignore_for_file: invalid_use_of_protected_member

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void checkAdder(Adder adder, LogicValue av, LogicValue bv, LogicValue cv) {
  final aB = av.toBigInt();
  final bB = bv.toBigInt();
  final cB = cv.toBigInt();
  adder.a.put(av);
  adder.b.put(bv);
  final BigInt golden;
  if (adder.hasCarryIn) {
    adder.carryIn!.put(cv);
    golden = aB + bB + cB;
  } else {
    golden = aB + bB;
  }
  expect(adder.sum.value.toBigInt(), equals(golden));
}

void testAdderRandomIter(int n, int nSamples, Adder adder) {
  test('random ci: ${adder.name}_W${n}_I$nSamples', () async {
    for (var i = 0; i < nSamples; i++) {
      final aa = Random().nextLogicValue(width: n);
      final bb = Random().nextLogicValue(width: n);
      final cc = Random().nextLogicValue(width: 1);
      checkAdder(adder, aa, bb, cc);
    }
  });
}

void testAdderExhaustiveIter(int n, Adder mod) {
  test(
      'exhaustive cin: ${mod.name}_W$n'
      '_G${mod.name}', () async {
    for (var aa = 0; aa < (1 << n); aa++) {
      for (var bb = 0; bb < (1 << n); bb++) {
        for (var cc = 0; cc < 2; cc++) {
          final av = LogicValue.of(BigInt.from(aa), width: n);
          final bv = LogicValue.of(BigInt.from(bb), width: n);
          final cv = Random().nextLogicValue(width: 1);

          checkAdder(mod, av, bv, cv);
        }
      }
    }
  });
}

void testAdderRandom(
    int n, int nSamples, Adder Function(Logic a, Logic b, {Logic? carryIn}) fn,
    {bool testCarryIn = true}) {
  testAdderRandomIter(
      n,
      nSamples,
      fn(Logic(name: 'a', width: n), Logic(name: 'b', width: n),
          carryIn: testCarryIn ? Logic(name: 'c') : null));
}

void testAdderExhaustive(
    int n, Adder Function(Logic a, Logic b, {Logic? carryIn}) fn,
    {bool testCarryIn = true}) {
  testAdderExhaustiveIter(
      n,
      fn(Logic(name: 'a', width: n), Logic(name: 'b', width: n),
          carryIn: testCarryIn ? Logic(name: 'c') : null));
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  final generators = [Ripple.new, Sklansky.new, KoggeStone.new, BrentKung.new];

  final adders = [
    RippleCarryAdder.new,
    NativeAdder.new,
  ];

  group('adder random', () {
    for (final n in [63, 64, 65]) {
      for (final testCin in [false, true]) {
        for (final adder in adders) {
          testAdderRandom(n, 30, adder, testCarryIn: testCin);
        }
        for (final ppGen in generators) {
          testAdderRandom(
              n,
              30,
              (a, b, {carryIn}) =>
                  ParallelPrefixAdder(a, b, ppGen: ppGen, carryIn: carryIn),
              testCarryIn: testCin);
        }
      }
      testAdderRandom(
          n, 30, (a, b, {carryIn}) => CarrySelectCompoundAdder(a, b));
    }
  });
  group('adder exhaustive', () {
    for (final testCin in [false, true]) {
      testAdderExhaustive(4, RippleCarryAdder.new, testCarryIn: testCin);
      for (final ppGen in generators) {
        testAdderExhaustive(
            4,
            (a, b, {carryIn}) =>
                ParallelPrefixAdder(a, b, ppGen: ppGen, carryIn: carryIn),
            testCarryIn: testCin);
      }
    }
    testAdderExhaustive(4, (a, b, {carryIn}) => CarrySelectCompoundAdder(a, b));
  });

  test('trivial parallel prefix adder test', () async {
    const width = 6;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);

    a.put(18);
    b.put(24);

    final adder = ParallelPrefixAdder(a, b, ppGen: BrentKung.new);

    final sum = adder.sum;
    expect(sum.value.toBigInt(), equals(BigInt.from(18 + 24)));
  });
}
