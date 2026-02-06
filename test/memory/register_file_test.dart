// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// register_file_test.dart
// Tests for register file
//
// 2025 September 3
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  group('rf exceptions', () {
    test('mismatch addr width', () {
      expect(
          () => RegisterFile(
                Logic(),
                Logic(),
                [DataPortInterface(32, 31)],
                [DataPortInterface(32, 32)],
              ),
          throwsA(const TypeMatcher<RohdHclException>()));
    });

    test('mismatch data width', () {
      expect(
          () => RegisterFile(
                Logic(),
                Logic(),
                [DataPortInterface(64, 32)],
                [DataPortInterface(32, 32)],
              ),
          throwsA(const TypeMatcher<RohdHclException>()));
    });

    test('required minimum ports', () {
      RegisterFile(Logic(), Logic(), [], [DataPortInterface(32, 32)]);
      RegisterFile(Logic(), Logic(), [DataPortInterface(32, 32)], []);

      try {
        RegisterFile(Logic(), Logic(), [], []);
        fail('Should have failed');
      } on RohdHclException catch (_) {}
    });
  });
}
