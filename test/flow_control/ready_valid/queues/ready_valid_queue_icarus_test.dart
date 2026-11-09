// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_queue_icarus_test.dart
// Generated RTL coverage for ready/valid queues.
//
// 2026 November 5
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _QueueHarness extends Module {
  _QueueHarness(ReadyValidQueueStorage storage, ReadyValidQueuePolicy policy) {
    final upstream = ReadyValidInterface(Logic(name: 'input', width: 8));
    final downstream = ReadyValidInterface(Logic(name: 'output', width: 8));
    upstream.data <= addInput('data', Logic(width: 8), width: 8);
    upstream.valid <= addInput('valid', Logic());
    downstream.ready <= addInput('ready', Logic());
    final queue = ReadyValidQueue<Logic>(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      upstream: upstream,
      downstream: downstream,
      depth: 1,
      policy: policy,
      storage: storage,
    );
    addOutput('out', width: 8) <= downstream.data;
    addOutput('outValid') <= downstream.valid;
    addOutput('inReady') <= upstream.ready;
    addOutput('full') <= queue.full;
  }
}

void main() {
  tearDown(Simulator.reset);

  for (final storage in ReadyValidQueueStorage.values) {
    for (final policy in ReadyValidQueuePolicy.values) {
      test('$storage $policy matches Icarus on full replacement', () async {
        final dut = _QueueHarness(storage, policy);
        final vectors = [
          Vector(
              {'clk': 0, 'reset': 1, 'data': 17, 'valid': 0, 'ready': 0}, {}),
          Vector({'clk': 1}, {'full': 0}),
          Vector({'clk': 0, 'reset': 0, 'valid': 1}, {'inReady': 1}),
          Vector({'clk': 1}, {'full': 1, 'outValid': 1, 'out': 17}),
          Vector({'clk': 0, 'data': 34, 'ready': 1}, {'inReady': 1, 'out': 17}),
          Vector({'clk': 1}, {'full': 1, 'out': 34}),
          Vector({'clk': 0, 'valid': 0}, {}),
          Vector({'clk': 1}, {'full': 0, 'outValid': 0}),
        ];
        await dut.build();
        await SimCompare.checkFunctionalVector(dut, vectors);
        SimCompare.checkIverilogVector(dut, vectors);
      });
    }
  }
}
