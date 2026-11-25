// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// vector_reduce_test.dart
// Tests for Vector Reduce.
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

  test('sums active unsigned lanes', () async {
    final lanes = _lanes();
    final mask = Logic(width: 4);
    final dut = VectorReduce(
      lanes,
      operation: InferenceVectorReduction.sum,
      activeMask: mask,
    );
    await dut.build();

    _injectSigned(lanes, [1, 2, 3, 4]);
    mask.inject(0xb);
    await Simulator.tick();

    expect(dut.result.value.toInt(), 7);
    expect(dut.activeCount.value.toInt(), 3);
    expect(dut.empty.value, LogicValue.zero);
  });

  test('selects signed minimum and maximum with stable indices', () async {
    final minLanes = _lanes(name: 'minLanes');
    final maxLanes = _lanes(name: 'maxLanes');
    final minimum = VectorReduce(
      minLanes,
      operation: InferenceVectorReduction.minimum,
      signed: true,
    );
    final maximum = VectorReduce(
      maxLanes,
      operation: InferenceVectorReduction.maximum,
      signed: true,
    );
    await minimum.build();
    await maximum.build();

    _injectSigned(minLanes, [-8, 7, -1, 7]);
    _injectSigned(maxLanes, [-8, 7, -1, 7]);
    await Simulator.tick();

    expect(minimum.result.value.toBigInt().toSigned(4).toInt(), -8);
    expect(minimum.selectedIndex.value.toInt(), 0);
    expect(maximum.result.value.toBigInt().toSigned(4).toInt(), 7);
    expect(maximum.selectedIndex.value.toInt(), 1);
  });

  test('reports empty masked extrema and saturates a narrow sum', () async {
    final emptyLanes = _lanes(name: 'emptyLanes');
    final sumLanes = _lanes(name: 'sumLanes');
    final emptyMask = Logic(width: 4);
    final empty = VectorReduce(
      emptyLanes,
      operation: InferenceVectorReduction.maximum,
      activeMask: emptyMask,
      signed: true,
    );
    final sum = VectorReduce(
      sumLanes,
      operation: InferenceVectorReduction.sum,
      outputWidth: 4,
    );
    await empty.build();
    await sum.build();

    _injectSigned(emptyLanes, [1, 2, 3, 4]);
    emptyMask.inject(0);
    _injectSigned(sumLanes, [15, 15, 15, 15]);
    await Simulator.tick();

    expect(empty.empty.value, LogicValue.one);
    expect(empty.result.value.toInt(), 0);
    expect(sum.result.value.toInt(), 15);
    expect(sum.overflowed.value, LogicValue.one);
  });
}

LogicArray _lanes({String name = 'lanes'}) =>
    LogicArray(const [4], 4, name: name);

void _injectSigned(
  LogicArray lanes,
  List<int> values,
) {
  for (var lane = 0; lane < values.length; lane++) {
    lanes.arrayElements[lane].inject(
      BigInt.from(values[lane]).toUnsigned(lanes.elementWidth),
    );
  }
}
