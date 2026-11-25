// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// rms_norm_test.dart
// Tests for Rms Norm.
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

  test('normalizes active fixed-point lanes and applies weights', () async {
    final values = LogicArray(const [4], 8, name: 'values');
    final weights = LogicArray(const [4], 8, name: 'weights');
    final mask = Logic(width: 4);
    final dut = _rmsNorm(values, weights, activeMask: mask);
    await dut.build();

    _injectSigned(values, [4, -4, 20, -20]);
    _injectSigned(weights, [16, 16, 16, 16]);
    mask.inject(3);
    await Simulator.tick();

    expect(_signedArray(dut.normalizedValues), [4, -4, 0, 0]);
    expect(dut.meanSquare.value.toInt(), 17);
    expect(dut.activeCount.value.toInt(), 2);
    expect(dut.status.invalidInput.value, LogicValue.zero);
    expect(dut.status.overflow.value, LogicValue.zero);
  });

  test('applies per-lane RMS weights', () async {
    final values = LogicArray(const [4], 8, name: 'values');
    final weights = LogicArray(const [4], 8, name: 'weights');
    final dut = _rmsNorm(values, weights);
    await dut.build();

    _injectSigned(values, [4, -4, 4, -4]);
    _injectSigned(weights, [16, 32, 8, 16]);
    await Simulator.tick();

    expect(_signedArray(dut.normalizedValues), [4, -8, 2, -4]);
  });

  test('native and compression-tree RMSNorm implementations agree', () async {
    final nativeValues = LogicArray(const [4], 8, name: 'nativeValues');
    final nativeWeights = LogicArray(const [4], 8, name: 'nativeWeights');
    final treeValues = LogicArray(const [4], 8, name: 'treeValues');
    final treeWeights = LogicArray(const [4], 8, name: 'treeWeights');
    final native = _rmsNorm(nativeValues, nativeWeights);
    final tree = _rmsNorm(
      treeValues,
      treeWeights,
      multiplierImplementation: compressionTreeInferenceMultiplierFunctor(),
    );
    await native.build();
    await tree.build();

    _injectSigned(nativeValues, [3, -5, 7, -2]);
    _injectSigned(nativeWeights, [16, 16, 16, 16]);
    _injectSigned(treeValues, [3, -5, 7, -2]);
    _injectSigned(treeWeights, [16, 16, 16, 16]);
    await Simulator.tick();

    expect(tree.normalizedValues.value, native.normalizedValues.value);
    expect(tree.meanSquare.value, native.meanSquare.value);
    expect(tree.inverseRms.value, native.inverseRms.value);
  });

  test('reports and zeros an empty active mask', () async {
    final values = LogicArray(const [4], 8, name: 'values');
    final weights = LogicArray(const [4], 8, name: 'weights');
    final mask = Logic(width: 4);
    final dut = _rmsNorm(values, weights, activeMask: mask);
    await dut.build();

    _injectSigned(values, [4, -4, 4, -4]);
    _injectSigned(weights, [16, 16, 16, 16]);
    mask.inject(0);
    await Simulator.tick();

    expect(dut.normalizedValues.value.packed.toBigInt(), BigInt.zero);
    expect(dut.status.invalidInput.value, LogicValue.one);
    expect(dut.status.approximationError.value, LogicValue.one);
  });

  test('validates RMSNorm formats', () {
    expect(
      () => _rmsNorm(
        LogicArray(const [4], 8),
        LogicArray(const [3], 8),
      ),
      throwsArgumentError,
    );
    expect(
      () => RmsNorm(
        LogicArray(const [4], 8),
        LogicArray(const [4], 8),
        valueFractionBits: 4,
        weightFractionBits: 4,
        meanSquareWidth: 8,
        countReciprocalWidth: 10,
        countReciprocalFractionBits: 8,
        inverseRmsWidth: 10,
        inverseRmsFractionBits: 8,
        outputWidth: 8,
        epsilonRaw: 1,
      ),
      throwsArgumentError,
    );
  });
}

RmsNorm _rmsNorm(
  LogicArray values,
  LogicArray weights, {
  Logic? activeMask,
  InferenceMultiplierFunctor multiplierImplementation =
      nativeInferenceMultiplierFunctor,
}) =>
    RmsNorm(
      values,
      weights,
      valueFractionBits: 2,
      weightFractionBits: 4,
      meanSquareWidth: 8,
      countReciprocalWidth: 10,
      countReciprocalFractionBits: 8,
      inverseRmsWidth: 10,
      inverseRmsFractionBits: 8,
      outputWidth: 8,
      epsilonRaw: 1,
      activeMask: activeMask,
      multiplierImplementation: multiplierImplementation,
    );

void _injectSigned(LogicArray array, List<int> values) {
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
