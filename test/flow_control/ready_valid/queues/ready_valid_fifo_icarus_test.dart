// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_fifo_icarus_test.dart
// Generated-RTL coverage for ReadyValidFifo admission policies.
// ignore_for_file: deprecated_member_use_from_same_package
//
// 2026 October 30
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

ReadyValidFifo<Logic> _fifo({required bool allowSameCycleReplacement}) =>
    ReadyValidFifo<Logic>(
      clk: Logic(),
      reset: Logic(),
      upstream: ReadyAndValidInterface(
        Logic(name: 'input', width: 8),
      ),
      downstream: ReadyValidInterface(
        Logic(name: 'output', width: 8),
      ),
      depth: 1,
      allowSameCycleReplacement: allowSameCycleReplacement,
    );

void main() {
  test('full-replacement ReadyValidFifo compiles in Icarus', () async {
    final conservative = _fifo(allowSameCycleReplacement: false);
    final replacement = _fifo(allowSameCycleReplacement: true);
    expect(replacement.definitionName, isNot(conservative.definitionName));
    expect(replacement.definitionName, startsWith('ReadyValidFifo_R1_'));

    await replacement.build();
    final directory =
        Directory.systemTemp.createTempSync('rohd_hcl_ready_valid_fifo_');
    final source = File('${directory.path}/ready_valid_fifo.sv');
    try {
      source.writeAsStringSync(replacement.dumpSystemVerilog());
      final result =
          Process.runSync('iverilog', ['-g2012', '-tnull', source.path]);
      expect(
        result.exitCode,
        0,
        reason: '${result.stdout}\n${result.stderr}',
      );
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
}
