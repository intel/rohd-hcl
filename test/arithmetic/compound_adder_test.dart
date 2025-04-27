// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// compound_adder_test.dart
// Tests for the Compound Adder interface.
//
// 2024 September 23
// Author: Anton Sorokin <anton.a.sorokin@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void checkCompoundAdder(CompoundAdder adder, LogicValue av, LogicValue bv) {
  final aB = av.toBigInt();
  final bB = bv.toBigInt();
  // ignore: invalid_use_of_protected_member
  adder.a.put(av);
  // ignore: invalid_use_of_protected_member
  adder.b.put(bv);

  expect(adder.sum.value.toBigInt(), equals(aB + bB));
  expect(adder.sumP1.value.toBigInt(), equals(aB + bB + BigInt.one));
}

void testExhaustive(int n, CompoundAdder Function(Logic a, Logic b) fn) {
  final a = Logic(name: 'a', width: n);
  final b = Logic(name: 'b', width: n);

  final mod = fn(a, b);
  test(
      'exhaustive: '
      '${fn.call(a, b).definitionName}', () async {
    await mod.build();

    for (var aa = 0; aa < (1 << n); ++aa) {
      for (var bb = 0; bb < (1 << n); ++bb) {
        final av = LogicValue.of(BigInt.from(aa), width: n);
        final bv = LogicValue.of(BigInt.from(bb), width: n);
        checkCompoundAdder(mod, av, bv);
      }
    }
  });
}

typedef TestCarrySelectOnesComplementCompoundAdder = ({
  int aMag,
  int bMag,
  Logic? subtractIn,
  bool carry,
  bool carryP1,
  LogicValue sign,
  LogicValue mag,
  Logic? endAroundCarry,
  LogicValue signP1,
  LogicValue magP1,
  Logic? endAroundCarryP1
});

