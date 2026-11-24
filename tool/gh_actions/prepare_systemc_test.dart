// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// prepare_systemc_test.dart
// Initialize ROHD's shared SystemC cache before parallel CI tests.
//
// 2026 November 24
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:test/test.dart';

class _SystemCPchProbe extends Module {
  _SystemCPchProbe() {
    final value = addInput('value', Logic(width: 8), width: 8);
    addOutput('inverted', width: 8) <= ~value;
  }
}

void main() {
  test('prepare shared SystemC precompiled header', () async {
    final dut = _SystemCPchProbe();
    await dut.build();
    expect(
      SimCompare.checkSystemCVector(
        dut,
        [
          Vector({'value': 0x5a}, {'inverted': 0xa5}),
          Vector({'value': 0xa5}, {'inverted': 0x5a}),
        ],
        requireTool: true,
      ),
      isTrue,
    );

    // ROHD can fall back to uncached compilation when PCH creation fails.
    // CI must instead stop before parallel isolates attempt initialization.
    for (final artifact in ['systemc.h.gch', 'systemc.pch']) {
      expect(File('tmp_test/pch/$artifact').lengthSync(), greaterThan(0),
          reason: 'SystemC cache must be ready before parallel tests.');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
