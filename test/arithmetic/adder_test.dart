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

  test('singleton', () {
    const width = 8;
    final av = LogicValue.ofInt(-6, width);
    final bv = LogicValue.ofInt(12, width);

    final cv = LogicValue.ofInt(0, width);
    final a = Logic(width: width);
    final b = Logic(width: width);
    final c = Logic(width: width);
    a.put(av);
    b.put(bv);
    c.put(cv);

    final adder = RippleCarryAdder(a, b);
    checkAdder(adder, av, bv, cv);
  });

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
      for (final adder in adders) {
        testAdderExhaustive(4, adder, testCarryIn: testCin);
      }
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

  test('trivial sign magnitude adder test', () async {
    const width = 6;
    final aSign = Logic(name: 'aSign');
    final a = Logic(name: 'a', width: width);
    final bSign = Logic(name: 'bSign');
    final b = Logic(name: 'b', width: width);

    aSign.put(0);
    a.put(24);
    bSign.put(1);
    b.put(18);

    final adder =
        SignMagnitudeAdder(aSign, a, bSign, b, largestMagnitudeFirst: true);

    final sum = adder.sum;
    expect(sum.value.toBigInt(), equals(BigInt.from(24 - 18)));
    aSign.put(1);
    a.put(24);
    bSign.put(0);
    b.put(18);

    expect(-sum.value.toBigInt(), equals(BigInt.from(18 - 24)));
  });

  test('ones complement adder: exhaustive with boolean subtract', () {
    const width = 2;
    final a = Logic(width: width);
    final b = Logic(width: width);

    for (final subtract in [false, true]) {
      for (var av = 0; av < pow(2, width); av++) {
        for (var bv = 0; bv < pow(2, width); bv++) {
          a.put(av);
          b.put(bv);
          final adder = OnesComplementAdder(a, b,
              outputEndAroundCarry: true, subtract: subtract);

          final carry = adder.endAroundCarry!;
          final mag = adder.sum.value.toInt() +
              (subtract ? (carry.value.isZero ? 0 : 1) : 0);
          final out = (adder.sign.value.toInt() == 1 ? -mag : mag);

          final expected = [if (subtract) av - bv else av + bv].first;
          expect(out, equals(expected));
        }
      }
    }
  });

  test('ones complement adder: random with boolean subtract', () {
    const width = 4;
    final a = Logic(width: width);
    final b = Logic(width: width);
    const nSamples = 100;

    for (var i = 0; i < nSamples; i++) {
      final av = Random().nextLogicValue(width: width);
      final bv = Random().nextLogicValue(width: width);

      for (final subtract in [true]) {
        a.put(av);
        b.put(bv);
        final adder = CarrySelectOnesComplementCompoundAdder(a, b,
            subtract: subtract, outputCarryOut: true);
        final carry = adder.carryOut!;
        final mag = adder.sum.value.toInt() +
            (subtract ? (carry.value.isZero ? 0 : 1) : 0);
        final out = (adder.sign.value.toBool() ? -mag : mag);

        // Use integer math to avoid twos-complement of av+bv
        final expected = [
          if (subtract) av.toInt() - bv.toInt() else av.toInt() + bv.toInt()
        ].first;
        expect(out, equals(expected), reason: '''
      a=$av ${av.toInt()}
      b=$bv ${bv.toInt()}
      sum: 2s= ${(av + bv).toInt()} 1s=${av.toInt() + bv.toInt()}
      output=$out
      expected=$expected
      ''');
      }
    }
  });

  test('ones complement subtractor', () {
    const width = 5;
    final a = Logic(width: width);
    final b = Logic(width: width);

    const subtract = true;
    const av = 1;
    const bv = 6;

    a.put(av);
    b.put(bv);
    final adder = OnesComplementAdder(a, b, subtract: subtract);
    expect(adder.sum.value.toInt(), equals(bv - av));
    expect(adder.sign.value, LogicValue.one);
  });

  test('ones complement with Logic subtract', () {
    const width = 2;
    final a = Logic(width: width);
    final b = Logic(width: width);

    for (final subtractIn in [Const(0), Const(1)]) {
      for (var av = 0; av < pow(2, width); av++) {
        for (var bv = 0; bv < pow(2, width); bv++) {
          a.put(av);
          b.put(bv);
          final adder = OnesComplementAdder(a, b,
              subtractIn: subtractIn,
              // endAroundCarry: carry,
              outputEndAroundCarry: true,
              adderGen: RippleCarryAdder.new);
          final carry = adder.endAroundCarry!;
          final mag = adder.sum.value.toInt() +
              (subtractIn.value == LogicValue.one
                  ? (carry.value.isZero ? 0 : 1)
                  : 0);
          final out = (adder.sign.value.toInt() == 1 ? -mag : mag);

          final expected = [
            if (subtractIn.value == LogicValue.one) av - bv else av + bv
          ].first;
          expect(out, equals(expected));
        }
      }
    }
  });

  test('trivial sign magnitude with onescomplement adder test', () async {
    const width = 8;
    final aSign = Logic(name: 'aSign');
    final a = Logic(name: 'a', width: width);
    final bSign = Logic(name: 'bSign');
    final b = Logic(name: 'b', width: width);

    aSign.put(1);
    a.put(24);
    b.put(6);
    bSign.put(0);

    final adder = OnesComplementAdder(a, b,
        adderGen: RippleCarryAdder.new, subtract: true);

    final sum = adder.sum;
    expect(-sum.value.toBigInt(), equals(BigInt.from(6 - 24)));
  });
}
