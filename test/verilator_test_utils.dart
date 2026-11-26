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
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:test/test.dart';

/// Verilator arguments that shorten the C++ build of a test.
///
/// The vectors of a test simulate in no time, so the model and Verilator's
/// runtime are compiled without optimization, which for a long list of
/// vectors is most of the build. With `ccache` installed, compiled objects
/// are reused: Verilator's runtime is the same for every design, and
/// compiling it is most of building a small one.
final List<String> verilatorBuildArguments = [
  for (final flags in ['OPT_FAST', 'OPT_GLOBAL']) ...[
    '-MAKEFLAGS',
    '$flags=-O0'
  ],
  if (_haveCcache()) ...['-MAKEFLAGS', 'OBJCACHE=ccache'],
];

bool _haveCcache() {
  try {
    return Process.runSync('ccache', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// Checks [vectors] on [dut] in Verilator as
/// [SimCompare.checkVerilatorVector] does, with [verilatorBuildArguments].
bool checkVerilatorVector(Module dut, List<Vector> vectors) =>
    SimCompare.checkVerilatorVector(dut, vectors,
        verilatorExtraArgs: verilatorBuildArguments);

void expectNoVerilatorWarnings(Module dut, List<String> warningNames) {
  try {
    Process.runSync('verilator', ['--version']);
  } on ProcessException catch (error) {
    if (error.errorCode != 2) {
      rethrow;
    }
    const reason = 'Verilator executable not found.';
    if (Platform.environment['ROHD_REQUIRE_VERILATOR'] == '1') {
      fail(reason);
    }
    markTestSkipped(reason);
    return;
  }
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
