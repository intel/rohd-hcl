// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// legacy_gaskets_import_test.dart
// Verifies the deprecated gasket barrel remains available.
//
// 2026 November 5
// Author: GitHub Copilot

// This test exercises the legacy import path.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/gaskets/gaskets.dart' as legacy;
import 'package:test/test.dart';

void main() {
  test('legacy gasket barrel exports the current endpoint types', () {
    expect(legacy.SpiMain, SpiMain);
    expect(legacy.SpiSub, SpiSub);
    expect(legacy.ApbCsrCompleter, ApbCsrCompleter);
  });
}
