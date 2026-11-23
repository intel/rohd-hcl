// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// grouped_query_attention_distribution_test.dart
// Tests for Grouped Query Attention Distribution.
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

  test('maps MHA, GQA, and MQA heads to query destinations', () {
    const mha =
        GroupedQueryHeadMapping(queryHeadCount: 4, keyValueHeadCount: 4);
    expect(mha.destinationMask(0), BigInt.from(0x1));
    expect(mha.destinationMask(3), BigInt.from(0x8));

    const gqa =
        GroupedQueryHeadMapping(queryHeadCount: 8, keyValueHeadCount: 2);
    expect(gqa.destinationMask(0), BigInt.from(0x0f));
    expect(gqa.destinationMask(1), BigInt.from(0xf0));

    const mqa =
        GroupedQueryHeadMapping(queryHeadCount: 4, keyValueHeadCount: 1);
    expect(mqa.destinationMask(0), BigInt.from(0xf));
  });

  test('delivers a GQA tile to each query head in its group', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final upstream = ValidThenReadyInterface(_tile('gqaInput'));
    final downstreams = [
      for (var head = 0; head < 4; head++)
        ReadyValidInterface(_tile('queryHead$head')),
    ];
    final keyValueHead = Logic(width: 2);
    final dut = GroupedQueryAttentionTileDistributor<Logic, LogicValue>(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstreams: downstreams,
      keyValueHead: keyValueHead,
      mapping: const GroupedQueryHeadMapping(
        queryHeadCount: 4,
        keyValueHeadCount: 2,
      ),
    );
    await dut.build();
    unawaited(Simulator.run());

    reset.inject(1);
    upstream.valid.inject(0);
    keyValueHead.inject(0);
    for (final downstream in downstreams) {
      downstream.ready.inject(0);
    }
    await clk.nextPosedge;
    reset.inject(0);

    for (var index = 0; index < 4; index++) {
      upstream.data.data.arrayElements[index].inject(index + 1);
    }
    upstream.data.rowMask.inject(0x3);
    upstream.data.columnMask.inject(0x1);
    keyValueHead.inject(1);
    upstream.valid.inject(1);
    await clk.nextPosedge;
    upstream.valid.inject(0);

    expect(downstreams[0].valid.value, LogicValue.zero);
    expect(downstreams[1].valid.value, LogicValue.zero);
    expect(downstreams[2].valid.value, LogicValue.one);
    expect(downstreams[3].valid.value, LogicValue.one);
    expect(_tileValues(downstreams[2].data), [1, 2, 3, 4]);
    expect(_tileValues(downstreams[3].data), [1, 2, 3, 4]);

    downstreams[2].ready.inject(1);
    await clk.nextPosedge;
    downstreams[2].ready.inject(0);
    expect(downstreams[2].valid.value, LogicValue.zero);
    expect(downstreams[3].valid.value, LogicValue.one);
    downstreams[3].ready.inject(1);
    await clk.nextPosedge;
    expect(dut.occupied.value, LogicValue.zero);
    await Simulator.endSimulation();
  });

  test('consumes and diagnoses an out-of-range KV head', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final upstream = ValidThenReadyInterface(_tile('invalidHeadInput'));
    final downstreams = [
      for (var head = 0; head < 4; head++)
        ReadyValidInterface(_tile('invalidHeadOutput$head')),
    ];
    final keyValueHead = Logic(width: 2);
    final dut = GroupedQueryAttentionTileDistributor<Logic, LogicValue>(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstreams: downstreams,
      keyValueHead: keyValueHead,
      mapping: const GroupedQueryHeadMapping(
        queryHeadCount: 4,
        keyValueHeadCount: 2,
      ),
    );
    await dut.build();
    unawaited(Simulator.run());

    reset.inject(1);
    upstream.valid.inject(0);
    keyValueHead.inject(0);
    for (final downstream in downstreams) {
      downstream.ready.inject(1);
    }
    await clk.nextPosedge;
    reset.inject(0);
    upstream.data.inject(0);
    keyValueHead.inject(3);
    upstream.valid.inject(1);
    await clk.nextNegedge;
    expect(upstream.ready.value, LogicValue.one);
    expect(dut.invalidKeyValueHead.value, LogicValue.one);
    await clk.nextPosedge;
    upstream.valid.inject(0);

    expect(dut.occupied.value, LogicValue.zero);
    for (final downstream in downstreams) {
      expect(downstream.valid.value, LogicValue.zero);
    }
    await Simulator.endSimulation();
  });

  test('accepts the top head when the index width is fully occupied', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final upstream = ValidThenReadyInterface(_tile('mhaInput'));
    final downstreams = [
      for (var head = 0; head < 4; head++)
        ReadyValidInterface(_tile('mhaOutput$head')),
    ];
    final keyValueHead = Logic(width: 2);
    final dut = GroupedQueryAttentionTileDistributor<Logic, LogicValue>(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstreams: downstreams,
      keyValueHead: keyValueHead,
      mapping: const GroupedQueryHeadMapping(
        queryHeadCount: 4,
        keyValueHeadCount: 4,
      ),
    );
    await dut.build();
    unawaited(Simulator.run());

    reset.inject(1);
    upstream.valid.inject(0);
    keyValueHead.inject(0);
    for (final downstream in downstreams) {
      downstream.ready.inject(0);
    }
    await clk.nextPosedge;
    reset.inject(0);
    upstream.data.inject(0);
    keyValueHead.inject(3);
    upstream.valid.inject(1);
    await clk.nextPosedge;
    upstream.valid.inject(0);

    expect(dut.invalidKeyValueHead.value, LogicValue.zero);
    for (var head = 0; head < downstreams.length; head++) {
      expect(
        downstreams[head].valid.value,
        head == 3 ? LogicValue.one : LogicValue.zero,
      );
    }
    await Simulator.endSimulation();
  });
}

InferenceTensorTile<Logic, LogicValue> _tile(String name) =>
    inferenceLogicTensorTile(
      rowCount: 2,
      columnCount: 2,
      format: InferenceNumericFormat.signedInteger(8),
      name: name,
    );

List<int> _tileValues(InferenceTensorTile<Logic, LogicValue> tile) =>
    tile.data.arrayElements.map((element) => element.value.toInt()).toList();
