// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// count_pattern_test.dart
// Tests for Count Pattern
//
// 2025 July 6
// Author: Louiz Ang Zhi Lin <louiz.zhi.lin.ang@intel.com>
// Co-author: Ramli, Nurul Izziany <nurul.izziany.ramli@intel.com>
//
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  group('From start, count pattern when pattern is', () {
    test('present once', () {
      final bus = Const(bin('00111110'), width: 8);
      final pattern = Const(bin('110'), width: 3);
      final countPattern = CountPattern(bus, pattern);
      expect(countPattern.count.value.toInt(), equals(1));
    });
    test('present more than once', () {
      final bus = Const(bin('00110110'), width: 8);
      final pattern = Const(bin('01'), width: 2);
      final countPattern = CountPattern(bus, pattern);
      expect(countPattern.count.value.toInt(), equals(2));
    });
    test('not present', () {
      final bus = Const(bin('00010000'), width: 8);
      final pattern = Const(bin('110'), width: 3);
      final countPattern = CountPattern(bus, pattern, generateError: true);
      expect(countPattern.error!.value.toInt(), equals(1));
      expect(countPattern.count.value.toInt(), equals(0));
    });
  });
  group('From end, count pattern when pattern is', () {
    test('present', () {
      final bus = Const(bin('00110111'), width: 8);
      final pattern = Const(bin('110'), width: 3);
      final countPattern = CountPattern(bus, pattern, fromStart: false);
      expect(countPattern.count.value.toInt(), equals(1));
    });
    test('present more than once', () {
      final bus = Const(bin('11011011'), width: 8);
      final pattern = Const(bin('10'), width: 2);
      final countPattern = CountPattern(bus, pattern);
      expect(countPattern.count.value.toInt(), equals(2));
    });
    test('not present', () async {
      final bus = Const(bin('101010101'), width: 8);
      final pattern = Const(bin('111'), width: 3);
      final countPattern =
          CountPattern(bus, pattern, fromStart: false, generateError: true);
      expect(countPattern.error!.value.toInt(), equals(1));
      expect(countPattern.count.value.toInt(), equals(0));
    });
  });
}
