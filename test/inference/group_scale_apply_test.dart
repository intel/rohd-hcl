// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// group_scale_apply_test.dart
// Tests for Group Scale Apply.
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

  test('applies one fixed-point scale per lane group', () async {
    final nativeValues = _array(4, 8, 'nativeValues');
    final nativeScales = _array(2, 8, 'nativeScales');
    final treeValues = _array(4, 8, 'treeValues');
    final treeScales = _array(2, 8, 'treeScales');
    final native = GroupScaleApply(
      nativeValues,
      nativeScales,
      groupSize: 2,
      fractionalBits: 8,
      outputWidth: 8,
      signedScale: false,
    );
    final compressionTree = GroupScaleApply(
      treeValues,
      treeScales,
      groupSize: 2,
      fractionalBits: 8,
      outputWidth: 8,
      signedScale: false,
      multiplierImplementation: compressionTreeInferenceMultiplierFunctor(),
    );
    await native.build();
    await compressionTree.build();

    _injectSigned(nativeValues, [100, -50, 60, -80]);
    _inject(nativeScales, [128, 64]);
    _injectSigned(treeValues, [100, -50, 60, -80]);
    _inject(treeScales, [128, 64]);
    await Simulator.tick();

    expect(_signedResults(native.scaledValues), [50, -25, 15, -20]);
    expect(compressionTree.scaledValues.value, native.scaledValues.value);
    expect(native.overflowMask.value.toInt(), 0);
    expect(native.underflowMask.value.toInt(), 0);
    expect(native.activeCount.value.toInt(), 4);
  });

  test('rounds ties to even before adding each group zero point', () async {
    final values = _array(4, 8, 'values');
    final scales = _array(2, 8, 'scales');
    final zeroPoints = _array(2, 8, 'zeroPoints');
    final dut = GroupScaleApply(
      values,
      scales,
      groupSize: 2,
      fractionalBits: 8,
      outputWidth: 8,
      zeroPoints: zeroPoints,
      signedScale: false,
    );
    await dut.build();

    _injectSigned(values, [3, 5, 6, 10]);
    _inject(scales, [128, 64]);
    _injectSigned(zeroPoints, [1, -2]);
    await Simulator.tick();

    expect(_signedResults(dut.scaledValues), [3, 3, 0, 0]);
    expect(dut.inexactMask.value.toInt(), 0xf);
  });

  test('masks inactive lanes and saturates positive overflow', () async {
    final values = _array(2, 8, 'values');
    final scales = _array(1, 8, 'scales');
    final mask = Logic(width: 2);
    final dut = GroupScaleApply(
      values,
      scales,
      groupSize: 2,
      fractionalBits: 0,
      outputWidth: 8,
      activeMask: mask,
      signedValue: false,
      signedScale: false,
      signedOutput: false,
    );
    await dut.build();

    _inject(values, [255, 17]);
    _inject(scales, [2]);
    mask.inject(1);
    await Simulator.tick();

    expect(
      dut.scaledValues.value.arrayValues.map((value) => value.toInt()),
      [255, 0],
    );
    expect(dut.overflowMask.value.toInt(), 1);
    expect(dut.inexactMask.value.toInt(), 0);
    expect(dut.activeCount.value.toInt(), 1);
  });

  test('clamps a negative signed product when output is unsigned', () async {
    final values = _array(1, 8, 'values');
    final scales = _array(1, 8, 'scales');
    final dut = GroupScaleApply(
      values,
      scales,
      groupSize: 1,
      fractionalBits: 0,
      outputWidth: 8,
      signedScale: false,
      signedOutput: false,
    );
    await dut.build();

    _injectSigned(values, [-2]);
    _inject(scales, [1]);
    await Simulator.tick();

    expect(dut.scaledValues.arrayElements.single.value.toInt(), 0);
    expect(dut.underflowMask.value.toInt(), 1);
    expect(dut.outputIsSigned.value, LogicValue.zero);
  });

  test('selects value and output signedness at runtime', () async {
    final values = _array(1, 8, 'values');
    final scales = _array(1, 4, 'scales');
    final signedValue = Logic(name: 'runtimeSignedValue');
    final signedOutput = Logic(name: 'runtimeSignedOutput');
    final dut = GroupScaleApply(
      values,
      scales,
      groupSize: 1,
      fractionalBits: 0,
      outputWidth: 10,
      signedValue: signedValue,
      signedScale: false,
      signedOutput: signedOutput,
    );
    await dut.build();

    _inject(values, [254]);
    _inject(scales, [2]);
    signedValue.inject(0);
    signedOutput.inject(0);
    await Simulator.tick();
    expect(dut.scaledValues.arrayElements.single.value.toInt(), 508);

    signedValue.inject(1);
    signedOutput.inject(1);
    await Simulator.tick();
    expect(
      dut.scaledValues.arrayElements.single.value.toBigInt().toSigned(10),
      BigInt.from(-4),
    );
    expect(dut.outputIsSigned.value, LogicValue.one);
  });

  test('validates scale count and group size', () {
    expect(
      () => GroupScaleApply(
        _array(4, 8, 'values'),
        _array(1, 8, 'scales'),
        groupSize: 2,
        fractionalBits: 4,
        outputWidth: 8,
      ),
      throwsArgumentError,
    );
    expect(
      () => GroupScaleApply(
        _array(4, 8, 'values'),
        _array(4, 8, 'scales'),
        groupSize: 0,
        fractionalBits: 4,
        outputWidth: 8,
      ),
      throwsArgumentError,
    );
  });
}

LogicArray _array(int count, int width, String name) =>
    LogicArray([count], width, name: name);

void _inject(LogicArray array, List<int> values) {
  for (var index = 0; index < values.length; index++) {
    array.arrayElements[index].inject(values[index]);
  }
}

void _injectSigned(LogicArray array, List<int> values) {
  for (var index = 0; index < values.length; index++) {
    array.arrayElements[index].inject(
      BigInt.from(values[index]).toUnsigned(array.elementWidth),
    );
  }
}

List<int> _signedResults(LogicArray values) => [
      for (final value in values.value.arrayValues)
        value.toBigInt().toSigned(values.elementWidth).toInt(),
    ];
