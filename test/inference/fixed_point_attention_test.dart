// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_attention_test.dart
// Tests for Fixed Point Attention.
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

  test('streams fused attention without materializing scores', () async {
    final fixture = _AttentionFixture();
    await fixture.buildAndReset();
    final query = [1, 0];
    final keys = [
      [0, 0],
      [-1, 0],
      [-2, 0],
    ];
    final values = [
      [4, 0],
      [0, 4],
      [4, 4],
    ];
    final reference = evaluateFixedPointAttention(
      query: query,
      keys: keys,
      values: values,
      keyMask: const [true, true, true],
      laneMask: const [true, true],
      causalKeyCount: 3,
      inputFractionBits: 0,
      scoreFractionBits: 0,
      outputFractionBits: 0,
    );

    await fixture.send(
      requestId: 5,
      query: query,
      keys: keys,
      values: values,
      keyMask: 7,
      laneMask: 3,
      causalKeyCount: 3,
    );
    await fixture.waitForOutput();

    expect(fixture.outputValues, reference.values);
    expect(fixture.downstream.data.requestId.value.toInt(), 5);
    expect(fixture.downstream.data.invalidInput.value, LogicValue.zero);
    expect(fixture.dut.scoreProducts.value.toInt(), 6);
    expect(fixture.dut.activeValues.value.toInt(), 3);
    expect(fixture.dut.inputBytes.value.toInt(), 10);
    expect(fixture.dut.avoidedScoreWriteBytes.value.toInt(), 3);
    expect(fixture.dut.busyCycles.value.toInt(), 3);
    expect(fixture.dut.completedRequests.value.toInt(), 0);

    final retained = fixture.downstream.data.value;
    await fixture.clk.nextPosedge;
    await fixture.clk.nextPosedge;
    expect(fixture.downstream.valid.value, LogicValue.one);
    expect(fixture.downstream.data.value, retained);
    expect(
      fixture.dut.outputStallCycles.value.toInt(),
      greaterThanOrEqualTo(2),
    );
    await fixture.acceptOutput();
    expect(fixture.dut.completedRequests.value.toInt(), 1);
    await Simulator.endSimulation();
  });

  test('combines causal, key, and head-lane masks', () async {
    final fixture = _AttentionFixture();
    await fixture.buildAndReset();
    final query = [1, 7];
    final keys = [
      [0, 3],
      [-1, -4],
      [-2, 2],
    ];
    final values = [
      [4, 0],
      [0, 4],
      [4, 4],
    ];
    final reference = evaluateFixedPointAttention(
      query: query,
      keys: keys,
      values: values,
      keyMask: const [true, true, true],
      laneMask: const [true, false],
      causalKeyCount: 2,
      inputFractionBits: 0,
      scoreFractionBits: 0,
      outputFractionBits: 0,
    );

    await fixture.send(
      requestId: 2,
      query: query,
      keys: keys,
      values: values,
      keyMask: 7,
      laneMask: 1,
      causalKeyCount: 2,
    );
    await fixture.waitForOutput();

    expect(fixture.outputValues, reference.values);
    expect(fixture.dut.scoreProducts.value.toInt(), 2);
    expect(fixture.dut.activeValues.value.toInt(), 2);
    expect(fixture.dut.avoidedScoreWriteBytes.value.toInt(), 2);
    await Simulator.endSimulation();
  });

  test('reports an empty attention request and supports counter clear',
      () async {
    final fixture = _AttentionFixture();
    await fixture.buildAndReset();
    await fixture.send(
      requestId: 1,
      query: const [1, 0],
      keys: const [
        [0, 0],
        [-1, 0],
        [-2, 0],
      ],
      values: const [
        [4, 0],
        [0, 4],
        [4, 4],
      ],
      keyMask: 0,
      laneMask: 3,
      causalKeyCount: 3,
    );
    await fixture.waitForOutput();

    expect(fixture.outputValues, [0, 0]);
    expect(fixture.downstream.data.invalidInput.value, LogicValue.one);
    expect(fixture.dut.activeValues.value.toInt(), 0);
    expect(fixture.dut.scoreProducts.value.toInt(), 0);
    expect(fixture.dut.busyCycles.value.toInt(), 3);

    fixture.clearCounters.inject(1);
    await fixture.clk.nextPosedge;
    fixture.clearCounters.inject(0);
    await fixture.clk.nextNegedge;
    for (final counter in [
      fixture.dut.scoreProducts,
      fixture.dut.activeValues,
      fixture.dut.inputBytes,
      fixture.dut.avoidedScoreWriteBytes,
      fixture.dut.busyCycles,
      fixture.dut.outputStallCycles,
      fixture.dut.completedRequests,
    ]) {
      expect(counter.value.toInt(), 0);
    }
    await Simulator.endSimulation();
  });

  test('compression-tree attention implementation matches reference', () async {
    final fixture = _AttentionFixture(
      multiplierImplementation: compressionTreeInferenceMultiplierFunctor(),
    );
    await fixture.buildAndReset();
    await fixture.send(
      requestId: 3,
      query: const [1, 0],
      keys: const [
        [0, 0],
        [-1, 0],
        [-2, 0],
      ],
      values: const [
        [4, 0],
        [0, 4],
        [4, 4],
      ],
      keyMask: 7,
      laneMask: 3,
      causalKeyCount: 3,
    );
    await fixture.waitForOutput();

    expect(fixture.outputValues, [3, 2]);
    expect(
      fixture.dut.multiplierImplementation.identity,
      'compressionTreeR4',
    );
    await Simulator.endSimulation();
  });
}

