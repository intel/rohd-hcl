// Copyright (C) 2023-2024 Intel Corporation
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
  expect(adder.sum1.value.toBigInt(), equals(aB + bB + BigInt.from(1)));
}

void testExhaustive(int n, CompoundAdder Function(Logic a, Logic b) fn) {
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
    testExhaustive(4, MockCompoundAdder.new);
    testExhaustive(4, CarrySelectCompoundAdder.new);
 });
  test('trivial compound adder test', () async {
    const width = 6;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);

    a.put(18);
    b.put(24);

    final adder = CarrySelectCompoundAdder(
      a, b, widthGen: CarrySelectCompoundAdder.splitSelectAdder4BitAlgorithm);
    
    final sum = adder.sum;
    final sum1 = adder.sum1;
    expect(sum.value.toBigInt(), equals(BigInt.from(18 + 24)));
    expect(sum1.value.toBigInt(), equals(BigInt.from(18 + 24 + 1)));
  });
  test('should return correct value when random numbers are given.', () async {
      final a = Logic(name: 'a', width: 10);
      final b = Logic(name: 'b', width: 10);

      final adder = CarrySelectCompoundAdder(
        a, b, widthGen: CarrySelectCompoundAdder.splitSelectAdder4BitAlgorithm);
      await adder.build();

      final rand = Random(5);
      for (var i = 0; i < 100; i++) {
        final randA = rand.nextInt(1 << a.width);
        final randB = rand.nextInt(1 << a.width);
        a.put(randA);
        b.put(randB);
        expect(adder.sum.value.toInt(),
          equals(randA + randB));
        expect(adder.sum1.value.toInt(),
          equals(randA + randB + 1));
      }
    });
}
