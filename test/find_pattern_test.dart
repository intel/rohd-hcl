// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// find_pattern_test.dart
// Tests for Find Pattern
//
// 2025 March 6
// Author: Louiz Ang Zhi Lin <louiz.zhi.lin.ang@intel.com>
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  group('From start, find first pattern with n as null', () {
    test('at 0th position', () async {
      final bus = Const(bin('10000001'), width: 8);
      final pattern = Const(bin('01'), width: 2);
      final findPattern = FindPattern(bus, pattern);
      expect(findPattern.index.value.toInt(), equals(0));
    });
    test('at random position', () async {
      final bus = Const(bin('11011111'), width: 8);
      final pattern = Const(bin('101'), width: 3);
      final findPattern = FindPattern(bus, pattern);
      expect(findPattern.index.value.toInt(), equals(4));
    });
    test('at last position', () async {
      final bus = Const(bin('11101010'), width: 8);
      final pattern = Const(bin('11101'), width: 5);
      final findPattern = FindPattern(bus, pattern);
      expect(findPattern.index.value.toInt(), equals(3));
    });
    test('when pattern not present', () async {
      final bus = Const(bin('00000000'), width: 8);
      final pattern = Const(bin('111'), width: 3);
      final findPattern = FindPattern(bus, pattern, generateError: true);
      expect(findPattern.error!.value.toInt(), equals(1));
    });
  });

  group('From end, find first pattern with n as null', () {
    test('at 0th position', () async {
      final bus = Const(bin('11101010'), width: 8);
      final pattern = Const(bin('11101'), width: 5);
      final findPattern = FindPattern(bus, pattern, start: false);
      expect(findPattern.index.value.toInt(), equals(0));
    });
    test('at random position', () async {
      final bus = Const(bin('11011111'), width: 8);
      final pattern = Const(bin('101'), width: 3);
      final findPattern = FindPattern(bus, pattern, start: false);
      expect(findPattern.index.value.toInt(), equals(1));
    });
    test('at last position', () async {
      final bus = Const(bin('10000001'), width: 8);
      final pattern = Const(bin('01'), width: 2);
      final findPattern = FindPattern(bus, pattern, start: false);
      expect(findPattern.index.value.toInt(), equals(6));
    });
    test('Pattern not present', () async {
      final bus = Const(bin('00000000'), width: 8);
      final pattern = Const(bin('111'), width: 3);
      final findPattern =
          FindPattern(bus, pattern, start: false, generateError: true);
      expect(findPattern.error!.value.toInt(), equals(1));
    });
  });

  group('From start, find nth pattern', () {
    test('where n is 0', () async {
      final bus = Const(bin('10101001'), width: 8);
      final pattern = Const(bin('01'), width: 2);
      final n = Const(0, width: log2Ceil(8) + 1);
      final findPattern = FindPattern(bus, pattern, n: n);
      expect(findPattern.index.value.toInt(), equals(0));
    });
    test('where n is 2 (find the 3rd occurrence, n is zero-index)', () async {
      final bus = Const(bin('10101001'), width: 8);
      final pattern = Const(bin('01'), width: 2);
      final n = Const(2, width: log2Ceil(8) + 1);
      final findPattern = FindPattern(bus, pattern, n: n);
      expect(findPattern.index.value.toInt(), equals(5));
    });
    test('where n is outside bound', () async {
      final bus = Const(bin('10101001'), width: 8);
      final pattern = Const(bin('01'), width: 2);
      final n = Const(5, width: log2Ceil(8) + 1);
      final findPattern = FindPattern(bus, pattern, n: n, generateError: true);
      expect(findPattern.error!.value.toInt(), equals(1));
    });
  });

  group('From end, find nth pattern', () {
    test('where n is 0', () async {
      final bus = Const(bin('01010110'), width: 8);
      final pattern = Const(bin('01'), width: 2);
      final n = Const(0, width: log2Ceil(8) + 1);
      final findPattern = FindPattern(bus, pattern, start: false, n: n);
      expect(findPattern.index.value.toInt(), equals(0));
    });
    test('where n is 2 (find the 3rd occurrence, n is zero-index)', () async {
      final bus = Const(bin('10101001'), width: 8);
      final pattern = Const(bin('01'), width: 2);
      final n = Const(2, width: log2Ceil(8) + 1);
      final findPattern = FindPattern(bus, pattern, start: false, n: n);
      expect(findPattern.index.value.toInt(), equals(6));
    });
    test('where n is outside bound', () async {
      final bus = Const(bin('10101001'), width: 8);
      final pattern = Const(bin('01'), width: 2);
      final n = Const(5, width: log2Ceil(8) + 1);
      final findPattern =
          FindPattern(bus, pattern, start: false, n: n, generateError: true);
      expect(findPattern.error!.value.toInt(), equals(1));
    });
  });
}
