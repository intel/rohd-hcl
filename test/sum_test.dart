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
  int minVal = 0,
}) {
  var sum = 0;
  maxVal ??= 1 << width - 1;
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
    final range = maxVal - minVal;
    if (sum > maxVal) {
      sum = sum % range + minVal;
    } else if (sum < minVal) {
      sum = maxVal - sum % range;
    }
  }

  return sum;
}

void main() {
  test('simple sum of 1', () async {
    final logics = [Const(1)];
    final dut = Sum.ofLogics(logics);
    await dut.build();
    expect(dut.value.value.toInt(), 1);
    expect(dut.width, 1);
    expect(goldenSumOfLogics(logics, width: dut.width), 1);
  });

  group('random', () {
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

    void testSum({required int numIncr, required int numDecr}) {}
  });
}
