// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// memory_model_snapshot_test.dart
// Tests snapshots of delayed behavioral memory reads.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Harness extends Module {
  late final MemoryModel<Logic> memory;

  _Harness({int latency = 3}) {
    final read = DataPortInterface<Logic>(8, 8);
    read.en <= addInput('en', Logic());
    read.addr <= addInput('addr', Logic(width: 8), width: 8);
    memory = MemoryModel<Logic>(
      addInput('clk', Logic()),
      addInput('reset', Logic()),
      [],
      [read],
      readLatency: latency,
      asyncReset: false,
    );
    addOutput('data', width: 8) <= read.data;
  }
}

void main() {
  tearDown(Simulator.reset);

  test('restores a delayed read and invalidates later scheduled reads',
      () async {
    final dut = _Harness();
    late MemoryModelImage image;
    Simulator.registerAction(21, () {
      MemoryStorageState(dut.memory.storage).poke(5, LogicValue.ofInt(0xa5, 8));
    });
    Simulator.registerAction(41, () {
      image = dut.memory.snapshot();
      expect(image.pendingReadCount, 1);
    });
    Simulator.registerAction(81, () {
      expect(dut.output('data').value, LogicValue.ofInt(0xa5, 8));
      MemoryStorageState(dut.memory.storage).poke(5, LogicValue.ofInt(0x33, 8));
      dut.memory.restore(image);
      expect(MemoryStorageState(dut.memory.storage).peek(5),
          LogicValue.ofInt(0xa5, 8));
    });
    final vectors = [
      Vector({'clk': 0, 'reset': 1, 'en': 0, 'addr': 0}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'en': 1, 'addr': 5}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'en': 0}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0}, {'data': LogicValue.z}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0}, {'data': LogicValue.z}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0}, {'data': 0xa5}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
  });

  test('state endpoint rejects images from different read latencies', () {
    final first = _Harness();
    final second = _Harness(latency: 2);
    MemoryStorageState(first.memory.storage).poke(1, LogicValue.ofInt(3, 8));
    MemoryStorageState(second.memory.storage).poke(1, LogicValue.ofInt(7, 8));
    final captured = first.memory.stateTransactions.transact(
        StateTransactionRequest<MemoryModelImage>.snapshot(transactionId: 3));
    expect(captured.transactionId, 3);
    expect(
        () => second.memory.stateTransactions.transact(
            StateTransactionRequest<MemoryModelImage>.restore(
                transactionId: 4, image: captured.image!)),
        throwsArgumentError);
    expect(MemoryStorageState(second.memory.storage).peek(1),
        LogicValue.ofInt(7, 8));
  });

  test('restores several overlapping reads in their original order', () async {
    final dut = _Harness();
    late MemoryModelImage image;
    Simulator.registerAction(21, () {
      MemoryStorageState(dut.memory.storage)
        ..poke(5, LogicValue.ofInt(0xa5, 8))
        ..poke(6, LogicValue.ofInt(0xb6, 8));
    });
    Simulator.registerAction(61, () {
      image = dut.memory.snapshot();
      expect(image.pendingReadCount, 2);
    });
    Simulator.registerAction(111, () => dut.memory.restore(image));
    final vectors = [
      Vector({'clk': 0, 'reset': 1, 'en': 0, 'addr': 0}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'en': 1, 'addr': 5}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'addr': 6}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'en': 0}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0}, {'data': 0xa5}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0}, {'data': 0xb6}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0}, {'data': 0xa5}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0}, {'data': 0xb6}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
  });
}
