// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sum_test.dart
// Tests for sum.
//
// 2024 August 27
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

import 'summation_test_utils.dart';

void main() {
  test('simple sum of 1 ofLogics', () async {
    final logics = [Const(1)];
    final dut = Sum.ofLogics(logics);
    await dut.build();
    expect(dut.sum.value.toInt(), 1);
    expect(dut.width, 1);
    expect(goldenSumOfLogics(logics, width: dut.width), 1);
  });

  group('sum indications', () {
    test('equalsMax', () {
      expect(
          Sum.ofLogics([Const(5, width: 8)], maxValue: 5)
              .equalsMax
              .value
              .toBool(),
          isTrue);
    });

    test('equalsMin', () {
      final dut =
          Sum.ofLogics([Const(0, width: 8)], minValue: 3, saturates: true);
      expect(dut.equalsMin.value.toBool(), isTrue);
    });

    test('underflowed', () {
      final dut = Sum.ofLogics([Const(5, width: 8)], minValue: 6);
      expect(dut.underflowed.value.toBool(), isTrue);
    });

    test('overflowed', () {
      final dut =
          Sum.ofLogics([Const(5, width: 8)], maxValue: 4, saturates: true);
      expect(dut.overflowed.value.toBool(), isTrue);
    });
  });

  group('simple 2 numbers', () {
    final pairs = [
      // fits
      (3, 5),
      (7, 1),

      // barely fits
      (10, 5),

      // barely overflows
      (7, 9),

      // overflows
      (8, 10),
    ];

    for (final increments in [true, false]) {
      final initialValue = increments ? 0 : 15;
      for (final saturates in [true, false]) {
        test('increments=$increments, saturate=$saturates', () async {
          final a = Logic(width: 4);
          final b = Logic(width: 4);
          final intfs = [a, b]
              .map((e) => SumInterface(
                    width: e.width,
                    increments: increments,
                  )..amount.gets(e))
              .toList();
          final dut =
              Sum(intfs, saturates: saturates, initialValue: initialValue);

          await dut.build();

          expect(dut.width, 4);

          for (final pair in pairs) {
            a.put(pair.$1);
            b.put(pair.$2);
            final expected = goldenSum(
              intfs,
              width: dut.width,
              saturates: saturates,
              initialValue: initialValue,
            );
            expect(dut.sum.value.toInt(), expected);
          }
        });
      }
    }
  });

  test('small width, big increment', () async {
    final a = Logic(width: 4);
    final b = Logic(width: 4);
    final intfs = [a, b]
        .map((e) => SumInterface(
              width: e.width,
            )..amount.gets(e))
        .toList();
    final dut = Sum(
      intfs,
      width: 2,
    );
    await dut.build();

    expect(dut.width, 2);

    a.put(3);
    b.put(2);
    expect(dut.sum.value.toInt(), 1);
    expect(goldenSum(intfs, width: dut.width, maxVal: 5), 1);
  });

  test('large increment on small width needs modulo', () async {
    final a = Logic(width: 8);
    final b = Logic(width: 8);
    final dut = Sum.ofLogics(
      [a, b],
      width: 2,
    );
    await dut.build();

    expect(dut.width, 2);

    a.put(10);
    b.put(11);
    expect(dut.sum.value.toInt(), 1);
  });

  test('one up, one down', () {
    final intfs = [
      SumInterface(fixedAmount: 3),
      SumInterface(fixedAmount: 2, increments: false),
    ];
    final dut = Sum(intfs, saturates: true, initialValue: 5, width: 7);

    expect(dut.width, 7);

    expect(dut.sum.value.toInt(), 6);
    expect(dut.sum.value.toInt(),
        goldenSum(intfs, width: dut.width, saturates: true, initialValue: 5));
  });

  test('init less than min', () {
    final intfs = [
      SumInterface(fixedAmount: 2),
    ];
    final dut = Sum(intfs, initialValue: 13, minValue: 16, maxValue: 31);

    final actual = dut.sum.value.toInt();
    final expected = goldenSum(
      intfs,
      width: dut.width,
      minVal: 16,
      maxVal: 31,
      initialValue: 13,
    );
    expect(actual, 31);
    expect(actual, expected);
  });

  test('init more than max', () {
    final intfs = [
      SumInterface(fixedAmount: 2, increments: false),
    ];
    final dut = Sum(intfs, initialValue: 34, minValue: 16, maxValue: 31);

    final actual = dut.sum.value.toInt();
    final expected = goldenSum(
      intfs,
      width: dut.width,
      minVal: 16,
      maxVal: 31,
      initialValue: 34,
    );
    expect(actual, 16);
    expect(actual, expected);
  });

  test('min == max', () {
    final intfs = [
      SumInterface(fixedAmount: 2, increments: false),
    ];
    final dut = Sum(intfs, initialValue: 4, minValue: 12, maxValue: 12);

    final actual = dut.sum.value.toInt();
    final expected = goldenSum(
      intfs,
      width: dut.width,
      minVal: 12,
      maxVal: 12,
      initialValue: 4,
    );
    expect(actual, 12);
    expect(actual, expected);
  });

  group('reached', () {
    test('has overflowed', () {
      final dut = Sum.ofLogics([Const(10, width: 8)],
          width: 8, maxValue: 5, saturates: true);
      expect(dut.overflowed.value.toBool(), true);
      expect(dut.sum.value.toInt(), 5);
    });

    test('not overflowed', () {
      final dut = Sum.ofLogics([Const(3, width: 8)],
          width: 8, maxValue: 5, saturates: true);
      expect(dut.overflowed.value.toBool(), false);
      expect(dut.sum.value.toInt(), 3);
    });

    test('has underflowed', () {
      final dut = Sum([
        SumInterface(fixedAmount: 10, increments: false),
      ], width: 8, minValue: 15, initialValue: 20, saturates: true);
      expect(dut.underflowed.value.toBool(), true);
      expect(dut.sum.value.toInt(), 15);
    });

    test('not underflowed', () {
      final dut = Sum([
        SumInterface(fixedAmount: 3, increments: false),
      ], width: 8, minValue: 15, initialValue: 20, saturates: true);
      expect(dut.underflowed.value.toBool(), false);
      expect(dut.sum.value.toInt(), 17);
    });
  });

  test('sum ofLogics enable', () async {
    final a = Logic(width: 3);
    final b = Logic(width: 3);
    final en = Logic();
    final dut = Sum.ofLogics(
      [a, b],
      width: 2,
      enable: en,
    );
    await dut.build();

    expect(dut.width, 2);

    a.put(2);
    b.put(3);
    en.put(false);
    expect(dut.sum.value.toInt(), 0);
    en.put(true);
    expect(dut.sum.value.toInt(), 1);
  });

  test('very large widths', () async {
    final initVal = BigInt.two.pow(66) + BigInt.one;
    final a = BigInt.two.pow(80) + BigInt.one;
    final b = BigInt.from(1234);
    final dut = Sum(
      [
        SumInterface(fixedAmount: a),
        SumInterface(width: 75)..amount.gets(Const(b, width: 75)),
      ],
      initialValue: initVal,
      maxValue: BigInt.two.pow(82),
    );
    await dut.build();

    expect(dut.sum.value.toBigInt(), initVal + a + b);
    expect(dut.width, greaterThan(80));
  });

  test('random sum', () {
    final rand = Random(123);

    for (var i = 0; i < 1000; i++) {
      final cfg = genRandomSummationConfiguration();

      for (final intf in cfg.interfaces) {
        if (intf.hasEnable) {
          intf.enable!.put(rand.nextBool());
        }

        if (intf.fixedAmount == null) {
          intf.amount.put(rand.nextInt(1 << intf.width));
        }
      }

      final dut = Sum(cfg.interfaces,
          saturates: cfg.saturates,
          maxValue: cfg.maxValue,
          minValue: cfg.minValue,
          width: cfg.width,
          initialValue: cfg.initialValue);

      final actual = dut.sum.value.toInt();
      final expected = goldenSum(
        cfg.interfaces,
        width: dut.width,
        saturates: cfg.saturates,
        maxVal: cfg.maxVal,
        minVal: cfg.minVal,
        initialValue: cfg.initialVal,
      );

      expect(actual, expected);
    }
  });
}
