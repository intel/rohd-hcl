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
      final carryOut = Logic();
      final carryOutP1 = Logic();
      final adder = CarrySelectOnesComplementCompoundAdder(a, b,
          subtract: doSubtract,
          carryOut: carryOut,
          carryOutP1: carryOutP1,
          widthGen: CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit(4));

      final refCarry = Logic();
      final refAdder = OnesComplementAdder(a, b,
          endAroundCarry: refCarry,
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
        final carryOut = Logic();
        final carryOutP1 = Logic();
        final adder = CarrySelectOnesComplementCompoundAdder(a, b,
            subtractIn: useLogic,
            subtract: subtract,
            carryOut: carryOut,
            carryOutP1: carryOutP1,
            widthGen:
                CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit(4));
        final refCarry = Logic();
        final refAdder = OnesComplementAdder(a, b,
            endAroundCarry: refCarry, subtractIn: useLogic, subtract: subtract);
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
}
