// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// extrema_test.dart
// Tests for extrema.
//
// 2024 September 16
// Author: Roberto Torres <roberto.torres@intel.com>
//

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });
  test('Extrema of a list of Logics, all same width.', () async {
    // Create a list of Logic objects with different values.
    final logics = [
      Logic(width: 8)..put(LogicValue.ofString('01101101')), // 109 in decimal
      Logic(width: 8)..put(LogicValue.ofString('00010100')), // 20 in decimal
      Logic(width: 8)..put(LogicValue.ofString('00000011')), // 3 in decimal
      Logic(width: 8)..put(LogicValue.ofString('00001111')) // 15 in decimal
    ];

    // Create an instance of Extrema to use for finding first minimum.
    final findMin = Extrema(logics, max: false);
    await findMin.build();

    // Create an instance of FindMax.
    final findMax = Extrema(logics);
    await findMax.build();

    // Verify the min value and index
    expect(findMin.val.value.toInt(), equals(3));
    expect(findMin.index.value.toInt(), equals(2));

    // Verify the max value and index.
    expect(findMax.val.value.toInt(), equals(109));
    expect(findMax.index.value.toInt(), equals(0));
  });

  test('Extrema of a list of Logics, different widths.', () async {
    // Create a list of Logic objects with different values.
    final logics = [
      Logic(width: 8)..put(LogicValue.ofString('01101101')), // 109 in decimal
      Logic(width: 4)..put(LogicValue.ofString('0101')), // 5 in decimal
      Logic(width: 8)..put(LogicValue.ofString('00010100')), // 20 in decimal
      Logic(width: 2)..put(LogicValue.ofString('11')), // 3 in decimal
      Logic(width: 8)..put(LogicValue.ofString('00001111')) // 15 in decimal
    ];

    // Create an instance of FindMin.
    final findMin = Extrema(logics, max: false);
    await findMin.build();

    // Create an instance of FindMax.
    final findMax = Extrema(logics);
    await findMax.build();

    // Verify the min value and index
    expect(findMin.val.value.toInt(), equals(3));
    expect(findMin.index.value.toInt(), equals(3));

    // Verify the max value and index.
    expect(findMax.val.value.toInt(), equals(109));
    expect(findMax.index.value.toInt(), equals(0));
  });

  test('List with same extrema including min in first and last.', () async {
    // Create a list of Logic objects with different values.
    final logics = [
      Logic(width: 8)..put(LogicValue.ofString('00000011')), // 3 in decimal
      Logic(width: 4)..put(LogicValue.ofString('1101')), // 13 in decimal
      Logic(width: 8)..put(LogicValue.ofString('00000100')), // 4 in decimal
      Logic(width: 2)..put(LogicValue.ofString('11')), // 3 in decimal
      Logic(width: 8)..put(LogicValue.ofString('00001100')), // 12 in decimal
      Logic(width: 6)..put(LogicValue.ofString('001101')), // 13 in decimal
      Logic(width: 8)..put(LogicValue.ofString('00000011')), // 3 in decimal
    ];

    // Create an instance of FindMin.
    final findMin = Extrema(logics, max: false);
    await findMin.build();

    // Create an instance of FindMax.
    final findMax = Extrema(logics);
    await findMax.build();

    // Verify the min value and index
    expect(findMin.val.value.toInt(), equals(3));
    expect(findMin.index.value.toInt(), equals(0));

    // Verify the max value and index.
    expect(findMax.val.value.toInt(), equals(13));
    expect(findMax.index.value.toInt(), equals(1));
  });

  test('List with same extrema including max in first and last.', () async {
    // Create a list of Logic objects with different values.
    final logics = [
      Logic(width: 8)..put(LogicValue.ofString('000001101')), // 13 in decimal
      Logic(width: 4)..put(LogicValue.ofString('1101')), // 13 in decimal
      Logic(width: 8)..put(LogicValue.ofString('00000100')), // 4 in decimal
      Logic(width: 2)..put(LogicValue.ofString('11')), // 3 in decimal
      Logic(width: 8)..put(LogicValue.ofString('00001100')), // 12 in decimal
      Logic(width: 6)..put(LogicValue.ofString('000011')), // 3 in decimal
      Logic(width: 8)..put(LogicValue.ofString('000001101')), // 13 in decimal
    ];

    // Create an instance of FindMin.
    final findMin = Extrema(logics, max: false);
    await findMin.build();

    // Create an instance of FindMax.
    final findMax = Extrema(logics);
    await findMax.build();

    // Verify the min value and index
    expect(findMin.val.value.toInt(), equals(3));
    expect(findMin.index.value.toInt(), equals(3));

    // Verify the max value and index.
    expect(findMax.val.value.toInt(), equals(13));
    expect(findMax.index.value.toInt(), equals(0));
  });

  test('List containing one element.', () async {
    // Create a list of Logic objects with different values
    final logics = [
      Logic(width: 4)..put(LogicValue.ofString('1100')), // 12 in decimal
    ];

    // Create an instance of FindMin.
    final findMin = Extrema(logics, max: false);
    await findMin.build();

    // Create an instance of FindMax
    final findMax = Extrema(logics);
    await findMax.build();

    // Verify the minimum value and index
    expect(findMax.val.value.toInt(), equals(12));
    expect(findMax.index.value.toInt(), equals(0));
  });

  test('Empty List.', () {
    // Create a list of Logic objects with
    final logics = List<Logic>.empty();

    // Try to create an instance of Extrema
    expect(() => Extrema(logics), throwsA(isA<RohdHclException>()));
  });

  test('tree radix does not affect computed extrema', () async {
    final rand = Random(1);
    for (var trial = 0; trial < 20; trial++) {
      final count = 1 + rand.nextInt(10);
      final values = List<int>.generate(count, (_) => rand.nextInt(1 << 8));
      final logics = [
        for (final v in values) Logic(width: 8)..put(v),
      ];

      for (final max in [true, false]) {
        // compute expected using earliest-index tie-breaking
        var expectedIndex = 0;
        for (var i = 1; i < values.length; i++) {
          final better = max
              ? values[i] > values[expectedIndex]
              : values[i] < values[expectedIndex];
          if (better) {
            expectedIndex = i;
          }
        }

        for (final radix in [2, 3, 4]) {
          final extrema = Extrema(logics, max: max, radix: radix);
          await extrema.build();
          expect(extrema.val.value.toInt(), values[expectedIndex],
              reason: 'trial=$trial max=$max radix=$radix values=$values');
          expect(extrema.index.value.toInt(), expectedIndex,
              reason: 'trial=$trial max=$max radix=$radix values=$values');
        }
      }
    }
  });
}
