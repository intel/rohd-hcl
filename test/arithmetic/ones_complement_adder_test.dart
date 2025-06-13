// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ones_complement_adder_test.dart
// Tests for the OnesComplementAdder.
//
// 2025 Mar 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

typedef TestOnesComplement = ({
  int av,
  int bv,
  bool subtract,
  bool carry,
  LogicValue sign,
  LogicValue sum,
  Logic? endAroundCarry
});

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
      (25, 21, false, false, false, 46, null),
      (25, 21, false, true, false, 46, Const(0)),
      (25, 21, true, false, false, 4, null),
      (25, 21, true, true, false, 3, Const(1)),
      (21, 25, false, false, false, 46, null),
      (21, 25, true, false, true, 4, null),
      (21, 25, true, true, true, 4, Const(0)),
      (21, 21, true, true, true, 0, Const(0)),
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
          generateEndAroundCarry: t.carry, subtract: t.subtract);
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

  test('OnesComplementAdder: exhaustive with boolean subtract', () {
    const width = 2;
    final a = Logic(width: width);
    final b = Logic(width: width);

    for (final subtract in [false, true]) {
      for (var av = 0; av < pow(2, width); av++) {
        for (var bv = 0; bv < pow(2, width); bv++) {
          a.put(av);
          b.put(bv);
          final adder = OnesComplementAdder(a, b,
              generateEndAroundCarry: true, subtract: subtract);
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

  test('OnesComplementAdder: random with boolean subtract', () {
    const width = 16;
    final a = Logic(width: width);
    final b = Logic(width: width);
    const nSamples = 10;

    final rnd = Random(57);

    for (var i = 0; i < nSamples; i++) {
      final av = rnd.nextLogicValue(width: width);
      final bv = rnd.nextLogicValue(width: width);

      for (final subtract in [false, true]) {
        a.put(av);
        b.put(bv);
        final adder = CarrySelectOnesComplementCompoundAdder(a, b,
            subtract: subtract, generateCarryOut: true);
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

  test('OnesComplementAdder as subtractor', () {
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

  test('OnesComplementAdder with Logic subtract', () {
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
              generateEndAroundCarry: true,
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

  test('OnesComplementAdder: trivial test', () async {
    const width = 8;
    final aSign = Logic(name: 'aSign');
    final a = Logic(name: 'a', width: width);
    final bSign = Logic(name: 'bSign');
    final b = Logic(name: 'b', width: width);

    aSign.put(1);
    a.put(0);
    bSign.put(0);
    b.put(1);

    final adder = OnesComplementAdder(a, b, adderGen: RippleCarryAdder.new);

    final sum = adder.sum;
    expect(sum.value.toBigInt(), equals(BigInt.from(1)));
    expect(adder.sign.value.toBool(), equals(false));
  });
}
