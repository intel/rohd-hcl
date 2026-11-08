// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_model_benchmark_test.dart
// Tests the CSR benchmark YAML configuration path.
//
// 2026 November
// Author: ROHD-HCL contributors

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  for (final software in [false, true]) {
    test('YAML benchmark runs with ${software ? 'software' : 'RTL'} CSR',
        () async {
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        'tool/csr_model_benchmark.dart',
        '--yaml=test/tool/fixtures/csr_model_benchmark.yaml',
        if (software) '--software',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final output =
          jsonDecode(result.stdout as String) as Map<String, dynamic>;
      expect(output['implementation'], software ? 'software' : 'rtl');
      expect(output['blocks'], 1);
      expect(output['registers'], 2);
      expect(output['simulation_1000_cycles_us'], greaterThan(0));
      expect(output['systemc_bytes'], software ? greaterThan(0) : isNull);
    });
  }
}
