// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// static_or_runtime_control_test.dart
// Tests for static-or-runtime control API compatibility.
//
// 2026 September 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

// ignore: deprecated_member_use_from_same_package
import 'package:rohd_hcl/src/static_or_runtime_parameter.dart';
import 'package:test/test.dart';

void main() {
  test('legacy static-or-runtime import path remains available', () {
    final parameter =
        StaticOrRuntimeParameter(name: 'enabled', staticConfig: true);

    expect(parameter.staticConfig, isTrue);
  });
}
