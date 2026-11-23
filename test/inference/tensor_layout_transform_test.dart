// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_layout_transform_test.dart
// Tests for Tensor Layout Transform.
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

  test('transposes typed tile data and exchanges runtime masks', () async {
    final input = _tile(rows: 2, columns: 3, name: 'inputTile');
    final dut = TensorTileTranspose<Logic, LogicValue>(input);
    await dut.build();
    unawaited(Simulator.run());

    _driveTile(input, [1, 2, 3, 4, 5, 6], rowMask: 0x1, columnMask: 0x5);
    await Simulator.tick();
    expect(_tileValues(dut.result), [1, 4, 2, 5, 3, 6]);
    expect(dut.result.rowCount, 3);
    expect(dut.result.columnCount, 2);
    expect(dut.result.rowMask.value.toInt(), 0x5);
    expect(dut.result.columnMask.value.toInt(), 0x1);
    await Simulator.endSimulation();
  });

  test('untiler emits row-major framed elements with repeated mask metadata',
      () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final upstream = ReadyValidInterface(
      _tile(rows: 2, columns: 3, name: 'untilerInput'),
    );
    final downstream = ReadyValidInterface(
      Frame(
        InferenceTensorStreamElement(
          Logic(name: 'elementData', width: 8),
          rowCount: 2,
          columnCount: 3,
        ),
      ),
    );
    final dut = TensorTileUntiler<Logic, LogicValue>(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstream: downstream,
    );
    await dut.build();
    unawaited(Simulator.run());
    reset.inject(1);
    upstream.valid.inject(0);
    upstream.data.inject(0);
    downstream.ready.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextNegedge;

    _driveTile(
      upstream.data,
      [1, 2, 3, 4, 5, 6],
      rowMask: 0x1,
      columnMask: 0x5,
    );
    upstream.valid.inject(1);
    await _waitForHigh(clk, upstream.ready, 'untiler input ready');
    await clk.nextPosedge;
    await clk.nextNegedge;
    upstream.valid.inject(0);

    for (var index = 0; index < 6; index++) {
      await _waitForHigh(clk, downstream.valid, 'untiler element $index');
      expect(downstream.data.data.data.value.toInt(), index + 1);
      expect(
        downstream.data.data.rowActive.value.toInt(),
        index ~/ 3 == 0 ? 1 : 0,
      );
      expect(
        downstream.data.data.columnActive.value.toInt(),
        const [1, 0, 1][index % 3],
      );
      expect(
        downstream.data.last.value,
        index == 5 ? LogicValue.one : LogicValue.zero,
      );
      final retained = downstream.data.value;
      if (index == 1) {
        await clk.nextPosedge;
        await clk.nextNegedge;
        expect(downstream.data.value, retained);
      }
      downstream.ready.inject(1);
      await clk.nextPosedge;
      await clk.nextNegedge;
      downstream.ready.inject(0);
    }
    expect(dut.active.value, LogicValue.zero);
    await Simulator.endSimulation();
  });

  test('tiler diagnoses malformed frame length and inconsistent masks',
      () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final upstream = ReadyValidInterface(
      Frame(
        InferenceTensorStreamElement(
          Logic(name: 'elementData', width: 8),
          rowCount: 2,
          columnCount: 3,
        ),
      ),
    );
    final downstream = ReadyValidInterface(
      _tile(rows: 2, columns: 3, name: 'tilerOutput'),
    );
    final dut = TensorTileTiler<Logic, LogicValue>(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstream: downstream,
    );
    await dut.build();
    unawaited(Simulator.run());
    reset.inject(1);
    upstream.valid.inject(0);
    upstream.data.inject(0);
    downstream.ready.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextNegedge;

    for (var index = 0; index < 6; index++) {
      await _sendElement(
        clk,
        upstream,
        data: index + 1,
        rowActive: index == 4 ? 0 : 1,
        columnActive: 1,
        last: index == 5,
      );
    }
    await _waitForHigh(clk, downstream.valid, 'inconsistent tile');
    expect(dut.framingError.value, LogicValue.zero);
    expect(dut.maskInconsistent.value, LogicValue.one);
    expect(dut.collectedElements.value.toInt(), 6);
    expect(downstream.data.rowMask.value.toInt(), 0);
    expect(downstream.data.columnMask.value.toInt(), 0);
    downstream.ready.inject(1);
    await clk.nextPosedge;
    await clk.nextNegedge;
    downstream.ready.inject(0);

    for (var index = 0; index < 3; index++) {
      await _sendElement(
        clk,
        upstream,
        data: index + 7,
        rowActive: 1,
        columnActive: 1,
        last: index == 2,
      );
    }
    await _waitForHigh(clk, downstream.valid, 'short tile');
    expect(dut.framingError.value, LogicValue.one);
    expect(dut.maskInconsistent.value, LogicValue.zero);
    expect(dut.collectedElements.value.toInt(), 3);
    expect(downstream.data.rowMask.value.toInt(), 0);
    expect(downstream.data.columnMask.value.toInt(), 0);
    await Simulator.endSimulation();
  });

  test('untiler and tiler round-trip a masked tile through a framed stream',
      () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final upstream = ReadyValidInterface(
      _tile(rows: 2, columns: 3, name: 'roundTripInput'),
    );
    final downstream = ReadyValidInterface(
      _tile(rows: 2, columns: 3, name: 'roundTripOutput'),
    );
    final dut = _TensorTileRoundTrip(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstream: downstream,
    );
    await dut.build();
    unawaited(Simulator.run());
    reset.inject(1);
    upstream.valid.inject(0);
    upstream.data.inject(0);
    downstream.ready.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextNegedge;

    _driveTile(
      upstream.data,
      [0x10, 0x11, 0x12, 0x20, 0x21, 0x22],
      rowMask: 0x3,
      columnMask: 0x3,
    );
    upstream.valid.inject(1);
    await _waitForHigh(clk, upstream.ready, 'round-trip input ready');
    await clk.nextPosedge;
    await clk.nextNegedge;
    upstream.valid.inject(0);
    await _waitForHigh(clk, downstream.valid, 'round-trip output');
    expect(_tileValues(downstream.data), [0x10, 0x11, 0x12, 0x20, 0x21, 0x22]);
    expect(downstream.data.rowMask.value.toInt(), 0x3);
    expect(downstream.data.columnMask.value.toInt(), 0x3);
    expect(dut.framingError.value, LogicValue.zero);
    expect(dut.maskInconsistent.value, LogicValue.zero);
    await Simulator.endSimulation();
  });
}

