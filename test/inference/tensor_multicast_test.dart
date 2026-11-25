// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_multicast_test.dart
// Tests for Tensor Multicast.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/inference/tensor_multicast.dart'
    show TensorTileMulticast;
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test(
    'core loads a new tile on the final advance and consumes zero masks',
    () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic()..put(1);
      final load = Logic()..put(0);
      final advance = Logic(width: 2)..put(0);
      final selection = Logic(width: 2)..put(0);
      final tile = _tile('coreInput')..put(0);
      final dut = TensorTileMulticastCore(
        clk: clk,
        reset: reset,
        tile: tile,
        selection: selection,
        load: load,
        advance: advance,
      );
      await dut.build();
      unawaited(Simulator.run());
      await clk.nextNegedge;
      reset.inject(0);
      load.inject(1);
      selection.inject(3);
      _driveTile(tile, [1, 2, 3, 4], rowMask: 1, columnMask: 2);
      await clk.nextNegedge;
      expect(dut.outputValidMask.value.toInt(), 3);

      advance.inject(1);
      selection.inject(1);
      _driveTile(tile, [5, 6, 7, 8], rowMask: 2, columnMask: 1);
      await clk.nextNegedge;
      expect(dut.outputValidMask.value.toInt(), 2);
      expect(_tileValues(dut.retainedTile), [1, 2, 3, 4]);

      advance.inject(2);
      await clk.nextNegedge;
      expect(dut.outputValidMask.value.toInt(), 1);
      expect(_tileValues(dut.retainedTile), [5, 6, 7, 8]);

      advance.inject(1);
      selection.inject(0);
      await clk.nextNegedge;
      expect(dut.occupied.value, LogicValue.zero);
      await Simulator.endSimulation();
    },
  );

  test('delivers a tile once to each selected destination', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final upstream = ValidThenReadyInterface(_tile('upstreamTile'));
    final downstreams = [
      for (var index = 0; index < 3; index++)
        ReadyValidInterface(_tile('downstreamTile$index')),
    ];
    final destinationMask = Logic(width: 3);
    final dut = TensorTileMulticast<Logic, LogicValue>(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstreams: downstreams,
      destinationMask: destinationMask,
    );
    await dut.build();
    unawaited(Simulator.run());

    reset.inject(1);
    upstream.valid.inject(0);
    destinationMask.inject(0);
    for (final downstream in downstreams) {
      downstream.ready.inject(0);
    }
    await clk.nextPosedge;
    reset.inject(0);

    _driveTile(
      upstream.data,
      [0x11, 0x12, 0x21, 0x22],
      rowMask: 0x3,
      columnMask: 0x1,
    );
    destinationMask.inject(0x5);
    upstream.valid.inject(1);
    await clk.nextNegedge;
    expect(upstream.ready.value, LogicValue.one);
    await clk.nextPosedge;
    upstream.valid.inject(0);

    expect(dut.occupied.value, LogicValue.one);
    expect(downstreams[0].valid.value, LogicValue.one);
    expect(downstreams[1].valid.value, LogicValue.zero);
    expect(downstreams[2].valid.value, LogicValue.one);
    for (final index in [0, 2]) {
      expect(_tileValues(downstreams[index].data), [0x11, 0x12, 0x21, 0x22]);
      expect(downstreams[index].data.rowMask.value.toInt(), 0x3);
      expect(downstreams[index].data.columnMask.value.toInt(), 0x1);
    }

    downstreams[0].ready.inject(1);
    await clk.nextPosedge;
    downstreams[0].ready.inject(0);
    expect(downstreams[0].valid.value, LogicValue.zero);
    expect(downstreams[2].valid.value, LogicValue.one);
    expect(upstream.ready.value, LogicValue.zero);

    downstreams[2].ready.inject(1);
    await clk.nextPosedge;
    downstreams[2].ready.inject(0);
    expect(dut.occupied.value, LogicValue.zero);
    expect(upstream.ready.value, LogicValue.one);
    await Simulator.endSimulation();
  });

  test('omitted destination mask broadcasts to every destination', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final upstream = ValidThenReadyInterface(_tile('broadcastInput'));
    final downstreams = [
      ReadyValidInterface(_tile('broadcastOutput0')),
      ReadyValidInterface(_tile('broadcastOutput1')),
    ];
    final dut = TensorTileMulticast<Logic, LogicValue>(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstreams: downstreams,
    );
    await dut.build();
    unawaited(Simulator.run());

    reset.inject(1);
    upstream.valid.inject(0);
    for (final downstream in downstreams) {
      downstream.ready.inject(0);
    }
    await clk.nextPosedge;
    reset.inject(0);
    _driveTile(upstream.data, [1, 2, 3, 4], rowMask: 0x1, columnMask: 0x3);
    upstream.valid.inject(1);
    await clk.nextPosedge;
    upstream.valid.inject(0);

    expect(downstreams[0].valid.value, LogicValue.one);
    expect(downstreams[1].valid.value, LogicValue.one);
    await Simulator.endSimulation();
  });

  test('rejects a mismatched destination tile', () {
    expect(
      () => TensorTileMulticast<Logic, LogicValue>(
        clk: Logic(),
        reset: Logic(),
        upstream: ReadyValidInterface(_tile('shapeInput')),
        downstreams: [
          ReadyValidInterface(
            inferenceLogicTensorTile(
              rowCount: 1,
              columnCount: 4,
              format: InferenceNumericFormat.signedInteger(8),
              name: 'shapeOutput',
            ),
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}

InferenceTensorTile<Logic, LogicValue> _tile(String name) =>
    inferenceLogicTensorTile(
      rowCount: 2,
      columnCount: 2,
      format: InferenceNumericFormat.signedInteger(8),
      name: name,
    );

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

List<int> _tileValues(InferenceTensorTile<Logic, LogicValue> tile) =>
    tile.data.arrayElements.map((element) => element.value.toInt()).toList();
