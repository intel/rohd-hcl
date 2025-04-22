// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// leading_zero_anticipate_test.dart
// Tests for the LeadingZeroAnticipate.
//
// 2025 April 14
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('LeadingDigitAnticipator: exhaustive', () {
    const width = 5;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    a.put(0);
    b.put(0);
    final sum = a + b;
    final lzp = RecursiveModulePriorityEncoder(sum.reversed).out;
    final lza = LeadingDigitAnticipate(a, b);
    final invSum = mux(sum[-1], ~sum, sum);
    final lzpInv = RecursiveModulePriorityEncoder(invSum.reversed).out;

    for (var i = 0; i < pow(2, width); i++) {
      for (var j = 0; j < pow(2, width); j++) {
        final av = LogicValue.ofInt(i, width);
        final bv = LogicValue.ofInt(j, width);
        a.put(av);
        b.put(bv);

        final Logic lz;
        if (sum[-1].value.isZero) {
          lz = lzp;
        } else {
          lz = lzpInv;
        }
        expect(
            lza.leadingDigit.value.toInt(),
            predicate(
                (c) => (c == lz.value.toInt()) || c == (lz.value.toInt() - 1)),
            reason: '''
            expected: ${lz.value.toInt()}
            computed: ${lza.leadingDigit.value.toInt()}
            av=${av.toInt()}
            bv=${bv.toInt()}
            sum=\t${sum.value.bitString}
            invSum=\t${invSum.value.bitString}
''');
      }
    }
  });

  test('LeadingDigitAnticipate: random', () {
    const width = 14;
    const iterations = 40;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    a.put(0);
    b.put(0);
    final sum = a + b;
    final lzp = RecursiveModulePriorityEncoder(sum.reversed).out;
    final lza = LeadingDigitAnticipate(a, b);
    final invSum = mux(sum[-1], ~sum, sum);
    final lzpInv = RecursiveModulePriorityEncoder(invSum.reversed).out;

    final rand = Random(47);
    for (var i = 0; i < iterations; i++) {
      final av = rand.nextLogicValue(width: width);
      final bv = rand.nextLogicValue(width: width);
      a.put(av);
      b.put(bv);

      final Logic lz;
      if (sum[-1].value.isZero) {
        lz = lzp;
      } else {
        lz = lzpInv;
      }
      expect(
          lza.leadingDigit.value.toInt(),
          predicate(
              (c) => (c == lz.value.toInt()) || c == (lz.value.toInt() - 1)),
          reason: '''
            expected: ${lz.value.toInt()}
            computed: ${lza.leadingDigit.value.toInt()}
            av=${av.toInt()}
            bv=${bv.toInt()}
            sum=\t${sum.value.bitString}
            invSum=\t${invSum.value.bitString}
''');
    }
  });

  test('LeadingZeroAnticipate: singleton', () {
    const width = 4;
    const i = -4;
    const j = 1;
    final bI = BigInt.from(i).toSigned(width);
    final bJ = BigInt.from(j).toSigned(width);
    final bigger = bI.abs() > bJ.abs() ? bI : bJ;
    final smaller = bJ;
    final biggerSign = bigger.abs() != bigger ? 1 : 0;
    final smallerSign = smaller.abs() != smaller ? 1 : 0;

    final aSignV = LogicValue.of(biggerSign, width: 1);
    final bSignV = LogicValue.of(smallerSign, width: 1);

    final av = LogicValue.of(bigger.abs(), width: width);
    final bv = LogicValue.of(smaller.abs(), width: width);

    final aSign = Logic();
    final a = Logic(width: width);
    final bSign = Logic();
    final b = Logic(width: width);
    aSign.put(aSignV);
    bSign.put(bSignV);
    a.put(av);
    b.put(bv);

    final adder = SignMagnitudeAdder(Const(0), a, aSign ^ bSign, b,
        largestMagnitudeFirst: true, outputEndAroundCarry: true);
    final predictor = LeadingZeroAnticipate(Const(0), a, aSign ^ bSign, b);

    final lz = RecursiveModulePriorityEncoder(adder.sum.reversed).out;

    final endAroundCarry = adder.endAroundCarry!;
    final leadingOneA = predictor.leadingOneA;
    final leadingOneB = predictor.leadingOneB;

    final lza = mux(endAroundCarry, leadingOneA!, leadingOneB!);

    final lzv = lz.value.toInt();
    final lzav = lza.value.toInt();

    expect(lzav, predicate((i) => (i == lzv) | (i == (lzv - 1))), reason: '''
          lzav $lzav does not estimate leading zero value $lzv
          lca=${predictor.leadingOneA!.value.toInt()}
          eac=${adder.endAroundCarry!.value.toBool()}
          lcb=${predictor.leadingOneB!.value.toInt()}
          sum:\t${adder.sum.value.bitString}
''');
  });

  // TODO(desmonddak): figure out why we can't use a negative first input
  // in the adder and still predict its result.

  test('LeadingZeroAnticipate: exhaustive', () {
    const width = 4;
    for (var i = 0; i < pow(2, width); i++) {
      for (var j = 0; j < pow(2, width); j++) {
        final bI = BigInt.from(i).toSigned(width);
        final bJ = BigInt.from(j).toSigned(width);
        final bigger = bI.abs() > bJ.abs() ? bI : bJ;
        final smaller = bI.abs() > bJ.abs() ? bJ : bI;
        final biggerSign = bigger.abs() != bigger ? 1 : 0;
        final smallerSign = smaller.abs() != smaller ? 1 : 0;

        final aSignV = LogicValue.of(biggerSign, width: 1);
        final bSignV = LogicValue.of(smallerSign, width: 1);

        final av = LogicValue.of(bigger.abs(), width: width);
        final bv = LogicValue.of(smaller.abs(), width: width);

        final aSign = Logic();
        final a = Logic(width: width);
        final bSign = Logic();
        final b = Logic(width: width);
        aSign.put(aSignV);
        bSign.put(bSignV);
        a.put(av);
        b.put(bv);

        final adder = SignMagnitudeAdder(Const(0), a, aSign ^ bSign, b,
            largestMagnitudeFirst: true, outputEndAroundCarry: true);
        final predictor = LeadingZeroAnticipate(Const(0), a, aSign ^ bSign, b);

        final lz = RecursiveModulePriorityEncoder(adder.sum.reversed).out;

        final endAroundCarry = adder.endAroundCarry!;
        final leadingOneA = predictor.leadingOneA;
        final leadingOneB = predictor.leadingOneB;

        final lza = mux(endAroundCarry, leadingOneA!, leadingOneB!);

        final lzv = lz.value.toInt();
        final lzav = lza.value.toInt();
        expect(lzav, predicate((i) => (i == lzv) | (i == (lzv - 1))),
            reason: '''
          lzav $lzav does not estimate leading zero value $lzv
''');
      }
    }
  });

  test('LeadingZeroAnticipate: sum anticipate random', () {
    const width = 14;
    const iterations = 40;

    final rand = Random(47);
    for (var i = 0; i < iterations; i++) {
      final bI = rand.nextLogicValue(width: width).toBigInt().toSigned(width);
      final bJ = rand.nextLogicValue(width: width).toBigInt().toSigned(width);
      final bigger = bI.abs() > bJ.abs() ? bI : bJ;
      final smaller = bI.abs() > bJ.abs() ? bJ : bI;
      final biggerSign = bigger.abs() != bigger ? 1 : 0;
      final smallerSign = smaller.abs() != smaller ? 1 : 0;

      final aSignV = LogicValue.of(biggerSign, width: 1);
      final bSignV = LogicValue.of(smallerSign, width: 1);

      final av = LogicValue.of(bigger.abs(), width: width);
      final bv = LogicValue.of(smaller.abs(), width: width);

      final aSign = Logic();
      final a = Logic(width: width);
      final bSign = Logic();
      final b = Logic(width: width);
      aSign.put(aSignV);
      bSign.put(bSignV);
      a.put(av);
      b.put(bv);

      final adder = SignMagnitudeAdder(Const(0), a, aSign ^ bSign, b,
          largestMagnitudeFirst: true, outputEndAroundCarry: true);
      final predictor = LeadingZeroAnticipate(Const(0), a, aSign ^ bSign, b);

      final lz = RecursiveModulePriorityEncoder(adder.sum.reversed).out;

      final endAroundCarry = adder.endAroundCarry!;
      final leadingOneA = predictor.leadingOneA;
      final leadingOneB = predictor.leadingOneB;

      final lza = mux(endAroundCarry, leadingOneA!, leadingOneB!);

      final lzv = lz.value.toInt();
      final lzav = lza.value.toInt();
      expect(lzav, predicate((i) => (i == lzv) | (i == (lzv - 1))), reason: '''
          lzav $lzav does not estimate leading zero value $lzv
''');
    }
  });

  test('LeadingZeroAnticipate: sumP1 anticipate exhaustive', () {
    const width = 4;
    for (var i = 0; i < pow(2, width); i++) {
      for (var j = 0; j < pow(2, width); j++) {
        final bI = BigInt.from(i).toSigned(width);
        final bJ = BigInt.from(j).toSigned(width);
        final bigger = bI.abs() > bJ.abs() ? bI : bJ;
        final smaller = bI.abs() > bJ.abs() ? bJ : bI;
        final biggerSign = bigger.abs() != bigger ? 1 : 0;
        final smallerSign = smaller.abs() != smaller ? 1 : 0;

        final aSignV = LogicValue.of(biggerSign, width: 1);
        final bSignV = LogicValue.of(smallerSign, width: 1);

        final av = LogicValue.of(bigger.abs(), width: width);
        final bv = LogicValue.of(smaller.abs(), width: width);

        final aSign = Logic();
        final a = Logic(width: width);
        final bSign = Logic();
        final b = Logic(width: width);
        aSign.put(aSignV);
        bSign.put(bSignV);
        a.put(av);
        b.put(bv);

        final adder = SignMagnitudeAdder(Const(0), a, aSign ^ bSign, b,
            largestMagnitudeFirst: true, outputEndAroundCarry: true);
        final predictor = LeadingZeroAnticipate(Const(0), a, aSign ^ bSign, b);

        final sum = adder.sum + Const(1, width: adder.sum.width);

        final lz = RecursiveModulePriorityEncoder(sum.reversed).out;

        final endAroundCarry = adder.endAroundCarry!;
        final leadingOneA = predictor.leadingOneA;
        final leadingOneB = predictor.leadingOneB;

        final lza = mux(endAroundCarry, leadingOneA!, leadingOneB!);

        final lzv = lz.value.toInt();
        final lzav = lza.value.toInt();

        expect(lzav,
            predicate((i) => (i == lzv) | (i == (lzv - 1)) | (i == (lzv + 1))),
            reason: '''
          lzav $lzav does not estimate leading zero value $lzv
''');
      }
    }
  });

  test('LeadingZeroAnticipate: sumP1 anticipate random', () {
    const width = 14;
    const iterations = 40;

    final rand = Random(47);
    for (var i = 0; i < iterations; i++) {
      final bI = rand.nextLogicValue(width: width).toBigInt().toSigned(width);
      final bJ = rand.nextLogicValue(width: width).toBigInt().toSigned(width);
      final bigger = bI.abs() > bJ.abs() ? bI : bJ;
      final smaller = bI.abs() > bJ.abs() ? bJ : bI;
      final biggerSign = bigger.abs() != bigger ? 1 : 0;
      final smallerSign = smaller.abs() != smaller ? 1 : 0;

      final aSignV = LogicValue.of(biggerSign, width: 1);
      final bSignV = LogicValue.of(smallerSign, width: 1);

      final av = LogicValue.of(bigger.abs(), width: width);
      final bv = LogicValue.of(smaller.abs(), width: width);

      final aSign = Logic();
      final a = Logic(width: width);
      final bSign = Logic();
      final b = Logic(width: width);
      aSign.put(aSignV);
      bSign.put(bSignV);
      a.put(av);
      b.put(bv);

      final adder = SignMagnitudeAdder(Const(0), a, aSign ^ bSign, b,
          largestMagnitudeFirst: true, outputEndAroundCarry: true);
      final predictor = LeadingZeroAnticipate(Const(0), a, aSign ^ bSign, b);

      final sum = adder.sum + Const(1, width: adder.sum.width);

      final lz = RecursiveModulePriorityEncoder(sum.reversed).out;

      final endAroundCarry = adder.endAroundCarry!;
      final leadingOneA = predictor.leadingOneA;
      final leadingOneB = predictor.leadingOneB;

      final lza = mux(endAroundCarry, leadingOneA!, leadingOneB!);

      final lzv = lz.value.toInt();
      final lzav = lza.value.toInt();

      expect(lzav,
          predicate((i) => (i == lzv) | (i == (lzv - 1)) | (i == (lzv + 1))),
          reason: '''
          lzav $lzav does not estimate leading zero value $lzv
''');
    }
  });
}
