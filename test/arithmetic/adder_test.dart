// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// adder_test.dart
// Tests for the Adder interface.
//
// 2024 April 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

Logic msb(Logic a) => a[a.width - 1];
Logic lsb(Logic a) => a[0];

LogicValue msbV(LogicValue a) => a[a.width - 1];
LogicValue lsbV(LogicValue a) => a[0];

void checkAdder(Adder adder, LogicValue av, LogicValue bv) {
  final aB = av.toBigInt();
  final bB = bv.toBigInt();
  // ignore: invalid_use_of_protected_member
  adder.a.put(av);
  // ignore: invalid_use_of_protected_member
  adder.b.put(bv);

  expect(
      adder.out.value.toBigInt(),
      // ignore: invalid_use_of_protected_member
      equals((aB + bB) & ((BigInt.one << adder.a.width) - BigInt.one)));
  expect(adder.sum.value.toBigInt(), equals(aB + bB));
}

void testExhaustive(int n, Adder Function(Logic a, Logic b) fn) {
  final a = Logic(name: 'a', width: n);
  final b = Logic(name: 'b', width: n);

  final mod = fn(a, b);
  test(
      'exhaustive: ${mod.name}_W$n'
      '_G${fn.call(a, b).name}', () async {
    await mod.build();

    for (var aa = 0; aa < (1 << n); ++aa) {
      for (var bb = 0; bb < (1 << n); ++bb) {
        final av = LogicValue.of(BigInt.from(aa), width: n);
        final bv = LogicValue.of(BigInt.from(bb), width: n);
        checkAdder(mod, av, bv);
      }
    }
  });
}

void testAdderRandom(int n, int nSamples, Adder Function(Logic a, Logic b) fn) {
  final a = Logic(name: 'a', width: n);
  final b = Logic(name: 'b', width: n);

  final adder = fn(a, b);
  test('random: ${adder.name}_W${a.width}_I$nSamples', () async {
    await adder.build();

    for (var i = 0; i < nSamples; ++i) {
      final aa = Random().nextLogicValue(width: n);
      final bb = Random().nextLogicValue(width: n);
      checkAdder(adder, aa, bb);
    }
  });
}

void checkSignMagnitudeAdder(SignMagnitudeAdder adder, LogicValue aSign,
    LogicValue aMagnitude, LogicValue bSign, LogicValue bMagnitude) {
  // ignore: invalid_use_of_protected_member
  adder.aSign.put(aSign);
  // ignore: invalid_use_of_protected_member
  adder.bSign.put(bSign);

  // ignore: invalid_use_of_protected_member
  adder.a.put(aMagnitude);
  // ignore: invalid_use_of_protected_member
  adder.b.put(bMagnitude);

  final n = aMagnitude.width;

  final computedVal = (adder.sign.value == LogicValue.one)
      ? -adder.out.value.toBigInt()
      : adder.out.value.toBigInt();

  final aValue = (aSign == LogicValue.one)
      ? -aMagnitude.toBigInt()
      : aMagnitude.toBigInt();
  final bValue = (bSign == LogicValue.one)
      ? -bMagnitude.toBigInt()
      : bMagnitude.toBigInt();
  final expectSign = (aValue + bValue).sign;
  // Special modular arithmetic for 1's complement negative numbers
  //   Remember that there are two zeros in 1's complement
  final expectedMag = (aValue + bValue).abs() %
      ((expectSign == -1)
          ? BigInt.from(pow(2, n) - 1)
          : BigInt.from(pow(2, n)));
  final expectVal = expectSign == -1 ? -expectedMag : expectedMag;
  expect(computedVal, equals(expectVal));
}

void testExhaustiveSignMagnitude(int n, Adder Function(Logic a, Logic b) fn) {
  final aSign = Logic(name: 'aSign');
  final a = Logic(name: 'a', width: n);
  final bSign = Logic(name: 'bSign');
  final b = Logic(name: 'b', width: n);

  final adder = SignMagnitudeAdder(aSign, a, bSign, b, fn);
  test('exhaustive Sign Magnitude: ${adder.name}_W${a.width}', () async {
    await adder.build();

    for (var i = 0; i < pow(2, n); i += 1) {
      for (var j = 0; j < pow(2, n); j += 1) {
        final bI = BigInt.from(i).toSigned(n);
        final bJ = BigInt.from(j).toSigned(n);
        final BigInt smaller;
        final BigInt bigger;
        // When equal, we want the negative one first to produce 1 1...1
        if ((bI.abs() > bJ.abs()) || (bI.abs() == bJ.abs() && (bI < bJ))) {
          bigger = bI;
          smaller = bJ;
        } else {
          bigger = bJ;
          smaller = bI;
        }
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
  });
}

void testRandomSignMagnitude(
    int width, int nSamples, Adder Function(Logic a, Logic b) fn) {
  final aSign = Logic(name: 'aSign');
  final a = Logic(name: 'a', width: width);
  final bSign = Logic(name: 'bSign');
  final b = Logic(name: 'b', width: width);

  final adder = SignMagnitudeAdder(aSign, a, bSign, b, fn);
  test('random Sign Magnitude: ${adder.name}_W${a.width}', () async {
    await adder.build();

    for (var i = 0; i < nSamples; ++i) {
      final aa = Random().nextLogicValue(width: width);
      final av = aa.toBigInt().toSigned(width);
      final bb = Random().nextLogicValue(width: width);
      final bv = bb.toBigInt().toSigned(width);

      final BigInt smaller;
      final BigInt bigger;
      // When equal, we want the negative one first to produce 1 1...1
      if ((av.abs() > bv.abs()) || (av.abs() == bv.abs() && (av < bv))) {
        bigger = av;
        smaller = bv;
      } else {
        bigger = bv;
        smaller = av;
      }
      final biggerSign = bigger.abs() != bigger ? 1 : 0;
      final smallerSign = smaller.abs() != smaller ? 1 : 0;

      final biggerSignLv = LogicValue.of(biggerSign, width: 1);
      final smallerSignLv = LogicValue.of(smallerSign, width: 1);

      final biggerLv = LogicValue.of(bigger.abs(), width: width);
      final smallerLv = LogicValue.of(smaller.abs(), width: width);

      checkSignMagnitudeAdder(
          adder, biggerSignLv, biggerLv, smallerSignLv, smallerLv);
    }
  });
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  final generators = [Ripple.new, Sklansky.new, KoggeStone.new, BrentKung.new];

  group('adderRandom', () {
    for (final n in [64, 64, 65]) {
      testAdderRandom(n, 30, RippleCarryAdder.new);
      for (final ppGen in generators) {
        testAdderRandom(n, 30, (a, b) => ParallelPrefixAdder(a, b, ppGen));
      }
    }
  });
  group('exhaustive', () {
    testExhaustive(4, RippleCarryAdder.new);
    for (final ppGen in generators) {
      testExhaustive(4, (a, b) => ParallelPrefixAdder(a, b, ppGen));
    }
  });
  group('SignMagnitude random', () {
    for (final ppGen in generators) {
      testRandomSignMagnitude(4, 30, RippleCarryAdder.new);
      testRandomSignMagnitude(
          4, 30, (a, b) => ParallelPrefixAdder(a, b, ppGen));
    }
  });
  group('SignMagnitude exhaustive', () {
    for (final ppGen in generators) {
      testExhaustiveSignMagnitude(4, RippleCarryAdder.new);
      testExhaustiveSignMagnitude(
          4, (a, b) => ParallelPrefixAdder(a, b, ppGen));
    }
  });
}
