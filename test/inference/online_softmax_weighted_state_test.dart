// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// online_softmax_weighted_state_test.dart
// Tests for Online Softmax Weighted State.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('merges weighted states and preserves commutativity', () async {
    final left = _weightedState('left');
    final right = _weightedState('right');
    final forward = OnlineSoftmaxWeightedMerge(
      left,
      right,
      expWidth: 10,
      expFractionBits: 8,
      name: 'forward',
    );
    final reverse = OnlineSoftmaxWeightedMerge(
      right,
      left,
      expWidth: 10,
      expFractionBits: 8,
      name: 'reverse',
    );
    await forward.build();
    await reverse.build();

    _injectWeightedState(
      left,
      maximum: 0,
      normalizer: 256,
      weightedValues: [256, 512],
      valid: true,
    );
    _injectWeightedState(
      right,
      maximum: -4,
      normalizer: 256,
      weightedValues: [512, -256],
      valid: true,
    );
    await Simulator.tick();

    expect(_signed(forward.mergedState.scalar.maximum), 0);
    expect(forward.mergedState.scalar.normalizer.value.toInt(), 384);
    expect(_signedArray(forward.mergedState.weightedValues), [512, 384]);
    expect(reverse.mergedState.value, forward.mergedState.value);
    expect(forward.mergedState.scalar.overflow.value, LogicValue.zero);
  });

  test('updates empty weighted state with one score and vector', () async {
    final state = _weightedState('state');
    final score = Logic(width: 5);
    final value = LogicArray(const [2], 12, name: 'value');
    final dut = OnlineSoftmaxWeightedUpdate(
      state,
      score,
      value,
      expWidth: 10,
      expFractionBits: 8,
    );
    await dut.build();

    _injectWeightedState(
      state,
      maximum: 0,
      normalizer: 0,
      weightedValues: [0, 0],
      valid: false,
    );
    score.inject(2);
    _injectSignedArray(value, [300, -120]);
    await Simulator.tick();

    expect(_signed(dut.nextState.scalar.maximum), 2);
    expect(dut.nextState.scalar.normalizer.value.toInt(), 256);
    expect(_signedArray(dut.nextState.weightedValues), [300, -120]);
    expect(dut.nextState.scalar.valid.value, LogicValue.one);
  });

  test('normalizes a weighted numerator by the softmax sum', () async {
    final state = _weightedState('state');
    final dut = OnlineSoftmaxNormalize(
      state,
      reciprocalWidth: 12,
      reciprocalFractionBits: 10,
      outputWidth: 12,
    );
    await dut.build();

    _injectWeightedState(
      state,
      maximum: 0,
      normalizer: 384,
      weightedValues: [512, 384],
      valid: true,
    );
    await Simulator.tick();

    expect(_signedArray(dut.values), [342, 256]);
    expect(dut.invalidState.value, LogicValue.zero);
    expect(dut.overflow.value, LogicValue.zero);

    state.scalar.valid.inject(0);
    state.scalar.normalizer.inject(0);
    await Simulator.tick();
    expect(dut.values.value.packed.toBigInt(), BigInt.zero);
    expect(dut.invalidState.value, LogicValue.one);
    expect(dut.overflow.value, LogicValue.zero);
    expect(dut.inexact.value, LogicValue.zero);
  });

  test('passes through one valid weighted state', () async {
    final left = _weightedState('left');
    final right = _weightedState('right');
    final dut = OnlineSoftmaxWeightedMerge(
      left,
      right,
      expWidth: 10,
      expFractionBits: 8,
    );
    await dut.build();

    _injectWeightedState(
      left,
      maximum: 3,
      normalizer: 300,
      weightedValues: [-100, 200],
      valid: true,
    );
    _injectWeightedState(
      right,
      maximum: 0,
      normalizer: 0,
      weightedValues: [0, 0],
      valid: false,
    );
    await Simulator.tick();

    expect(dut.mergedState.value, left.value);
  });
}

OnlineSoftmaxWeightedState _weightedState(String name) =>
    OnlineSoftmaxWeightedState(
      scoreWidth: 5,
      scoreFractionBits: 2,
      normalizerWidth: 12,
      normalizerFractionBits: 8,
      valueCount: 2,
      valueWidth: 12,
      valueFractionBits: 8,
      name: name,
    );

void _injectWeightedState(
  OnlineSoftmaxWeightedState state, {
  required int maximum,
  required int normalizer,
  required List<int> weightedValues,
  required bool valid,
}) {
  state.scalar.maximum.inject(
    BigInt.from(maximum).toUnsigned(state.scalar.scoreWidth),
  );
  state.scalar.normalizer.inject(normalizer);
  state.scalar.valid.inject(valid ? 1 : 0);
  state.scalar.overflow.inject(0);
  state.scalar.inexact.inject(0);
  state.scalar.approximationError.inject(0);
  _injectSignedArray(state.weightedValues, weightedValues);
}

void _injectSignedArray(LogicArray array, List<int> values) {
  for (var index = 0; index < values.length; index++) {
    array.arrayElements[index].inject(
      BigInt.from(values[index]).toUnsigned(array.elementWidth),
    );
  }
}

List<int> _signedArray(LogicArray values) => [
      for (final value in values.value.arrayValues)
        value.toBigInt().toSigned(values.elementWidth).toInt(),
    ];

int _signed(Logic value) =>
    value.value.toBigInt().toSigned(value.width).toInt();
