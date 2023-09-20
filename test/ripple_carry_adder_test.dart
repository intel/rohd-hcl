// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ripple_carry_adder_test.dart
// Tests for ripple carry adder.
//
// 2023 May 29
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('ripple carry adder', () {
    test('should throw exception if toSum Logics have diferent width.', () {
      final a = Logic(name: 'a', width: 8);
      final b = Logic(name: 'b', width: 16);

      expect(() => RippleCarryAdder(a, b),
          throwsA(const TypeMatcher<RohdHclException>()));
    });

    test('should return correct value for ripple carry adder.', () async {
      final a = Logic(name: 'a', width: 8);
      final b = Logic(name: 'b', width: 8);

      final lvA = Random(5).nextInt(128);
      final lvB = Random(10).nextInt(128);

      a.put(lvA);
      b.put(lvB);

      final rippleCarryAdder = RippleCarryAdder(a, b);
      await rippleCarryAdder.build();

      expect(rippleCarryAdder.sum.value.toInt(), equals(lvA + lvB));
    });

    test('should return 0 when a and b is both 0.', () async {
      final a = Logic(name: 'a', width: 10)..put(0);
      final b = Logic(name: 'b', width: 10)..put(0);

      final rippleCarryAdder = RippleCarryAdder(a, b);
      await rippleCarryAdder.build();

      expect(rippleCarryAdder.sum.value.toInt(), equals(0));
    });

    test('should return one of the value when one of the input is 0.',
        () async {
      const valA = 10;
      final a = Logic(name: 'a', width: 10)..put(valA);
      final b = Logic(name: 'b', width: 10)..put(0);

      final rippleCarryAdder = RippleCarryAdder(a, b);
      await rippleCarryAdder.build();

      expect(rippleCarryAdder.sum.value.toInt(), equals(valA));
    });

    test('should return correct value when random numbers is given.', () async {
      final a = Logic(name: 'a', width: 10);
      final b = Logic(name: 'b', width: 10);

      final rippleCarryAdder = RippleCarryAdder(a, b);
      await rippleCarryAdder.build();

      final rand = Random(5);
      for (var i = 0; i < 100; i++) {
        final randA = rand.nextInt(1 << a.width);
        final randB = rand.nextInt(1 << a.width);
        a.put(randA);
        b.put(randB);
        expect(rippleCarryAdder.sum.value.toInt(), equals(randA + randB));
      }
    });

    test('should return correct value when carry bit is non-zero.', () async {
      const widthLength = 4;
      final a = Logic(name: 'a', width: widthLength)..put(1 << widthLength - 1);
      final b = Logic(name: 'b', width: widthLength)..put(1 << widthLength - 1);

      final rippleCarryAdder = RippleCarryAdder(a, b);
      await rippleCarryAdder.build();

      expect(rippleCarryAdder.sum.value.toInt(), 1 << a.width);
      expect(rippleCarryAdder.sum.value.width, a.width + 1);
      expect(rippleCarryAdder.sum.value[a.width], equals(LogicValue.one));
    });

    test('should return correct value when overflow from int to Big Int.',
        () async {
      const widthLength = 64;
      final a = Logic(name: 'a', width: widthLength)..put(1 << widthLength - 1);
      final b = Logic(name: 'b', width: widthLength)..put(1 << widthLength - 1);

      final rippleCarryAdder = RippleCarryAdder(a, b);
      await rippleCarryAdder.build();

      expect(rippleCarryAdder.sum.value.toBigInt(), BigInt.one << a.width);
      expect(rippleCarryAdder.sum.value.width, a.width + 1);
      expect(rippleCarryAdder.sum.value[widthLength], equals(LogicValue.one));
    });
  });
}
