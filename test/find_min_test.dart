// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// find_min_test.dart
// Implementation of Find Minimum module.
//
// 2024 September 10
// Author: Roberto Torres <roberto.torres@intel.com>
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';
import 'package:rohd_hcl/src/find_min.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });
  group('first group of tests', () {
    test('FindMin finds the minimum value correctly', () async {
      // Create a list of Logic objects with different values
      List<Logic> logics = [
        Logic(width: 8)..put(LogicValue.ofString('01101101')), // 109 in decimal
        Logic(width: 8)..put(LogicValue.ofString('00000101')), // 5 in decimal
        Logic(width: 8)..put(LogicValue.ofString('00010100')), // 20 in decimal
        Logic(width: 8)..put(LogicValue.ofString('00000011')), // 3 in decimal
        Logic(width: 8)..put(LogicValue.ofString('00001111')) // 15 in decimal
      ];

      // Create an instance of FindMin
      FindMin findMin = FindMin(logics);

      // Verify the minimum value and index
      expect(findMin.val.value.toInt(), equals(3));
      expect(findMin.index.value.toInt(), equals(3));
    });

    // Test including x,z

    // Test with null
  });
}
