// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sign_magnitude_adder_test.dart
// Tests for the SignMagnitudeAdder.
//
// 2025 April 14
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

typedef TestSignMagnitude = ({
  bool aSign,
  int aMag,
  bool bSign,
  int bMag,
  bool sorted,
  bool carry,
  LogicValue sign,
  LogicValue mag,
  Logic? endAroundCarry
});

void checkSignMagnitudeAdder(SignMagnitudeAdder adder, LogicValue aSign,
    LogicValue aMagnitude, LogicValue bSign, LogicValue bMagnitude) {
  adder.aSign.put(aSign);
  adder.bSign.put(bSign);
  // ignore: invalid_use_of_protected_member
  adder.a.put(aMagnitude);
  // ignore: invalid_use_of_protected_member
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
    for (var i = 0; i < pow(2, n + 1); i++) {
      for (var j = 0; j < pow(2, n + 1); j++) {
        final bI = BigInt.from(i).toSigned(n + 1);
        final bJ = BigInt.from(j).toSigned(n + 1);

        final bigger = bI;
        final smaller = bJ;
        // When equal, we want the negative one first to produce 1 1...1
        if (operandsArePresorted &
            ((bI.toUnsigned(n) < bJ.toUnsigned(n)) ||
                (bI.abs() == bJ.abs() && (bI > bJ)))) {
          continue;
        } else {
          final biggerSign = bigger.abs() != bigger ? 1 : 0;
          final smallerSign = smaller.abs() != smaller ? 1 : 0;

          final biggerSignLv = LogicValue.of(biggerSign, width: 1);
          final smallerSignLv = LogicValue.of(smallerSign, width: 1);

          final biggerLv = LogicValue.of(bigger.toUnsigned(n), width: n);
          final smallerLv = LogicValue.of(smaller.toUnsigned(n), width: n);

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
    final rnd = Random(57);

    for (var i = 0; i < nSamples; i++) {
      final aa = rnd.nextLogicValue(width: width + 1);
      final av = aa.toBigInt().toSigned(width + 1);
      final bb = rnd.nextLogicValue(width: width + 1);
      final bv = bb.toBigInt().toSigned(width + 1);

      final bigger = av;
      final smaller = bv;
      // When equal, we want the negative one first to produce 1 1...1
      if (sortOperands &
          ((av.toUnsigned(width) < bv.toUnsigned(width)) ||
              (av.toUnsigned(width) == bv.toUnsigned(width) && (av > bv)))) {
        continue;
      } else {
        final biggerSign = bigger.abs() != bigger ? 1 : 0;
        final smallerSign = smaller.abs() != smaller ? 1 : 0;

        final biggerSignLv = LogicValue.of(biggerSign, width: 1);
        final smallerSignLv = LogicValue.of(smallerSign, width: 1);

        final biggerLv = LogicValue.of(bigger.toUnsigned(width), width: width);
        final smallerLv =
            LogicValue.of(smaller.toUnsigned(width), width: width);

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

  test('SignMagnitudeAdder case test', () async {
    const width = 8;
    final aSign = Logic(name: 'aSign');
    final a = Logic(name: 'a', width: width);
    final bSign = Logic(name: 'bSign');
    final b = Logic(name: 'b', width: width);

    a.put(25);
    b.put(21);

    const F = false;
    const T = true;

    //  inputs: (as amag  bs bmag sorted carry)
    // outputs: (sign sum endAround)
    final tests = <TestSignMagnitude>[];
    final cases = [
      // larger first, unordered, creates comparator and endaround hw
      ((F, 25, F, 21, F, F), (F, 46, null)),
      ((T, 25, F, 21, F, F), (T, 4, null)),
      ((F, 25, T, 21, F, F), (F, 4, null)),
      ((T, 25, T, 21, F, F), (T, 46, null)),
      // smaller first, unordered, creates comparator and endaround hw
      ((F, 21, F, 25, F, F), (F, 46, null)),
      ((T, 21, F, 25, F, F), (F, 4, null)),
      ((F, 21, T, 25, F, F), (T, 4, null)),
      ((T, 21, T, 25, F, F), (T, 46, null)),
      // larger first, ordered ignored, creates end-around hw
      ((F, 25, F, 21, T, F), (F, 46, null)),
      ((T, 25, F, 21, T, F), (T, 4, null)),
      ((F, 25, T, 21, T, F), (F, 4, null)),
      ((T, 25, T, 21, T, F), (T, 46, null)),
      // smaller first, ordered ignored, creates endaroundhw
      ((F, 21, F, 25, T, F), (F, 46, null)),
      ((T, 21, F, 25, T, F), (T, 4, null)), // sign wrong expected
      ((F, 21, T, 25, T, F), (F, 4, null)), // sign wrong expecte
      ((T, 21, T, 25, T, F), (T, 46, null)),
      // larger first, unordered, uses carryOut, adds comparator, endaround
      ((F, 25, F, 21, F, T), (F, 46, Const(0))),
      ((T, 25, F, 21, F, T), (T, 4, Const(0))),
      ((F, 25, T, 21, F, T), (F, 4, Const(0))),
      ((T, 25, T, 21, F, T), (T, 46, Const(0))),
      // larger first, ordered, uses carryOut, no extra hardware
      ((F, 25, F, 21, T, T), (F, 46, Const(0))),
      ((T, 25, F, 21, T, T), (T, 4, Const(0))),
      ((F, 25, T, 21, T, T), (F, 3, Const(1))),
      ((T, 25, T, 21, T, T), (T, 46, Const(0))),
      // smaller first, unordered, uses carryOut, adds comparator, endaround
      ((F, 21, F, 25, F, T), (F, 46, Const(0))),
      ((T, 21, F, 25, F, T), (F, 4, Const(0))),
      ((F, 21, T, 25, F, T), (T, 4, Const(0))),
      ((T, 21, T, 25, F, T), (T, 46, Const(0))),
      // smaller first, ordered, uses carryOut, no extra hardware
      ((F, 21, F, 25, T, T), (F, 46, Const(0))),
      ((T, 21, F, 25, T, T), (T, 3, Const(1))),
      ((F, 21, T, 25, T, T), (F, 4, Const(0))),
      ((T, 21, T, 25, T, T), (T, 46, Const(0))),
      // equal subtraction tests
      ((F, 21, T, 21, T, T), (F, 0, Const(0))),
      ((F, 21, T, 21, T, F), (F, 0, null)),
      ((F, 21, T, 21, F, T), (T, 0, Const(0))),
      ((F, 21, T, 21, F, F), (T, 0, null)),
    ];

    for (final t in cases) {
      final input = t.$1;
      final output = t.$2;
      tests.add((
        aSign: input.$1,
        aMag: input.$2,
        bSign: input.$3,
        bMag: input.$4,
        sorted: input.$5,
        carry: input.$6,
        sign: output.$1 ? LogicValue.one : LogicValue.zero,
        mag: LogicValue.ofInt(output.$2.abs(), width + 1),
        endAroundCarry: output.$3
      ));
    }

    for (final t in tests) {
      aSign.put(t.aSign);
      a.put(t.aMag);
      bSign.put(t.bSign);
      b.put(t.bMag);

      final adder = SignMagnitudeAdder(aSign, a, bSign, b,
          largestMagnitudeFirst: t.sorted, outputEndAroundCarry: t.carry);
      expect(adder.sign.value, equals(t.sign), reason: 'sign mismatch');
      expect(adder.sum.value, equals(t.mag), reason: 'mag mismatch');
      expect(adder.endAroundCarry == null, equals(t.endAroundCarry == null),
          reason: 'endAroundCarry null miss');
      if (adder.endAroundCarry != null) {
        if (t.endAroundCarry != null) {
          expect(adder.endAroundCarry!.value, equals(t.endAroundCarry!.value),
              reason: 'endAroundCarry value miss');
        }
      }
    }
  });

  test('SignMagnitudeAdder: trivial test', () async {
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

  test('SignMagnitudeDualAdder: trivial test', () async {
    const width = 64;
    final aSign = Logic(name: 'aSign');
    final a = Logic(name: 'a', width: width);
    final bSign = Logic(name: 'bSign');
    final b = Logic(name: 'b', width: width);

    aSign.put(0);
    a.put(8);
    bSign.put(1);
    b.put(9);

    final adder = SignMagnitudeAdder(aSign, a, bSign, b);
    final sum = adder.sum;
    expect(sum.value.toBigInt(), equals(BigInt.from(1)));
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

  group('SignMagnitudeAdder: random', () {
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

  group('SignMagnitudeAdder: exhaustive', () {
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

  test('SignMagnitudeDualAdder: singleton', () {
    const n = 16;
    const i = 26;
    const j = 8;
    final bI = BigInt.from(i).toSigned(n + 1);
    final bJ = BigInt.from(j).toSigned(n + 1);
    final bigger = bI;
    final smaller = bJ;
    const biggerSign = 0;
    const smallerSign = 1;
    final aSignV = LogicValue.of(biggerSign, width: 1);
    final bSignV = LogicValue.of(smallerSign, width: 1);

    final av = LogicValue.of(bigger.abs(), width: n) << 4;
    final bv = (LogicValue.of(smaller.abs(), width: n) << 4) |
        LogicValue.of(2, width: n);

    final aSign = Logic();
    final a = Logic(width: n);
    final bSign = Logic();
    final b = Logic(width: n);
    aSign.put(aSignV);
    bSign.put(bSignV);
    a.put(av);
    b.put(bv);

    final adder = SignMagnitudeDualAdder(aSign, a, bSign, b);
    expect(adder.sum.value.toInt(), equals(286));
  });
}
