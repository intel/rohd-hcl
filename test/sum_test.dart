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

int goldenSumOfLogics(
  List<Logic> logics, {
  required int width,
  bool saturates = false,
  int? maxVal,
  int minVal = 0,
}) =>
    goldenSum(
      logics.map((e) => SumInterface(width: e.width)..amount.gets(e)).toList(),
      width: width,
      saturates: saturates,
      minVal: minVal,
      maxVal: maxVal,
    );

int goldenSum(
  List<SumInterface> interfaces, {
  required int width,
  bool saturates = false,
  int? maxVal,
  int? minVal,
  int initialValue = 0,
  bool debug = false,
}) {
  void log(String message) {
    if (debug) {
      // ignore: avoid_print
      print(message);
    }
  }

  log('width: $width');

  var sum = initialValue;

  log('min $minVal  ->  max $maxVal');

  maxVal ??= (1 << width) - 1;
  if (maxVal > (1 << width) - 1) {
    // ignore: parameter_assignments
    maxVal = (1 << width) - 1;
  }
  minVal ??= 0;

  log('min $minVal  ->  max $maxVal  [adjusted]');

  if (minVal > maxVal) {
    throw Exception('minVal must be less than or equal to maxVal');
  }

  log('init: $initialValue');

  for (final intf in interfaces) {
    final amount = intf.amount.value.toInt();
    final enabled = !intf.hasEnable || intf.enable!.value.toBool();

    log('${intf.increments ? '+' : '-'}'
        '$amount${enabled ? '' : '  [disabled]'}');

    if (enabled) {
      if (intf.increments) {
        sum += amount;
      } else {
        sum -= amount;
      }
    }
  }

  log('=$sum');

  if (saturates) {
    if (sum > maxVal) {
      sum = maxVal;
    } else if (sum < minVal) {
      sum = minVal;
    }
    log('saturates to $sum');
  } else {
    final range = maxVal - minVal + 1;
    if (sum > maxVal) {
      sum = sum % range + minVal;
    } else if (sum < minVal) {
      sum = maxVal - (minVal - sum) % range + 1;
    }
    log('rolls-over to $sum');
  }

  return sum;
}

void main() {
  test('simple sum of 1 ofLogics', () async {
    final logics = [Const(1)];
    final dut = Sum.ofLogics(logics);
    await dut.build();
    expect(dut.value.value.toInt(), 1);
    expect(dut.width, 1);
    expect(goldenSumOfLogics(logics, width: dut.width), 1);
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
            expect(dut.value.value.toInt(), expected);
          }
        });
      }
    }
  });

  test('small width, big increment', () {
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
      maxValue: 5,
    );

    expect(dut.width, 2);

    a.put(3);
    b.put(2);
    expect(dut.value.value.toInt(), 1);
    expect(goldenSum(intfs, width: dut.width, maxVal: 5), 1);
  });

  test('one up, one down', () {
    final intfs = [
      SumInterface(fixedAmount: 3),
      SumInterface(fixedAmount: 2, increments: false),
    ];
    final dut = Sum(intfs, saturates: true, initialValue: 5, width: 7);

    expect(dut.width, 7);

    expect(dut.value.value.toInt(), 6);
    expect(dut.value.value.toInt(),
        goldenSum(intfs, width: dut.width, saturates: true, initialValue: 5));
  });

  test('init less than min', () {
    final intfs = [
      SumInterface(fixedAmount: 2),
    ];
    final dut = Sum(intfs, initialValue: 13, minValue: 16, maxValue: 31);

    final actual = dut.value.value.toInt();
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

    final actual = dut.value.value.toInt();
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

  test('random', () {
    final rand = Random(123);

    SumInterface genRandomInterface() {
      final isFixed = rand.nextBool();
      return SumInterface(
        fixedAmount: isFixed ? rand.nextInt(100) : null,
        width: isFixed ? null : rand.nextInt(8),
        increments: rand.nextBool(),
        hasEnable: rand.nextBool(),
      );
    }

    List<SumInterface> genRandomInterfaces() {
      final numInterfaces = rand.nextInt(8) + 1;
      return List.generate(numInterfaces, (_) => genRandomInterface());
    }

    //TODO: set max number of rand iterations
    for (var i = 0; i < 100; i++) {
      final interfaces = genRandomInterfaces();

      final saturates = rand.nextBool();
      var minVal = rand.nextBool() ? rand.nextInt(30) : 0;
      final maxVal = rand.nextBool() ? rand.nextInt(70) + minVal : null;
      final initialValue = rand.nextBool() ? rand.nextInt(maxVal ?? 100) : 0;
      final width = rand.nextBool() ? null : rand.nextInt(10) + 1;

      if (maxVal == null || minVal >= maxVal) {
        if (maxVal == null && width == null) {
          minVal = 0;
        } else {
          minVal =
              rand.nextInt(maxVal ?? (width == null ? 0 : (1 << width) - 1));
        }
      }

      for (final intf in interfaces) {
        if (intf.hasEnable) {
          intf.enable!.put(rand.nextBool());
        }

        if (intf.fixedAmount == null) {
          intf.amount.put(rand.nextInt(1 << intf.width));
        }
      }

      final dut = Sum(interfaces,
          saturates: saturates,
          maxValue: maxVal != null && rand.nextBool()
              ? Const(LogicValue.ofInferWidth(maxVal))
              : maxVal,
          minValue:
              rand.nextBool() ? Const(LogicValue.ofInferWidth(minVal)) : minVal,
          width: width,
          initialValue: rand.nextBool()
              ? Const(LogicValue.ofInferWidth(initialValue))
              : initialValue);

      final actual = dut.value.value.toInt();
      final expected = goldenSum(
        interfaces,
        width: dut.width,
        saturates: saturates,
        maxVal: maxVal,
        minVal: minVal,
        initialValue: initialValue,
        debug: true,
      );

      expect(actual, expected);
    }
  });
}
