// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// systemc_test_utils.dart
// Availability checks for tests that compile native SystemC harnesses.
//
// 2026 November 20
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';

import 'package:test/test.dart';

/// Why the native SystemC test harness cannot compile, or null if available.
final String? systemCUnavailable = _probeSystemC();

/// Skips the current check if the native SystemC toolchain is unavailable.
bool canRunSystemC() {
  final reason = systemCUnavailable;
  if (reason == null) {
    return true;
  }
  if (Platform.environment['ROHD_REQUIRE_SYSTEMC'] == '1') {
    fail(reason);
  }
  markTestSkipped(reason);
  return false;
}

String? _probeSystemC() {
  final directory = Directory.systemTemp.createTempSync('hcl_systemc_probe_');
  try {
    final source = File('${directory.path}/probe.cpp')
      ..writeAsStringSync('#include <systemc>\n'
          'int sc_main(int, char**) { return 0; }\n');
    final result = Process.runSync('g++', [
      '-std=c++17',
      source.path,
      '-lsystemc',
      '-o',
      '${directory.path}/probe',
    ]);
    if (result.exitCode == 0) {
      return null;
    }
    return 'SystemC compile/link probe failed:\n${result.stderr}';
  } on ProcessException catch (error) {
    if (error.errorCode != 2) {
      rethrow;
    }
    return 'g++ not found; cannot run SystemC checks.';
  } finally {
    directory.deleteSync(recursive: true);
  }
}
