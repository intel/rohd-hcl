// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// mixed_precision_dot_product_test.dart
// Tests for Mixed Precision Dot Product.
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

  test('computes an unsigned masked mixed-width dot product', () async {
    final left = _lanes(3, 4, 'left');
    final right = _lanes(3, 3, 'right');
    final mask = Logic(width: 3);
    final initial = Logic(width: 10);
    final dut = MixedPrecisionDotProduct(
      left,
      right,
      outputWidth: 10,
      activeMask: mask,
      initialValue: initial,
    );
    await dut.build();

    _injectLanes(left, [2, 3, 4]);
    _injectLanes(right, [5, 6, 7]);
    mask.inject(5);
    initial.inject(9);
    await Simulator.tick();

    expect(dut.result.value.toInt(), 2 * 5 + 4 * 7 + 9);
    expect(dut.activeProducts.value.toInt(), 2);
    expect(dut.overflowed.value, LogicValue.zero);
    expect(dut.underflowed.value, LogicValue.zero);
  });

  test('computes signed by unsigned products', () async {
    final left = _lanes(2, 4, 'signedLeft');
    final right = _lanes(2, 3, 'unsignedRight');
    final dut = MixedPrecisionDotProduct(
      left,
      right,
      outputWidth: 8,
      signedLeft: true,
    );
    await dut.build();

    _injectSignedLanes(left, [-2, 3]);
    _injectLanes(right, [5, 4]);
    await Simulator.tick();

    expect(dut.result.value.toBigInt().toSigned(8).toInt(), 2);
    expect(dut.activeProducts.value.toInt(), 2);
    expect(dut.resultIsSigned.value, LogicValue.one);
  });

  test('selects operand signedness at runtime', () async {
    final left = _lanes(1, 4, 'runtimeLeft');
    final right = _lanes(1, 3, 'runtimeRight');
    final signedLeft = Logic(name: 'runtimeSignedLeft');
    final signedRight = Logic(name: 'runtimeSignedRight');
    final dut = MixedPrecisionDotProduct(
      left,
      right,
      outputWidth: 8,
      signedLeft: signedLeft,
      signedRight: signedRight,
    );
    await dut.build();

    _injectLanes(left, [14]);
    _injectLanes(right, [5]);
    signedLeft.inject(0);
    signedRight.inject(0);
    await Simulator.tick();
    expect(dut.result.value.toInt(), 70);
    expect(dut.resultIsSigned.value, LogicValue.zero);

    signedLeft.inject(1);
    await Simulator.tick();
    expect(dut.result.value.toBigInt().toSigned(8).toInt(), -10);
    expect(dut.resultIsSigned.value, LogicValue.one);
  });

  test('selects native and compression-tree multiplier functors', () async {
    final nativeLeft = _lanes(2, 4, 'nativeLeft');
    final nativeRight = _lanes(2, 3, 'nativeRight');
    final treeLeft = _lanes(2, 4, 'treeLeft');
    final treeRight = _lanes(2, 3, 'treeRight');
    final native = MixedPrecisionDotProduct(
      nativeLeft,
      nativeRight,
      outputWidth: 10,
    );
    final compressionTree = MixedPrecisionDotProduct(
      treeLeft,
      treeRight,
      outputWidth: 10,
      multiplierImplementation: compressionTreeInferenceMultiplierFunctor(),
    );
    await native.build();
    await compressionTree.build();

    _injectLanes(nativeLeft, [13, 7]);
    _injectLanes(nativeRight, [6, 5]);
    _injectLanes(treeLeft, [13, 7]);
    _injectLanes(treeRight, [6, 5]);
    await Simulator.tick();

    expect(native.result.value.toInt(), 113);
    expect(compressionTree.result.value, native.result.value);
    expect(native.multiplierImplementation.identity, 'native');
    expect(
      compressionTree.multiplierImplementation.identity,
      'compressionTreeR4',
    );
  });

  test('applies saturating and wrapping output policies', () async {
    final saturatingLeft = _lanes(4, 4, 'saturatingLeft');
    final saturatingRight = _lanes(4, 4, 'saturatingRight');
    final wrappingLeft = _lanes(4, 4, 'wrappingLeft');
    final wrappingRight = _lanes(4, 4, 'wrappingRight');
    final saturating = MixedPrecisionDotProduct(
      saturatingLeft,
      saturatingRight,
      outputWidth: 8,
    );
    final wrapping = MixedPrecisionDotProduct(
      wrappingLeft,
      wrappingRight,
      outputWidth: 8,
      overflowMode: NumericOverflowMode.wrap,
    );
    await saturating.build();
    await wrapping.build();

    _injectLanes(saturatingLeft, [15, 15, 15, 15]);
    _injectLanes(saturatingRight, [15, 15, 15, 15]);
    _injectLanes(wrappingLeft, [15, 15, 15, 15]);
    _injectLanes(wrappingRight, [15, 15, 15, 15]);
    await Simulator.tick();

    expect(saturating.result.value.toInt(), 255);
    expect(saturating.overflowed.value, LogicValue.one);
    expect(wrapping.result.value.toInt(), 900 & 0xff);
    expect(wrapping.overflowed.value, LogicValue.one);
  });
}

LogicArray _lanes(int count, int width, String name) =>
    LogicArray([count], width, name: name);

void _injectLanes(
  LogicArray lanes,
  List<int> values,
) {
  for (var lane = 0; lane < values.length; lane++) {
    lanes.arrayElements[lane].inject(values[lane]);
  }
}

void _injectSignedLanes(
  LogicArray lanes,
  List<int> values,
) {
  for (var lane = 0; lane < values.length; lane++) {
    lanes.arrayElements[lane].inject(
      BigInt.from(values[lane]).toUnsigned(lanes.elementWidth),
    );
  }
}
