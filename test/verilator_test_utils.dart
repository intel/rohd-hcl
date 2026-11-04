// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// verilator_test_utils.dart
// Utilities for checking generated HDL with Verilator.
//
// 2026 November 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:test/test.dart';

void expectNoVerilatorWarnings(Module dut, List<String> warningNames) {
  final dir = Directory.systemTemp.createTempSync('rohd_hcl_verilator_');
  try {
    final source = File('${dir.path}/design.sv')
      ..writeAsStringSync(dut.dumpSystemVerilog());
    final lint = Process.runSync('verilator', [
      '--lint-only',
      '-Wno-fatal',
      '--top-module',
      dut.definitionName,
      source.path,
    ]);
    final output = '${lint.stdout}\n${lint.stderr}';
    expect(lint.exitCode, 0, reason: output);
    for (final warning in warningNames) {
      expect(output, isNot(contains('Warning-$warning')), reason: output);
    }
  } finally {
    dir.deleteSync(recursive: true);
  }
}