class _AttentionFixture {
  final InferenceMultiplierFunctor multiplierImplementation;
  final Logic clk = SimpleClockGenerator(10).clk;
  final Logic reset = Logic();
  final Logic clearCounters = Logic();
  late final ReadyValidInterface<FixedPointAttentionRequest> upstream;
  late final ReadyValidInterface<FixedPointAttentionResult> downstream;
  late final FixedPointAttention dut;

  _AttentionFixture({
    this.multiplierImplementation = nativeInferenceMultiplierFunctor,
  }) {
    upstream = ReadyValidInterface(
      FixedPointAttentionRequest(
        sequenceLength: 3,
        headDimension: 2,
        valueDimension: 2,
        elementWidth: 4,
        valueWidth: 8,
        requestIdWidth: 3,
      ),
    );
    downstream = ReadyValidInterface(
      FixedPointAttentionResult(
        valueDimension: 2,
        outputWidth: 8,
        requestIdWidth: 3,
      ),
    );
    dut = FixedPointAttention(
      clk: clk,
      reset: reset,
      clearCounters: clearCounters,
      upstream: upstream,
      downstream: downstream,
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
      multiplierImplementation: multiplierImplementation,
    );
  }

  List<int> get outputValues => [
        for (final value in downstream.data.values.value.arrayValues)
          value.toBigInt().toSigned(8).toInt(),
      ];

  Future<void> buildAndReset() async {
    await dut.build();
    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());
    reset.inject(1);
    clearCounters.inject(0);
    upstream.valid.inject(0);
    upstream.data.inject(0);
    downstream.ready.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextNegedge;
  }

  Future<void> send({
    required int requestId,
    required List<int> query,
    required List<List<int>> keys,
    required List<List<int>> values,
    required int keyMask,
    required int laneMask,
    required int causalKeyCount,
  }) async {
    upstream.data.requestId.inject(requestId);
    upstream.data.keyMask.inject(keyMask);
    upstream.data.laneMask.inject(laneMask);
    upstream.data.causalKeyCount.inject(causalKeyCount);
    for (var lane = 0; lane < query.length; lane++) {
      upstream.data.query.arrayElements[lane].inject(
        BigInt.from(query[lane]).toUnsigned(
          upstream.data.query.elementWidth,
        ),
      );
    }
    for (var position = 0; position < keys.length; position++) {
      for (var lane = 0; lane < keys[position].length; lane++) {
        upstream.data.keys.at([position, lane]).inject(
          BigInt.from(keys[position][lane]).toUnsigned(
            upstream.data.keys.elementWidth,
          ),
        );
      }
      for (var lane = 0; lane < values[position].length; lane++) {
        upstream.data.values.at([position, lane]).inject(
          BigInt.from(values[position][lane]).toUnsigned(
            upstream.data.values.elementWidth,
          ),
        );
      }
    }
    upstream.valid.inject(1);
    while (upstream.ready.value != LogicValue.one) {
      await clk.nextNegedge;
    }
    await clk.nextPosedge;
    upstream.valid.inject(0);
    await clk.nextNegedge;
  }

  Future<void> waitForOutput() async {
    while (downstream.valid.value != LogicValue.one) {
      await clk.nextNegedge;
    }
  }

  Future<void> acceptOutput() async {
    downstream.ready.inject(1);
    await clk.nextPosedge;
    downstream.ready.inject(0);
    await clk.nextNegedge;
  }
}
