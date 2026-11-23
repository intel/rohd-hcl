// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_attention_row_engine_test.dart
// Tests for Fixed Point Attention Row Engine.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('processes accepted rows with arbitrary input gaps', () async {
    final fixture = _RowAttentionFixture();
    await fixture.buildAndReset();
    await fixture.sendCommand(requestId: 5, query: [1, 0], laneMask: 0x3);
    await fixture.sendRow(key: [0, 0], values: [4, 0], active: true);
    await fixture.clk.nextPosedge;
    await fixture.clk.nextPosedge;
    await fixture.sendRow(key: [-1, 0], values: [0, 4], active: true);
    await fixture.sendRow(
      key: [-2, 0],
      values: [4, 4],
      active: true,
      last: true,
    );

    await fixture.waitForResult();
    expect(fixture.outputValues, [3, 2]);
    expect(fixture.result.data.requestId.value.toInt(), 5);
    expect(fixture.dut.rowsAccepted.value.toInt(), 3);
    expect(fixture.dut.scoreProducts.value.toInt(), 6);
    expect(fixture.dut.activeValues.value.toInt(), 3);
    expect(fixture.dut.rowWaitCycles.value.toInt(), greaterThanOrEqualTo(2));

    final retained = fixture.result.data.value;
    await fixture.clk.nextPosedge;
    expect(fixture.result.data.value, retained);
    fixture.result.ready.inject(1);
    await fixture.clk.nextPosedge;
    expect(fixture.result.valid.value, LogicValue.zero);
    await Simulator.endSimulation();
  });

  test('final inactive row produces an invalid zero result', () async {
    final fixture = _RowAttentionFixture();
    await fixture.buildAndReset();
    await fixture.sendCommand(requestId: 1, query: [1, 2], laneMask: 0x3);
    await fixture.sendRow(
      key: [3, 4],
      values: [5, 6],
      active: false,
      last: true,
    );
    await fixture.waitForResult();

    expect(fixture.outputValues, [0, 0]);
    expect(fixture.result.data.invalidInput.value, LogicValue.one);
    expect(fixture.dut.rowsAccepted.value.toInt(), 1);
    expect(fixture.dut.activeValues.value.toInt(), 0);
    await Simulator.endSimulation();
  });
}

class _RowAttentionFixture {
  final Logic clk = SimpleClockGenerator(10).clk;
  final Logic reset = Logic();
  final ReadyValidInterface<FixedPointAttentionRowCommand> command =
      ReadyValidInterface(
    FixedPointAttentionRowCommand(
      headDimension: 2,
      elementWidth: 4,
      requestIdWidth: 3,
    ),
  );
  final ReadyValidInterface<FixedPointAttentionRow> rows = ReadyValidInterface(
    FixedPointAttentionRow(
      headDimension: 2,
      valueDimension: 2,
      elementWidth: 4,
      valueWidth: 8,
    ),
  );
  final ReadyValidInterface<FixedPointAttentionResult> result =
      ReadyValidInterface(
    FixedPointAttentionResult(
      valueDimension: 2,
      outputWidth: 8,
      requestIdWidth: 3,
    ),
  );
  late final FixedPointAttentionRowEngine dut;

  _RowAttentionFixture() {
    dut = FixedPointAttentionRowEngine(
      clk: clk,
      reset: reset,
      command: command,
      rows: rows,
      result: result,
      elementFractionBits: 0,
      valueFractionBits: 0,
      scoreWidth: 6,
      scoreFractionBits: 0,
      normalizerWidth: 10,
      normalizerFractionBits: 6,
      expWidth: 8,
      expFractionBits: 6,
      reciprocalWidth: 10,
      reciprocalFractionBits: 8,
      outputWidth: 8,
      counterWidth: 16,
    );
  }

  List<int> get outputValues => [
        for (final value in result.data.values.value.arrayValues)
          value.toBigInt().toSigned(8).toInt(),
      ];

  Future<void> buildAndReset() async {
    await dut.build();
    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());
    reset.inject(1);
    command.valid.inject(0);
    command.data.inject(0);
    rows.valid.inject(0);
    rows.data.inject(0);
    result.ready.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
  }

  Future<void> sendCommand({
    required int requestId,
    required List<int> query,
    required int laneMask,
  }) async {
    command.data.requestId.inject(requestId);
    command.data.laneMask.inject(laneMask);
    for (var lane = 0; lane < query.length; lane++) {
      command.data.query.arrayElements[lane].inject(
        BigInt.from(query[lane]).toUnsigned(command.data.elementWidth),
      );
    }
    command.valid.inject(1);
    await _waitForHigh(command.ready, 'command ready');
    await clk.nextPosedge;
    command.valid.inject(0);
  }

  Future<void> sendRow({
    required List<int> key,
    required List<int> values,
    required bool active,
    bool last = false,
  }) async {
    for (var lane = 0; lane < key.length; lane++) {
      rows.data.key.arrayElements[lane].inject(
        BigInt.from(key[lane]).toUnsigned(rows.data.elementWidth),
      );
    }
    for (var lane = 0; lane < values.length; lane++) {
      rows.data.values.arrayElements[lane].inject(
        BigInt.from(values[lane]).toUnsigned(rows.data.valueWidth),
      );
    }
    rows.data.active.inject(active ? 1 : 0);
    rows.data.last.inject(last ? 1 : 0);
    rows.valid.inject(1);
    await _waitForHigh(rows.ready, 'row ready');
    await clk.nextPosedge;
    rows.valid.inject(0);
  }

  Future<void> waitForResult() async {
    await _waitForHigh(result.valid, 'attention result');
  }

  Future<void> _waitForHigh(Logic signal, String description) async {
    for (var cycle = 0; cycle < 20 && signal.value != LogicValue.one; cycle++) {
      await clk.nextNegedge;
    }
    expect(signal.value, LogicValue.one,
        reason: 'Timed out waiting for $description.');
  }
}
