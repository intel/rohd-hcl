// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// extrema_test.dart
// Tests for extrema.
//
// 2024 September 16
// Author: Roberto Torres <roberto.torres@intel.com>
//

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

  test('Empty List.', () async {
    // Create a list of Logic objects with
    final logics = List<Logic>.empty();

    // Try to create an instance of Extrema
    expect(() => Extrema(logics), throwsA(isA<RohdHclException>()));
  });
}