void main() {
  tearDown(() async {
    await Simulator.reset();
  });
  group('exhaustive', () {
    testExhaustive(4, TrivialCompoundAdder.new);
    testExhaustive(
        8,
        (a, b) => CarrySelectCompoundAdder(a, b,
            widthGen:
                CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit(4)));
    testExhaustive(
        8,
        (a, b) => CarrySelectCompoundAdder(a, b,
            adderGen: OnesComplementAdder.new,
            widthGen:
                CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit(4)));
  });

  test('trivial compound adder test', () async {
    const width = 6;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);

    a.put(18);
    b.put(24);

    final adder = CarrySelectCompoundAdder(a, b,
        widthGen: CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit(3));

    final sum = adder.sum;
    final sum1 = adder.sumP1;
    expect(sum.value.toBigInt(), equals(BigInt.from(18 + 24)));
    expect(sum1.value.toBigInt(), equals(BigInt.from(18 + 24 + 1)));
  });

  Adder defaultAdder(Logic a, Logic b,
          {Logic? carryIn, Logic? subtractIn, String name = ''}) =>
      ParallelPrefixAdder(a, b, carryIn: carryIn, name: name);
  test('CarrySelectAdder: random inputs', () async {
    final a = Logic(name: 'a', width: 10);
    final b = Logic(name: 'b', width: 10);

    final adder = CarrySelectCompoundAdder(a, b,
        adderGen: defaultAdder,
        widthGen: CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit(4));
    await adder.build();

    final rand = Random(5);
    for (var i = 0; i < 100; i++) {
      final randA = rand.nextInt(1 << a.width);
      final randB = rand.nextInt(1 << a.width);
      a.put(randA);
      b.put(randB);
      expect(adder.sum.value.toInt(), equals(randA + randB));
      expect(adder.sumP1.value.toInt(), equals(randA + randB + 1));
    }
  });
  test('CarrySelectAdder ones complement: basic cases', () {
    const width = 8;
    final a = Logic(width: width);
    final b = Logic(width: width);

    for (final (ai, bi, doSubtract) in [
      (36, 66, false),
      (36, 66, true),
      (1, 1, true),
      (1, 2, true),
      (0, 0, true),
      (0, 0, false),
      (0, 1, true),
      (1, 0, true),
      (66, 36, true),
      (255, 255, false),
      (255, 255, true)
    ]) {
      final av = LogicValue.ofInt(ai, width);
      final bv = LogicValue.ofInt(bi, width);
      a.put(av);
      b.put(bv);
      final adder = CarrySelectOnesComplementCompoundAdder(a, b,
          subtract: doSubtract,
          generateCarryOut: true,
          generateCarryOutP1: true,
          widthGen: CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit(4));

      final refAdder = OnesComplementAdder(a, b,
          generateEndAroundCarry: true,
          subtractIn: doSubtract ? Const(1) : Const(0));

      final expectedVal = doSubtract ? ai - bi : ai + bi;
      final expectedValP1 = expectedVal + 1;
      final expectedSign = doSubtract & (ai <= bi);

      final expectedMag =
          expectedVal.abs() - (doSubtract & (expectedVal > 0) ? 1 : 0);
      final expectedMagP1 =
          expectedValP1.abs() - (doSubtract & (expectedValP1 > 0) ? 1 : 0);

      final increment = doSubtract ? adder.carryOut!.value.toInt() : 0;
      final incrementP1 = doSubtract ? adder.carryOutP1!.value.toInt() : 0;
      expect(expectedMag + increment, equals(expectedVal.abs()));
      expect(expectedMagP1 + incrementP1, equals(expectedValP1.abs()));

      final expectedSignP1 = (expectedMag > 0) & expectedSign;
      expect(adder.sign.value.toBool(), equals(expectedSign));
      expect(adder.sum.value.toInt(), equals(expectedMag));
      expect(refAdder.sign.value.toBool(), equals(expectedSign));
      expect(refAdder.sum.value.toInt(), equals(expectedMag));
      expect(adder.sumP1.value.toInt(), equals(expectedMagP1));
      expect(adder.signP1.value.toBool(), equals(expectedSignP1));
    }
  });

  test('CarrySelectOnesComplementCompoundAdder: exhaustive ', () {
    const width = 6;
    final a = Logic(width: width);
    final b = Logic(width: width);

    for (final useLogic in [null, Const(0), Const(1)]) {
      for (final subtract in (useLogic == null) ? [false, true] : [false]) {
        final doSubtract =
            (useLogic == null) ? subtract : useLogic.value.toBool();
        final adder = CarrySelectOnesComplementCompoundAdder(a, b,
            subtractIn: useLogic,
            subtract: subtract,
            generateCarryOut: true,
            generateCarryOutP1: true,
            widthGen:
                CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit(4));
        final refAdder = OnesComplementAdder(a, b,
            generateEndAroundCarry: true,
            subtractIn: useLogic,
            subtract: subtract);
        for (var ai = 0; ai < pow(2, width); ai++) {
          for (var bi = 0; bi < pow(2, width); bi++) {
            final av = LogicValue.ofInt(ai, width);
            final bv = LogicValue.ofInt(bi, width);
            a.put(av);
            b.put(bv);

            final expectedVal = doSubtract ? ai - bi : ai + bi;
            final expectedValP1 = expectedVal + 1;
            final expectedSign = doSubtract & (ai <= bi);

            final expectedMag =
                expectedVal.abs() - (doSubtract & (expectedVal > 0) ? 1 : 0);
            final expectedMagP1 = expectedValP1.abs() -
                (doSubtract & (expectedValP1 > 0) ? 1 : 0);

            final increment = doSubtract ? adder.carryOut!.value.toInt() : 0;
            final incrementP1 =
                doSubtract ? adder.carryOutP1!.value.toInt() : 0;
            expect(expectedMag + increment, equals(expectedVal.abs()));
            expect(expectedMagP1 + incrementP1, equals(expectedValP1.abs()));

            final expectedSignP1 = (expectedMag > 0) & expectedSign;
            expect(adder.sign.value.toBool(), equals(expectedSign));
            expect(adder.sum.value.toInt(), equals(expectedMag));
            expect(refAdder.sign.value.toBool(), equals(expectedSign));
            expect(refAdder.sum.value.toInt(), equals(expectedMag));
            expect(adder.sumP1.value.toInt(), equals(expectedMagP1));
            expect(adder.signP1.value.toBool(), equals(expectedSignP1));
          }
        }
      }
    }
  });

  test('CarrySelectOnesComplementCompoundAdder: singleton', () {
    const n = 8;
    const i = 2;
    const j = 2;

    final av = LogicValue.of(i, width: n);
    final bv = LogicValue.of(j, width: n);

    final a = Logic(width: n);
    final b = Logic(width: n);
    a.put(av);
    b.put(bv);

    final adder = CarrySelectOnesComplementCompoundAdder(a, b);
    expect(adder.sum.value.toInt(), equals(4));
  });

  test('CarrySelectOnesComplementCompoundAdder case test', () async {
    const width = 8;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);

    a.put(25);
    b.put(21);

    const F = false;
    const T = true;

    // inputs: (amag bmag subtract carry carryP1)
    // out1:(sign sum eac)
    // out2: (signP1 sumP1 eacP1)
    final newCases = [
      ((25, 21, null, F, F), (F, 46, null), (F, 47, null)),
      ((25, 21, Const(0), F, F), (F, 46, null), (F, 47, null)),
      ((25, 21, Const(1), F, F), (F, 4, null), (F, 5, null)),
      ((21, 25, Const(1), F, F), (T, 4, null), (T, 3, null)),
      // Cancellation
      ((21, 21, Const(1), F, F), (T, 0, null), (F, 1, null)),
      ((21, 22, Const(1), F, F), (T, 1, null), (T, 0, null)),
      ((21, 23, Const(1), F, F), (T, 2, null), (T, 1, null)),
      // carry
      ((25, 21, Const(1), T, F), (F, 3, Const(1)), (F, 5, null)),
      ((25, 21, Const(1), T, T), (F, 3, Const(1)), (F, 4, Const(1))),
      ((25, 24, Const(1), T, T), (F, 0, Const(1)), (F, 1, Const(1))),
      ((25, 25, Const(1), T, T), (T, 0, Const(0)), (F, 0, Const(1))),
      ((25, 26, Const(1), T, T), (T, 1, Const(0)), (T, 0, Const(0))),
      ((25, 27, Const(1), T, T), (T, 2, Const(0)), (T, 1, Const(0))),
      // odd carry
      ((25, 21, Const(1), F, T), (F, 4, null), (F, 4, Const(1))),
      ((21, 25, Const(1), F, T), (T, 4, null), (T, 3, Const(0))),
    ];
    final tests = <TestCarrySelectOnesComplementCompoundAdder>[];
    for (final t in newCases) {
      final inputs = t.$1;
      final out1 = t.$2;
      final out2 = t.$3;
      tests.add((
        aMag: inputs.$1,
        bMag: inputs.$2,
        subtractIn: inputs.$3,
        carry: inputs.$4,
        carryP1: inputs.$5,
        sign: out1.$1 ? LogicValue.one : LogicValue.zero,
        mag: LogicValue.ofInt(out1.$2.abs(), width + 1),
        endAroundCarry: out1.$3,
        signP1: out2.$1 ? LogicValue.one : LogicValue.zero,
        magP1: LogicValue.ofInt(out2.$2.abs(), width + 1),
        endAroundCarryP1: out2.$3,
      ));
    }
    for (final t in tests) {
      a.put(t.aMag);
      b.put(t.bMag);

      final adder = CarrySelectOnesComplementCompoundAdder(a, b,
          subtractIn: t.subtractIn,
          generateCarryOut: t.carry,
          generateCarryOutP1: t.carryP1);

      expect(adder.sign.value, equals(t.sign), reason: 'sign mismatch');
      expect(adder.sum.value, equals(t.mag), reason: 'mag mismatch');
      expect(adder.signP1.value, equals(t.signP1), reason: 'signP1 mismatch');
      expect(adder.sumP1.value, equals(t.magP1), reason: 'magP1 mismatch');

      expect(adder.carryOut == null, equals(t.endAroundCarry == null),
          reason: 'endAroundCarry null miss');
      if (adder.carryOut != null) {
        if (t.endAroundCarry != null) {
          expect(adder.carryOut!.value, equals(t.endAroundCarry!.value),
              reason: 'endAroundCarry value miss');
        }
      }
      expect(adder.carryOutP1 == null, equals(t.endAroundCarryP1 == null),
          reason: 'endAroundCarryP1 null miss');
      if (adder.carryOutP1 != null) {
        if (t.endAroundCarryP1 != null) {
          expect(adder.carryOutP1!.value, equals(t.endAroundCarryP1!.value),
              reason: 'endAroundCarryP1 value miss');
        }
      }
    }
  });
}
