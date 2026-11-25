// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// online_softmax_state_test.dart
// Tests for Online Softmax State.
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

  test('merges exact powers of two and is commutative', () async {
    final left = _state('left');
    final right = _state('right');
    final forward = OnlineSoftmaxMerge(
      left,
      right,
      expWidth: 10,
      expFractionBits: 8,
      name: 'forwardMerge',
    );
    final reverse = OnlineSoftmaxMerge(
      right,
      left,
      expWidth: 10,
      expFractionBits: 8,
      name: 'reverseMerge',
    );
    await forward.build();
    await reverse.build();

    _injectState(left, maximum: 0, normalizer: 256, valid: true);
    _injectState(right, maximum: -4, normalizer: 256, valid: true);
    await Simulator.tick();

    expect(_signed(forward.mergedState.maximum), 0);
    expect(forward.mergedState.normalizer.value.toInt(), 384);
    expect(forward.mergedState.valid.value, LogicValue.one);
    expect(forward.mergedState.overflow.value, LogicValue.zero);
    expect(forward.mergedState.inexact.value, LogicValue.zero);
    expect(forward.mergedState.approximationError.value, LogicValue.zero);
    expect(reverse.mergedState.value, forward.mergedState.value);
  });

  test('passes through one valid state and clears two empty states', () async {
    final left = _state('left');
    final right = _state('right');
    final dut = OnlineSoftmaxMerge(
      left,
      right,
      expWidth: 10,
      expFractionBits: 8,
    );
    await dut.build();

    _injectState(
      left,
      maximum: 7,
      normalizer: 300,
      valid: true,
      inexact: true,
    );
    _injectState(right, maximum: -4, normalizer: 200, valid: false);
    await Simulator.tick();
    expect(_signed(dut.mergedState.maximum), 7);
    expect(dut.mergedState.normalizer.value.toInt(), 300);
    expect(dut.mergedState.inexact.value, LogicValue.one);

    _injectState(left, maximum: 7, normalizer: 300, valid: false);
    await Simulator.tick();
    expect(dut.mergedState.valid.value, LogicValue.zero);
    expect(dut.mergedState.maximum.value.toInt(), 0);
    expect(dut.mergedState.normalizer.value.toInt(), 0);
  });

  test('updates an empty state then rescales a smaller score', () async {
    final state = _state('state');
    final score = Logic(width: 5);
    final valid = Logic();
    final dut = OnlineSoftmaxUpdate(
      state,
      score,
      scoreValid: valid,
      expWidth: 10,
      expFractionBits: 8,
    );
    await dut.build();

    _injectState(state, maximum: 0, normalizer: 0, valid: false);
    score.inject(BigInt.from(2).toUnsigned(5));
    valid.inject(1);
    await Simulator.tick();
    expect(_signed(dut.nextState.maximum), 2);
    expect(dut.nextState.normalizer.value.toInt(), 256);
    expect(dut.nextState.valid.value, LogicValue.one);

    _injectState(state, maximum: 0, normalizer: 256, valid: true);
    score.inject(BigInt.from(-4).toUnsigned(5));
    await Simulator.tick();
    expect(_signed(dut.nextState.maximum), 0);
    expect(dut.nextState.normalizer.value.toInt(), 384);
  });

  test('merge agrees with reference lookup and fixed-point scaling', () async {
    final left = _state('left');
    final right = _state('right');
    final dut = OnlineSoftmaxMerge(
      left,
      right,
      expWidth: 10,
      expFractionBits: 8,
    );
    await dut.build();

    _injectState(left, maximum: 0, normalizer: 384, valid: true);
    _injectState(right, maximum: -2, normalizer: 256, valid: true);
    await Simulator.tick();

    final expContract = FixedPointApproximationContract(
      operation: FixedPointApproximationOperation.exp2,
      inputWidth: 6,
      inputFractionBits: 2,
      signedInput: true,
      outputWidth: 10,
      outputFractionBits: 8,
      minimumInputRaw: -32,
      maximumInputRaw: 0,
      roundingMode: NumericRoundingMode.nearestEven,
      maximumErrorLsb: 0.5,
      monotonicallyIncreasing: true,
    );
    final rightScale =
        evaluateFixedPointApproximation(expContract, -2).result.toInt();
    final expected = 384 + ((256 * rightScale + 128) >> 8);
    expect(dut.mergedState.normalizer.value.toInt(), expected);
    expect(dut.mergedState.inexact.value, LogicValue.one);
  });

  test('saturates a normalization overflow', () async {
    final left = _state('left', normalizerWidth: 10);
    final right = _state('right', normalizerWidth: 10);
    final dut = OnlineSoftmaxMerge(
      left,
      right,
      expWidth: 10,
      expFractionBits: 8,
    );
    await dut.build();

    _injectState(left, maximum: 0, normalizer: 800, valid: true);
    _injectState(right, maximum: 0, normalizer: 800, valid: true);
    await Simulator.tick();

    expect(dut.mergedState.normalizer.value.toInt(), 1023);
    expect(dut.mergedState.overflow.value, LogicValue.one);
  });
}

OnlineSoftmaxState _state(
  String name, {
  int normalizerWidth = 12,
}) =>
    OnlineSoftmaxState(
      scoreWidth: 5,
      scoreFractionBits: 2,
      normalizerWidth: normalizerWidth,
      normalizerFractionBits: 8,
      name: name,
    );

void _injectState(
  OnlineSoftmaxState state, {
  required int maximum,
  required int normalizer,
  required bool valid,
  bool overflow = false,
  bool inexact = false,
  bool approximationError = false,
}) {
  state.maximum.inject(
    BigInt.from(maximum).toUnsigned(state.maximum.width),
  );
  state.normalizer.inject(normalizer);
  state.valid.inject(valid ? 1 : 0);
  state.overflow.inject(overflow ? 1 : 0);
  state.inexact.inject(inexact ? 1 : 0);
  state.approximationError.inject(approximationError ? 1 : 0);
}

int _signed(Logic value) =>
    value.value.toBigInt().toSigned(value.width).toInt();
