// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_tile_buffer_test.dart
// Tests for Tensor Tile Buffer.
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

  test('buffers two typed tiles while the consumer is stalled', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final format = InferenceNumericFormat.signedInteger(8);
    final upstream = ReadyValidInterface(
      inferenceLogicTensorTile(
        rowCount: 2,
        columnCount: 2,
        format: format,
        name: 'upstreamTile',
      ),
    );
    final downstream = ReadyValidInterface(
      inferenceLogicTensorTile(
        rowCount: 2,
        columnCount: 2,
        format: format,
        name: 'downstreamTile',
      ),
    );
    final queue = tensorPingPongBuffer(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstream: downstream,
    );
    await queue.build();
    unawaited(Simulator.run());
    reset.inject(1);
    upstream.valid.inject(0);
    upstream.data.inject(0);
    downstream.ready.inject(0);
    await clk.nextPosedge;
    reset.inject(0);

    await _sendTile(clk, upstream, [1, 2, 3, 4], rowMask: 3, columnMask: 3);
    await _sendTile(clk, upstream, [5, 6, 7, 8], rowMask: 1, columnMask: 3);
    _driveTile(upstream.data, [9, 10, 11, 12], rowMask: 3, columnMask: 1);
    upstream.valid.inject(1);
    await clk.nextNegedge;
    expect(upstream.ready.value, LogicValue.zero);
    expect(queue.occupancy.value.toInt(), 2);
    expect(_tileValues(downstream.data), [1, 2, 3, 4]);

    downstream.ready.inject(1);
    await clk.nextPosedge;
    upstream.valid.inject(0);
    await clk.nextNegedge;
    expect(_tileValues(downstream.data), [5, 6, 7, 8]);
    expect(downstream.data.rowMask.value.toInt(), 1);
    await Simulator.endSimulation();
  });
}

Future<void> _sendTile(
  Logic clk,
  ReadyValidInterface<InferenceTensorTile<Logic, LogicValue>> upstream,
  List<int> values, {
  required int rowMask,
  required int columnMask,
}) async {
  _driveTile(
    upstream.data,
    values,
    rowMask: rowMask,
    columnMask: columnMask,
  );
  upstream.valid.inject(1);
  while (upstream.ready.value != LogicValue.one) {
    await clk.nextNegedge;
  }
  await clk.nextPosedge;
  upstream.valid.inject(0);
  await clk.nextNegedge;
}

void _driveTile(
  InferenceTensorTile<Logic, LogicValue> tile,
  List<int> values, {
  required int rowMask,
  required int columnMask,
}) {
  for (var index = 0; index < values.length; index++) {
    tile.data.arrayElements[index].inject(values[index]);
  }
  tile.rowMask.inject(rowMask);
  tile.columnMask.inject(columnMask);
}

List<int> _tileValues(InferenceTensorTile<Logic, LogicValue> tile) => [
      for (final value in tile.data.value.arrayValues) value.toInt(),
    ];
