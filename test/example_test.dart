// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// example_test.dart
// Tests that the examples run.
//
// 2024 September 24
// Author: Max Korbel <max.korbel@intel.com>

import 'package:test/test.dart';

import '../example/clock_gating_example.dart' as clock_gating_example;
import '../example/example.dart' as example;

void main() {
  test('examples run', () async {
    for (final exMain in [example.main, clock_gating_example.main]) {
      await exMain(noPrint: true);
    }
  });
}
