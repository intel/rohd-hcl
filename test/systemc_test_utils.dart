// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// systemc_test_utils.dart
// Availability checks and a shared precompiled header for tests that
// compile native SystemC harnesses.
//
// 2026 November 20
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

/// Why the native SystemC test harness cannot compile, or null if available.
final String? systemCUnavailable = _systemC.unavailable;

/// Compiler arguments that make a SystemC harness use a `<systemc>` header
/// precompiled once for all tests, to go before the source file.
///
/// Parsing `<systemc>` is most of what compiling a small harness costs. The
/// precompiled header includes nothing else, so a harness is compiled exactly
/// as it would be without these arguments; they need `-std=c++17` and no
/// optimization, and the compiler reads `<systemc>` itself if they do not
/// apply.
List<String> get systemCHeaderArguments => _systemC.headerArguments;

/// Skips the current check if the native SystemC toolchain is unavailable.
bool canRunSystemC() {
  final reason = systemCUnavailable;
  if (reason == null) {
    return true;
  }
  if (Platform.environment['ROHD_REQUIRE_SYSTEMC'] == '1') {
    fail(reason);
  }
  markTestSkipped(
      'Optional SystemC checks skipped: native toolchain unavailable. '
      'Set ROHD_REQUIRE_SYSTEMC=1 to require it '
      'and show the probe diagnostic.');
  return false;
}

final _SystemCToolchain _systemC = _SystemCToolchain.probe();

/// The native SystemC toolchain, probed once for each test file.
class _SystemCToolchain {
  /// Why SystemC cannot be compiled and linked, or null if it can.
  final String? unavailable;

  /// See [systemCHeaderArguments].
  final List<String> headerArguments;

  const _SystemCToolchain._(this.unavailable, this.headerArguments);

  static const _compiler = 'g++';
  static const _standard = '-std=c++17';
  static const _header = 'rohd_hcl_systemc.h';

  /// Where precompiled headers are kept, beside ROHD's own in `tmp_test`.
  static const _cache = 'tmp_test/systemc_pch';

  /// Finds the precompiled header for this compiler and SystemC
  /// installation, building it and checking that a harness links on first
  /// use.
  ///
  /// Test files run in parallel. The header is built in a directory of its
  /// own and renamed into place, so that no compiler reads a partial one.
  factory _SystemCToolchain.probe() {
    final scratch = Directory(_cache)..createSync(recursive: true);
    final building = scratch.createTempSync('building_');
    try {
      final header = File('${building.path}/$_header')
        ..writeAsStringSync('#include <systemc>\n');
      final ProcessResult version;
      try {
        version = Process.runSync(_compiler, ['--version']);
      } on ProcessException catch (error) {
        if (error.errorCode != 2) {
          rethrow;
        }
        return const _SystemCToolchain._(
            '$_compiler not found; cannot run SystemC checks.', []);
      }
      final dependencies = Process.runSync(
          _compiler, [_standard, '-x', 'c++-header', '-M', header.path]);
      if (dependencies.exitCode != 0) {
        return _SystemCToolchain._failed(dependencies);
      }

      // A precompiled header is not checked against the headers it was made
      // from, so the compiler and every header read identify it here.
      final identity = StringBuffer(version.stdout.toString());
      for (final path in dependencies.stdout.toString().split(RegExp(r'\s+'))) {
        if (path.startsWith('/') && path != header.absolute.path) {
          final stat = File(path).statSync();
          identity.writeln('$path ${stat.size} ${stat.modified}');
        }
      }
      final ready = Directory(
          '$_cache/${sha256.convert(utf8.encode(identity.toString()))}');
      final arguments = ['-include', '${ready.absolute.path}/$_header'];
      if (ready.existsSync()) {
        return _SystemCToolchain._(null, arguments);
      }

      final precompile = Process.runSync(_compiler, [
        _standard,
        '-x',
        'c++-header',
        header.path,
        '-o',
        '${header.path}.gch',
      ]);
      if (precompile.exitCode != 0) {
        return _SystemCToolchain._failed(precompile);
      }
      final source = File('${building.path}/probe.cpp')
        ..writeAsStringSync('#include <systemc>\n'
            'int sc_main(int, char**) { return 0; }\n');
      final link = Process.runSync(_compiler, [
        _standard,
        '-include',
        header.path,
        source.path,
        '-lsystemc',
        '-o',
        '${building.path}/probe',
      ]);
      if (link.exitCode != 0) {
        return _SystemCToolchain._failed(link);
      }
      for (final name in ['probe.cpp', 'probe']) {
        File('${building.path}/$name').deleteSync();
      }
      try {
        building.renameSync(ready.path);
      } on FileSystemException {
        // Another test file finished building the same header first.
      }
      return _SystemCToolchain._(null, arguments);
    } finally {
      if (building.existsSync()) {
        building.deleteSync(recursive: true);
      }
    }
  }

  _SystemCToolchain._failed(ProcessResult result)
      : this._(
            'SystemC compile/link probe failed:\n${result.stderr}', const []);
}