class _TensorTileRoundTrip extends Module {
  Logic get framingError => output('framingError');

  Logic get maskInconsistent => output('maskInconsistent');

  _TensorTileRoundTrip({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<InferenceTensorTile<Logic, LogicValue>>
        upstream,
    required ReadyValidInterface<InferenceTensorTile<Logic, LogicValue>>
        downstream,
  }) : super(definitionName: 'TensorTileRoundTrip') {
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localUpstream = addPairInterface(
      upstream,
      PairRole.consumer,
      uniquify: (original) => 'upstream_$original',
    );
    final localDownstream = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(downstream.data.clone()),
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );
    final stream = ReadyValidInterface(
      Frame(
        InferenceTensorStreamElement(
          Logic(name: 'streamData', width: upstream.data.format.elementWidth),
          rowCount: upstream.data.rowCount,
          columnCount: upstream.data.columnCount,
        ),
      ),
    );
    TensorTileUntiler<Logic, LogicValue>(
      clk: localClk,
      reset: localReset,
      upstream: localUpstream,
      downstream: stream,
      name: 'untiler',
    );
    final tiler = TensorTileTiler<Logic, LogicValue>(
      clk: localClk,
      reset: localReset,
      upstream: stream,
      downstream: localDownstream,
      name: 'tiler',
    );
    addOutput('framingError') <= tiler.framingError;
    addOutput('maskInconsistent') <= tiler.maskInconsistent;
  }
}

InferenceTensorTile<Logic, LogicValue> _tile({
  required int rows,
  required int columns,
  required String name,
}) =>
    inferenceLogicTensorTile(
      rowCount: rows,
      columnCount: columns,
      format: InferenceNumericFormat.unsignedInteger(8),
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

List<int> _tileValues(InferenceTensorTile<Logic, LogicValue> tile) => [
      for (final element in tile.data.value.arrayValues) element.toInt(),
    ];

Future<void> _sendElement(
  Logic clk,
  ReadyValidInterface<Frame<InferenceTensorStreamElement<Logic>>> upstream, {
  required int data,
  required int rowActive,
  required int columnActive,
  required bool last,
}) async {
  upstream.data.data.data.inject(data);
  upstream.data.data.rowActive.inject(rowActive);
  upstream.data.data.columnActive.inject(columnActive);
  upstream.data.last.inject(last ? 1 : 0);
  upstream.valid.inject(1);
  await _waitForHigh(clk, upstream.ready, 'tiler input ready');
  await clk.nextPosedge;
  await clk.nextNegedge;
  upstream.valid.inject(0);
}

Future<void> _waitForHigh(
  Logic clk,
  Logic signal,
  String description,
) async {
  for (var cycle = 0; cycle < 50; cycle++) {
    if (signal.value == LogicValue.one) {
      return;
    }
    await clk.nextNegedge;
  }
  fail('Timed out waiting for $description.');
}
