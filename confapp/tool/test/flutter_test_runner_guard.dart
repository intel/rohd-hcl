// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// flutter_test_runner_guard.dart
// Directs Confapp tests to the Flutter test runner.
//
// 2026 November 7
// Author: GitHub Copilot

import 'package:test/test.dart';

void main() {
  test('Use the Flutter test runner for Confapp', () {
    fail(
      'Confapp is a Flutter package; dart test cannot run its Flutter tests.\n'
      'Run `flutter test` from the confapp directory instead.',
    );
  });
}
