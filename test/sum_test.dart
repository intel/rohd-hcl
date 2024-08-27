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
}) {
  var sum = initialValue;
  maxVal ??= (1 << width) - 1;
  minVal ??= 0;
  for (final intf in interfaces) {
    if (!intf.hasEnable || intf.enable!.value.toBool()) {
      final amount = intf.amount.value.toInt();
      if (intf.increments) {
        sum += amount;
      } else {
        sum -= amount;
      }
    }
  }

  if (saturates) {
    if (sum > maxVal) {
      sum = maxVal;
    } else if (sum < minVal) {
      sum = minVal;
    }
  } else {
    final range = maxVal - minVal + 1;
    if (sum > maxVal) {
      sum = sum % range + minVal;
    } else if (sum < minVal) {
      sum = maxVal - sum % range;
    }
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

  // TODO: testing with overridden width

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
      final numInterfaces = rand.nextInt(8);
      return List.generate(numInterfaces, (_) => genRandomInterface());
    }

    //TODO: set max number of rand iterations
    for (var i = 0; i < 1; i++) {
      final interfaces = genRandomInterfaces();

      final saturates = rand.nextBool();
      final minVal = rand.nextBool() ? rand.nextInt(30) : null;
      final maxVal = rand.nextBool() ? rand.nextInt(70) + (minVal ?? 0) : null;
      final initialValue = rand.nextInt(maxVal ?? 100);

      for (final intf in interfaces) {
        if (intf.hasEnable) {
          intf.enable!.put(rand.nextBool());
        }

        if (intf.fixedAmount != null) {
          intf.amount.put(rand.nextInt(1 << intf.width));
        }
      }

      final dut = Sum(interfaces,
          saturates: saturates,
          maxValue: maxVal,
          minValue: minVal,
          width: rand.nextBool() ? null : rand.nextInt(8),
          initialValue: initialValue);

      expect(
        dut.value.value.toInt(),
        goldenSum(
          interfaces,
          width: dut.width,
          saturates: saturates,
          maxVal: maxVal,
          minVal: minVal,
          initialValue: initialValue,
        ),
      );
    }
  });
}
