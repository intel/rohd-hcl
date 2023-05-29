// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ripple_carry_adder_test.dart
// Tests for ripple carry adder.
//
// 2023 May 29
// Author: Yao Jing Quek <yao.jing.quek@intel.com>
//

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

      expect(() => RippleCarryAdder(toSum: [a, b]),
          throwsA(const TypeMatcher<RohdHclException>()));
    });

    test('should throw exception if toSum length is not two.', () {
      final a = Logic(name: 'a', width: 8);
      final b = Logic(name: 'b', width: 8);
      final c = Logic(name: 'c', width: 8);

      expect(() => RippleCarryAdder(toSum: [a, b, c]),
          throwsA(const TypeMatcher<RohdHclException>()));
    });

    test('should return correct value for ripple carry adder.', () {
      final a = Logic(name: 'a', width: 8);
      final b = Logic(name: 'b', width: 8);

      final lvA = Random(5).nextInt(128);
      final lvB = Random(10).nextInt(128);

      a.put(lvA);
      b.put(lvB);

      final rippleCarryAdder = RippleCarryAdder(toSum: [a, b]);

      expect(rippleCarryAdder.sum.rswizzle().value.toInt(), equals(lvA + lvB));
    });
  });
}
