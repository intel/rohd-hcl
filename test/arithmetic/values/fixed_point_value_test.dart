// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// 2024 September 24
// Authors:
//  Soner Yaldiz <soner.yaldiz@intel.com>

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('Construct from sign,int,frac', () {
    const m = 4;
    const n = 3;
    final corners = [
      // result, sign, integer, fraction
      ('00000000', 0, 0, 1),
      ('01111111', 0, pow(2, m).toInt() - 1, pow(2, n).toInt() - 1),
      ('10000001', 1, pow(2, m).toInt() - 1, pow(2, n).toInt() - 1),
      ('11101100', 1, 2, 4), // -2.5
    ];
    for (var c = 0; c < corners.length; c++) {
      final val = LogicValue.ofString(corners[c].$1);
      final fxp = FixedPointValue(
        sign: LogicValue.ofInt(corners[c].$2, 1),
        integer: LogicValue.ofInt(corners[c].$3, m),
        fraction: LogicValue.ofInt(corners[c].$4, n),
      );
      expect(val, fxp.value);
    }
  });

  test('Construct from int and frac only', () {
    const m = 5;
    const n = 3;
    final corners = [
      // result, integer, fraction
      ('00000000', 0, 0),
      ('11111111', pow(2, m).toInt() - 1, pow(2, n).toInt() - 1),
      ('00001001', 1, 1),
    ];
    for (var c = 0; c < corners.length; c++) {
      final val = LogicValue.ofString(corners[c].$1);
      final fxp = FixedPointValue(
        integer: LogicValue.ofInt(corners[c].$2, m),
        fraction: LogicValue.ofInt(corners[c].$3, n),
      );
      expect(val, fxp.value);
    }
  });

  test('Construct from sign and int only', () {
    const m = 7;
    final corners = [
      // result, sign, integer
      ('00000000', 0, 0),
      ('00000001', 0, 1),
      ('01000000', 0, pow(2, m - 1).toInt()),
      ('11111111', 1, 1),
    ];
    for (var c = 0; c < corners.length; c++) {
      final val = LogicValue.ofString(corners[c].$1);
      final fxp = FixedPointValue(
        sign: LogicValue.ofInt(corners[c].$2, 1),
        integer: LogicValue.ofInt(corners[c].$3, m),
      );
      expect(val, fxp.value);
    }
  });

  test('Construct from sign and frac only', () {
    const n = 4;
    final corners = [
      // result, sign, fraction
      ('00000', 0, 0),
      ('00001', 0, 1),
      ('01000', 0, pow(2, n - 1).toInt()),
      ('11111', 1, 1),
    ];
    for (var c = 0; c < corners.length; c++) {
      final val = LogicValue.ofString(corners[c].$1);
      final fxp = FixedPointValue(
        sign: LogicValue.ofInt(corners[c].$2, 1),
        fraction: LogicValue.ofInt(corners[c].$3, n),
      );
      expect(val, fxp.value);
    }
  });

  test('ofDouble toDouble', () {
    final corners = [
      ('00000000', 4, 3, 0.0),
      ('11111111', 7, 0, -1.0),
      ('00011010', 4, 3, 3.25),
      ('11110010', 4, 3, -1.75),
    ];
    for (var c = 0; c < corners.length; c++) {
      final str = corners[c].$1;
      final m = corners[c].$2;
      final n = corners[c].$3;
      final val = corners[c].$4;
      final fxp = FixedPointValue.ofDouble(val, signed: true, m: m, n: n);
      expect(str, fxp.value.bitString);
      expect(val, fxp.toDouble());
    }
    corners
      ..clear()
      ..addAll([
        ('00000000', 5, 3, 0.0),
        ('00001001', 5, 3, 1.125),
        ('11111111', 5, 3, 31.875),
      ]);
    for (var c = 0; c < corners.length; c++) {
      final str = corners[c].$1;
      final m = corners[c].$2;
      final n = corners[c].$3;
      final val = corners[c].$4;
      final fxp = FixedPointValue.ofDouble(val, signed: false, m: m, n: n);
      expect(str, fxp.value.bitString);
      expect(val, fxp.toDouble());
    }
  });

  test('compareTo', () {
    expect(
        FixedPointValue.ofDouble(1, signed: false, m: 4, n: 2)
            .compareTo(FixedPointValue.ofDouble(1, signed: false, m: 4, n: 2)),
        0);
    expect(
        FixedPointValue.ofDouble(1.125, signed: false, m: 4, n: 2).compareTo(
            FixedPointValue.ofDouble(1.125, signed: false, m: 4, n: 2)),
        0);
    expect(
        FixedPointValue.ofDouble(1.124, signed: false, m: 4, n: 2).compareTo(
            FixedPointValue.ofDouble(1.125, signed: false, m: 4, n: 2)),
        lessThan(0));
    expect(
        FixedPointValue.ofDouble(1.126, signed: false, m: 4, n: 2).compareTo(
            FixedPointValue.ofDouble(1.125, signed: false, m: 4, n: 2)),
        0);
    expect(
        FixedPointValue.ofDouble(1, signed: false, m: 4, n: 2)
            .compareTo(FixedPointValue.ofDouble(-3, signed: true, m: 4, n: 2)),
        greaterThan(0));
    expect(
        FixedPointValue.ofDouble(-3.333, signed: true, m: 4, n: 2).compareTo(
            FixedPointValue.ofDouble(-3.333, signed: true, m: 4, n: 2)),
        0);
    expect(
        FixedPointValue.ofDouble(-6.5, signed: true, m: 4, n: 2).compareTo(
            FixedPointValue.ofDouble(-3.5, signed: true, m: 4, n: 2)),
        lessThan(0));
  });

  test('Comparison operators', () {
    expect(
        FixedPointValue.ofDouble(14.432, signed: false, m: 4, n: 2)
            .eq(FixedPointValue.ofDouble(14.432, signed: false, m: 4, n: 2)),
        LogicValue.one);
    expect(
        FixedPointValue.ofDouble(14.432, signed: false, m: 4, n: 2)
            .neq(FixedPointValue.ofDouble(14.432, signed: false, m: 4, n: 2)),
        LogicValue.zero);
    expect(
        FixedPointValue.ofDouble(13.454, signed: false, m: 4, n: 2) >
            (FixedPointValue.ofDouble(14, signed: false, m: 4, n: 2)),
        LogicValue.zero);
    expect(
        FixedPointValue.ofDouble(13.454, signed: false, m: 4, n: 2) >=
            (FixedPointValue.ofDouble(14, signed: false, m: 4, n: 2)),
        LogicValue.zero);
    expect(
        FixedPointValue.ofDouble(13.454, signed: false, m: 4, n: 2) <
            (FixedPointValue.ofDouble(14, signed: false, m: 4, n: 2)),
        LogicValue.one);
    expect(
        FixedPointValue.ofDouble(13.454, signed: false, m: 4, n: 2) <=
            (FixedPointValue.ofDouble(14, signed: false, m: 4, n: 2)),
        LogicValue.one);
    expect(
        FixedPointValue.ofDouble(14, signed: false, m: 4, n: 2) <=
            (FixedPointValue.ofDouble(14, signed: false, m: 4, n: 2)),
        LogicValue.one);
    expect(
        FixedPointValue.ofDouble(14, signed: false, m: 4, n: 2) >=
            (FixedPointValue.ofDouble(14, signed: false, m: 4, n: 2)),
        LogicValue.one);
  });

  test('Math operators', () {
    FixedPointValue fxp;

    fxp = FixedPointValue.ofDouble(4.125, signed: false, m: 4, n: 3) +
        FixedPointValue.ofDouble(3.250, signed: false, m: 4, n: 2);
    expect(fxp.sign, LogicValue.empty);
    expect(fxp.integer.width, 5);
    expect(fxp.fraction.width, 3);
    expect(fxp.toDouble(), 7.375);

    fxp = FixedPointValue.ofDouble(4.125, signed: false, m: 4, n: 3) +
        FixedPointValue.ofDouble(3.250, signed: true, m: 4, n: 2);
    expect(fxp.sign, LogicValue.zero);
    expect(fxp.integer.width, 5);
    expect(fxp.fraction.width, 3);
    expect(fxp.toDouble(), 7.375);

    fxp = FixedPointValue.ofDouble(4.125, signed: false, m: 4, n: 3) +
        FixedPointValue.ofDouble(-3.250, signed: true, m: 4, n: 2);
    expect(fxp.sign, LogicValue.zero);
    expect(fxp.integer.width, 5);
    expect(fxp.fraction.width, 3);
    expect(fxp.toDouble(), 0.875);

    fxp = FixedPointValue.ofDouble(4.125, signed: false, m: 4, n: 3) -
        FixedPointValue.ofDouble(3.250, signed: false, m: 4, n: 2);
    expect(fxp.sign, LogicValue.zero);
    expect(fxp.integer.width, 5);
    expect(fxp.fraction.width, 3);
    expect(fxp.toDouble(), 0.875);

    fxp = FixedPointValue.ofDouble(4.125, signed: false, m: 4, n: 3) -
        FixedPointValue.ofDouble(-3.250, signed: true, m: 4, n: 2);
    expect(fxp.sign, LogicValue.zero);
    expect(fxp.integer.width, 5);
    expect(fxp.fraction.width, 3);
    expect(fxp.toDouble(), 7.375);

    fxp = FixedPointValue.ofDouble(4.125, signed: false, m: 4, n: 3) *
        FixedPointValue.ofDouble(-3.25, signed: true, m: 4, n: 2);
    expect(fxp.sign, LogicValue.one);
    expect(fxp.integer.width, 8);
    expect(fxp.fraction.width, 5);
    expect(fxp.toDouble(), 4.125 * -3.25);

    fxp = FixedPointValue.ofDouble(3, signed: false, m: 4, n: 3) /
        FixedPointValue.ofDouble(12, signed: true, m: 4, n: 2);
    expect(fxp.sign, LogicValue.zero);
    expect(fxp.integer.width, 8);
    expect(fxp.fraction.width, 5);
    expect(fxp.toDouble(), 3.0/12);
  });
}
