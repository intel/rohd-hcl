// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// rotate_test.dart
// Tests for rotating
//
// 2023 February 17
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  group('rotate left', () {
    group('Logic', () {
      test('by int', () {
        final orig = Logic(width: 8)..put(0xf0);
        expect(orig.rotateLeft(4).value.toInt(), equals(0x0f));
        expect(orig.rotateLeft(1).value.toInt(), equals(0xe1));
        expect(orig.rotateLeft(1 + 8).value.toInt(), equals(0xe1));
      });
      test('by Logic', () {
        final orig = Logic(width: 8)..put(0xf0);
        expect(orig.rotateLeft(Const(4, width: 4)).value.toInt(), equals(0x0f));
        expect(orig.rotateLeft(Const(1, width: 5)).value.toInt(), equals(0xe1));
        expect(
          orig.rotateLeft(Const(1 + 8, width: 10), maxAmount: 16).value.toInt(),
          equals(0xe1),
        );
      });
      test('by Logic with Module and maxAmount', () {
        expect(
            RotateLeft(
              Const(0xf000, width: 16),
              Const(4, width: 8),
              maxAmount: 4,
            ).rotated.value,
            equals(LogicValue.ofInt(0xf, 16)));
      });
    });

    test('LogicValue', () {
      final orig = LogicValue.ofInt(0xf0, 8);
      expect(orig.rotateLeft(4).toInt(), equals(0x0f));
      expect(orig.rotateLeft(1).toInt(), equals(0xe1));
      expect(orig.rotateLeft(1 + 8).toInt(), equals(0xe1));
    });
  });

  group('rotate right', () {
    group('Logic', () {
      test('by int', () {
        final orig = Logic(width: 8)..put(0xf0);
        expect(orig.rotateRight(4).value.toInt(), equals(0x0f));
        expect(orig.rotateRight(1).value.toInt(), equals(0x78));
        expect(orig.rotateRight(1 + 8).value.toInt(), equals(0x78));
      });
      test('by Logic', () {
        final orig = Logic(width: 8)..put(0xf0);
        expect(
          orig.rotateRight(Const(4, width: 4)).value.toInt(),
          equals(0x0f),
        );
        expect(
          orig.rotateRight(Const(1, width: 5)).value.toInt(),
          equals(0x78),
        );
        expect(
          orig
              .rotateRight(Const(1 + 8, width: 10), maxAmount: 16)
              .value
              .toInt(),
          equals(0x78),
        );
      });
    });

    test('LogicValue', () {
      final orig = LogicValue.ofInt(0xf0, 8);
      expect(orig.rotateRight(4).toInt(), equals(0x0f));
      expect(orig.rotateRight(1).toInt(), equals(0x78));
      expect(orig.rotateRight(1 + 8).toInt(), equals(0x78));
    });
  });

  test('rotate type exception', () {
    expect(() => Logic().rotateLeft('badType'),
        throwsA(const TypeMatcher<RohdHclException>()));
  });
}
