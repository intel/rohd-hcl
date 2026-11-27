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

import 'dart:async';
import 'dart:convert';

import 'package:rohd/rohd.dart';
import 'package:test/test.dart';

import '../../tool/csr_model_benchmark.dart' as benchmark;

void main() {
  tearDown(Simulator.reset);

  for (final software in [false, true]) {
    test('YAML benchmark runs with ${software ? 'software' : 'RTL'} CSR',
        () async {
      // The benchmark runs in this process. Starting it with `dart run`
      // compiled it again for each test, which under a loaded machine took
      // most of the time a test is allowed.
      final printed = <String>[];
      await runZoned(
          () => benchmark.main([
                '--yaml=test/tool/fixtures/csr_model_benchmark.yaml',
                if (software) '--software',
              ]),
          zoneSpecification: ZoneSpecification(
              print: (self, parent, zone, line) => printed.add(line)));
      final output = jsonDecode(printed.single) as Map<String, dynamic>;
      expect(output['implementation'], software ? 'software' : 'rtl');
      expect(output['blocks'], 1);
      expect(output['registers'], 2);
      expect(output['simulation_1000_cycles_us'], greaterThan(0));
      expect(output['systemc_bytes'], software ? greaterThan(0) : isNull);
    });
  }
}
