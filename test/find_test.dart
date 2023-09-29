// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// find_test.dart
// Tests for Find
//
// 2023 June 8
// Author: Rahul Gautham Putcha <rahul.gautham.putcha@intel.com>
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/utils.dart';
import 'package:test/test.dart';

void main() {
  group(
      'find first one with n as null',
      () => {
            test('at 0th position', () {
              final bus = Const(bin('11010101'), width: 8);
              final mod = Find(bus);
              expect(mod.index.value.toInt(), 0);
            }),
            test('at random position', () {
              final bus = Const(bin('11111100'), width: 8);
              final mod = Find(bus);
              expect(mod.index.value.toInt(), 2);
            }),
            test('at last position', () {
              final bus = Const(bin('10000000'), width: 8);
              final mod = Find(bus);
              expect(mod.index.value.toInt(), 7);
            }),
            test('when first one is not present', () {
              final bus = Const(bin('00000000'), width: 8);
              final mod = Find(bus);
              // When your find is not found it will result in error
              expect(mod.error.value.toInt(), 1);
            }),
          });

  group(
      'find first zero with n as null',
      () => {
            test('at 0th position', () {
              final bus = Const(bin('11010100'), width: 8);
              final mod = Find(bus, countOne: false);
              expect(mod.index.value.toInt(), 0);
            }),
            test('at random position', () {
              final bus = Const(bin('10101011'), width: 8);
              final mod = Find(bus, countOne: false);
              expect(mod.index.value.toInt(), 2);
            }),
            test('at last position', () {
              final bus = Const(bin('01111111'), width: 8);
              final mod = Find(bus, countOne: false);
              expect(mod.index.value.toInt(), 7);
            }),
            test('when first zero is not present', () {
              final bus = Const(bin('11111111'), width: 8);
              final mod = Find(bus, countOne: false);
              // When your find is not found it will result in error
              expect(mod.error.value.toInt(), 1);
            }),
          });

  group(
      'find nth zero',
      () => {
            test('n is 0', () {
              final bus = Const(bin('11010100'), width: 8);
              final mod = Find(bus, countOne: false);
              expect(mod.index.value.toInt(), 0);
            }),
            test('when n is 2 (find 3rd zero; n is zero index)', () {
              final bus = Const(bin('10101011'), width: 8);
              final mod = Find(bus,
                  countOne: false, n: Const(2, width: log2Ceil(8) + 1));
              expect(mod.index.value.toInt(), 6);
            }),
            test('n is outside bound', () {
              final bus = Const(bin('00000000'), width: 8);
              final mod =
                  Find(bus, countOne: false, n: Const(10, width: log2Ceil(10)));
              expect(mod.error.value.toInt(), 1);
            }),
            test('if all 0s', () {
              final bus = Const(bin('00000000'), width: 8);
              final mod =
                  Find(bus, countOne: false, n: Const(7, width: log2Ceil(8)));
              expect(mod.index.value.toInt(), 0);
            }),
            test('if all 1s', () {}),
          });

  group(
      'find nth one',
      () => {
            test('n is 0', () {
              final bus = Const(bin('11010100'), width: 8);
              final mod = Find(bus);
              expect(mod.index.value.toInt(), 2);
            }),
            test('when n is 2 (find 3rd zero; n is zero index)', () {
              final bus = Const(bin('10101011'), width: 8);
              final mod = Find(bus, n: Const(2, width: log2Ceil(8)));
              expect(mod.index.value.toInt(), 3);
            }),
            test('n is outside bound', () {
              final bus = Const(bin('11111111'), width: 8);
              final mod = Find(bus, n: Const(10, width: log2Ceil(10)));
              expect(mod.error.value.toInt(), 1);
            }),
          });
}
