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

void checkSignMagnitudeAdder(SignMagnitudeAdder adder, LogicValue aSign,
    LogicValue aMagnitude, LogicValue bSign, LogicValue bMagnitude) {
  adder.aSign.put(aSign);
  adder.bSign.put(bSign);
  adder.a.put(aMagnitude);
  adder.b.put(bMagnitude);

  final computedVal = (adder.sign.value == LogicValue.one)
      ? -adder.sum.value.toBigInt()
      : adder.sum.value.toBigInt();

  final aValue = (aSign == LogicValue.one)
      ? -aMagnitude.toBigInt()
      : aMagnitude.toBigInt();
  final bValue = (bSign == LogicValue.one)
      ? -bMagnitude.toBigInt()
      : bMagnitude.toBigInt();
  final expectSign = (aValue + bValue).sign;
  final expectedMag = (aValue + bValue).abs();

  final expectVal = expectSign == -1 ? -expectedMag : expectedMag;
  expect(computedVal, equals(expectVal));
}

void testExhaustiveSignMagnitude(
    int n, Adder Function(Logic a, Logic b, {Logic? carryIn}) fn,
    {bool operandsArePresorted = true}) {
  final aSign = Logic(name: 'aSign');
  final a = Logic(name: 'a', width: n);
  final bSign = Logic(name: 'bSign');
  final b = Logic(name: 'b', width: n);

  final adder = SignMagnitudeAdder(aSign, a, bSign, b, fn,
      largestMagnitudeFirst: operandsArePresorted);
  test(
      'exhaustive Sign Magnitude: '
      '${adder.name}_W${a.width}_N$operandsArePresorted', () {
    for (var i = 0; i < pow(2, n); i++) {
      for (var j = 0; j < pow(2, n); j++) {
        final bI = BigInt.from(i).toSigned(n);
        final bJ = BigInt.from(j).toSigned(n);

        final bigger = bI;
        final smaller = bJ;
        // When equal, we want the negative one first to produce 1 1...1
        if (operandsArePresorted &
            ((bI.abs() < bJ.abs()) || (bI.abs() == bJ.abs() && (bI > bJ)))) {
          continue;
        } else {
          final biggerSign = bigger.abs() != bigger ? 1 : 0;
          final smallerSign = smaller.abs() != smaller ? 1 : 0;

          final biggerSignLv = LogicValue.of(biggerSign, width: 1);
          final smallerSignLv = LogicValue.of(smallerSign, width: 1);

          final biggerLv = LogicValue.of(bigger.abs(), width: n);
          final smallerLv = LogicValue.of(smaller.abs(), width: n);

          checkSignMagnitudeAdder(
              adder, biggerSignLv, biggerLv, smallerSignLv, smallerLv);
        }
      }
    }
  });
}

void testRandomSignMagnitude(int width, int nSamples,
    Adder Function(Logic a, Logic b, {Logic? carryIn}) fn,
    {bool sortOperands = true}) {
  final aSign = Logic(name: 'aSign');
  final a = Logic(name: 'a', width: width);
  final bSign = Logic(name: 'bSign');
  final b = Logic(name: 'b', width: width);

  final adder = SignMagnitudeAdder(aSign, a, bSign, b, fn,
      largestMagnitudeFirst: sortOperands);
  test('random Sign Magnitude: ${adder.name}_W${a.width}_N$sortOperands',
      () async {
    await adder.build();

    for (var i = 0; i < nSamples; i++) {
      final aa = Random().nextLogicValue(width: width);
      final av = aa.toBigInt().toSigned(width);
      final bb = Random().nextLogicValue(width: width);
      final bv = bb.toBigInt().toSigned(width);

      final bigger = av;
      final smaller = bv;
      // When equal, we want the negative one first to produce 1 1...1
      if (sortOperands &
          ((av.abs() < bv.abs()) || (av.abs() == bv.abs() && (av > bv)))) {
        continue;
      } else {
        final biggerSign = bigger.abs() != bigger ? 1 : 0;
        final smallerSign = smaller.abs() != smaller ? 1 : 0;

        final biggerSignLv = LogicValue.of(biggerSign, width: 1);
        final smallerSignLv = LogicValue.of(smallerSign, width: 1);

        final biggerLv = LogicValue.of(bigger.abs(), width: width);
        final smallerLv = LogicValue.of(smaller.abs(), width: width);

        checkSignMagnitudeAdder(
            adder, biggerSignLv, biggerLv, smallerSignLv, smallerLv);
      }
    }
  });
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

  group('SignMagnitude random', () {
    for (final ppGen in generators) {
      testRandomSignMagnitude(4, 30, RippleCarryAdder.new);
      testRandomSignMagnitude(4, 30, RippleCarryAdder.new, sortOperands: false);
      testRandomSignMagnitude(
          4, 30, (a, b, {carryIn}) => ParallelPrefixAdder(a, b, ppGen: ppGen));
      testRandomSignMagnitude(
          4, 30, (a, b, {carryIn}) => ParallelPrefixAdder(a, b, ppGen: ppGen),
          sortOperands: false);
    }
  });
  group('SignMagnitude exhaustive', () {
    for (final ppGen in generators) {
      testExhaustiveSignMagnitude(4, RippleCarryAdder.new);
      testExhaustiveSignMagnitude(4, RippleCarryAdder.new,
          operandsArePresorted: false);
      testExhaustiveSignMagnitude(
          4, (a, b, {carryIn}) => ParallelPrefixAdder(a, b, ppGen: ppGen));
      testExhaustiveSignMagnitude(
          4, (a, b, {carryIn}) => ParallelPrefixAdder(a, b, ppGen: ppGen),
          operandsArePresorted: false);
    }
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

    final adder = SignMagnitudeAdder(aSign, a, bSign, b, RippleCarryAdder.new,
        largestMagnitudeFirst: true);

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
          final carry = Logic();
          final adder =
              OnesComplementAdder(a, b, carryOut: carry, subtract: subtract);
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
        final carry = Logic();
        final adder = CarrySelectOnesComplementCompoundAdder(a, b,
            subtract: subtract, carryOut: carry);
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
          final carry = Logic();
          final adder = OnesComplementAdder(a, b,
              subtractIn: subtractIn,
              carryOut: carry,
              adderGen: RippleCarryAdder.new);
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
    // print('${adder.sign.value.toInt()} ${sum.value.toInt()}');
    expect(-sum.value.toBigInt(), equals(BigInt.from(6 - 24)));
  });
}
