// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ones_complement_adder_test.dart
// Tests for the OnesComplementAdder and SignMagnitudeAdder.
//
// 2025 Mar 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

// ignore_for_file: invalid_use_of_protected_member

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

typedef TestOnesComplement = ({
  int av,
  int bv,
  bool subtract,
  Logic? carry,
  LogicValue sign,
  LogicValue sum,
  Logic? endAroundCarry
});

typedef TestSignMagnitude = ({
  bool aSign,
  int aMag,
  bool bSign,
  int bMag,
  bool sorted,
  Logic? carry,
  LogicValue sign,
  LogicValue mag,
  Logic? endAroundCarry
});

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

  final adder = SignMagnitudeAdder(aSign, a, bSign, b,
      adderGen: fn, largestMagnitudeFirst: operandsArePresorted);
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

  final adder = SignMagnitudeAdder(aSign, a, bSign, b,
      adderGen: fn, largestMagnitudeFirst: sortOperands);
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

  test('OnesComplementAdder case test', () async {
    const width = 8;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);

    //   inputs  | expected outputs
    // (av  bv  subt  carry  | sign  sum endAround)
    final tests = <TestOnesComplement>[];
    final cases = [
      (25, 21, false, null, false, 46, null),
      (25, 21, false, Logic(), false, 46, Const(0)),
      (25, 21, true, null, false, 4, null),
      (25, 21, true, Logic(), false, 3, Const(1)),
      (21, 25, false, null, false, 46, null),
      (21, 25, true, null, true, 4, null),
      (21, 25, true, Logic(), true, 4, Const(0)),
    ];

    for (final t in cases) {
      tests.add((
        av: t.$1,
        bv: t.$2,
        subtract: t.$3,
        carry: t.$4,
        sign: t.$5 ? LogicValue.one : LogicValue.zero,
        sum: LogicValue.ofInt(t.$6, width + 1),
        endAroundCarry: t.$7,
      ));
    }

    for (final t in tests) {
      a.put(t.av);
      b.put(t.bv);

      final adder = OnesComplementAdder(a, b,
          endAroundCarry: t.carry, subtract: t.subtract);
      expect(adder.sign.value, equals(t.sign));
      expect(adder.sum.value, equals(t.sum));
      expect(adder.endAroundCarry == null, equals(t.endAroundCarry == null));
      if (adder.endAroundCarry != null) {
        if (t.endAroundCarry != null) {
          expect(adder.endAroundCarry!.value, equals(t.endAroundCarry!.value));
        }
      }
    }
  });

  test('SignMagnitudeAdder case test', () async {
    const width = 8;
    final aSign = Logic(name: 'aSign');
    final a = Logic(name: 'a', width: width);
    final bSign = Logic(name: 'bSign');
    final b = Logic(name: 'b', width: width);

    a.put(25);
    b.put(21);

    //   inputs  | expected outputs
    // (as amag  bs bmag sorted carry | sum endAround)
    final tests = <TestSignMagnitude>[];
    final cases = [
      // larger first, unordered, creates comparator and endaround hw
      (false, 25, false, 21, false, null, 46, null),
      (true, 25, false, 21, false, null, -4, null),
      (false, 25, true, 21, false, null, 4, null),
      (true, 25, true, 21, false, null, -46, null),
      // smaller first, unordered, creates comparator and endaround hw
      (false, 21, false, 25, false, null, 46, null),
      (true, 21, false, 25, false, null, 4, null),
      (false, 21, true, 25, false, null, -4, null),
      (true, 21, true, 25, false, null, -46, null),
      // larger first, ordered ignored, creates end-around hw
      (false, 25, false, 21, true, null, 46, null),
      (true, 25, false, 21, true, null, -4, null),
      (false, 25, true, 21, true, null, 4, null),
      (true, 25, true, 21, true, null, -46, null),
      // smaller first, ordered ignored, creates endaroundhw
      (false, 21, false, 25, true, null, 46, null),
      (true, 21, false, 25, true, null, -4, null), // sign is wrong as expected
      (false, 21, true, 25, true, null, 4, null), // sign is wrong as expected
      (true, 21, true, 25, true, null, -46, null),
      // larger first, unordered, uses carryOut, adds comparator, endaround
      (false, 25, false, 21, false, Logic(), 46, Const(0)),
      (true, 25, false, 21, false, Logic(), -4, Const(0)),
      (false, 25, true, 21, false, Logic(), 4, Const(0)),
      (true, 25, true, 21, false, Logic(), -46, Const(0)),
      // larger first, ordered, uses carryOut, no extra hardware
      (false, 25, false, 21, true, Logic(), 46, Const(0)),
      (true, 25, false, 21, true, Logic(), -4, Const(0)),
      (false, 25, true, 21, true, Logic(), 3, Const(1)),
      (true, 25, true, 21, true, Logic(), -46, Const(0)),
      // smaller first, unordered, uses carryOut, adds comparator, endaround
      (false, 21, false, 25, false, Logic(), 46, Const(0)),
      (true, 21, false, 25, false, Logic(), 4, Const(0)),
      (false, 21, true, 25, false, Logic(), -4, Const(0)),
      (true, 21, true, 25, false, Logic(), -46, Const(0)),
      // smaller first, ordered, uses carryOut, no extra hardware
      (false, 21, false, 25, true, Logic(), 46, Const(0)),
      (true, 21, false, 25, true, Logic(), -3, Const(1)),
      (false, 21, true, 25, true, Logic(), 4, Const(0)),
      (true, 21, true, 25, true, Logic(), -46, Const(0)),
    ];

    for (final t in cases) {
      tests.add((
        aSign: t.$1,
        aMag: t.$2,
        bSign: t.$3,
        bMag: t.$4,
        sorted: t.$5,
        carry: t.$6,
        sign: t.$7 < 0 ? LogicValue.one : LogicValue.zero,
        mag: LogicValue.ofInt(t.$7.abs(), width + 1),
        endAroundCarry: t.$8
      ));
    }

    for (final t in tests) {
      aSign.put(t.aSign);
      a.put(t.aMag);
      bSign.put(t.bSign);
      b.put(t.bMag);

      final adder = SignMagnitudeAdder(aSign, a, bSign, b,
          largestMagnitudeFirst: t.sorted, endAroundCarry: t.carry);
      // expect(adder.sign.value, equals(t.sign));
      expect(adder.sum.value, equals(t.mag));
      expect(adder.endAroundCarry == null, equals(t.endAroundCarry == null));
      if (adder.endAroundCarry != null) {
        if (t.endAroundCarry != null) {
          expect(adder.endAroundCarry!.value, equals(t.endAroundCarry!.value));
        }
      }
    }
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
          final adder = OnesComplementAdder(a, b,
              endAroundCarry: carry, subtract: subtract);
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
    const width = 16;
    final a = Logic(width: width);
    final b = Logic(width: width);
    const nSamples = 10;

    final rnd = Random(57);

    for (var i = 0; i < nSamples; i++) {
      final av = rnd.nextLogicValue(width: width);
      final bv = rnd.nextLogicValue(width: width);

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
              endAroundCarry: carry,
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
    expect(-sum.value.toBigInt(), equals(BigInt.from(6 - 24)));
  });

  test('trivial sign magnitude adder test', () async {
    const width = 4;
    final aSign = Logic(name: 'aSign');
    final a = Logic(name: 'a', width: width);
    final bSign = Logic(name: 'bSign');
    final b = Logic(name: 'b', width: width);

    aSign.put(1);
    a.put(8);
    bSign.put(1);
    b.put(8);

    final adder =
        SignMagnitudeAdder(aSign, a, bSign, b, largestMagnitudeFirst: true);

    final sum = adder.sum;
    expect(sum.value.toBigInt(), equals(BigInt.from(16)));
  });

  test('SignMagnitudeAdder: four case test', () async {
    const width = 6;
    final aSign = Logic(name: 'aSign');
    final a = Logic(name: 'a', width: width);
    final bSign = Logic(name: 'bSign');
    final b = Logic(name: 'b', width: width);

    final cases = [
      [(0, 24), (0, 20)],
      [(1, 24), (0, 20)],
      [(0, 24), (1, 20)],
      [(1, 24), (1, 20)]
    ];

    for (final c in cases) {
      aSign.put(c[0].$1);
      a.put(c[0].$2);
      bSign.put(c[1].$1);
      b.put(c[1].$2);

      final adder = SignMagnitudeAdder(aSign, a, bSign, b,
          adderGen: RippleCarryAdder.new, largestMagnitudeFirst: true);
      expect(adder.sum.value.toInt(), equals(c[0].$1 == c[1].$1 ? 44 : 4));
    }
  });

  final generators = [Ripple.new, Sklansky.new, KoggeStone.new, BrentKung.new];

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
    testExhaustiveSignMagnitude(4, RippleCarryAdder.new);
    testExhaustiveSignMagnitude(4, RippleCarryAdder.new,
        operandsArePresorted: false);
    for (final ppGen in generators) {
      testExhaustiveSignMagnitude(
          4, (a, b, {carryIn}) => ParallelPrefixAdder(a, b, ppGen: ppGen));
      testExhaustiveSignMagnitude(
          4, (a, b, {carryIn}) => ParallelPrefixAdder(a, b, ppGen: ppGen),
          operandsArePresorted: false);
    }
  });
}
