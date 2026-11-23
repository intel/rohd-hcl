// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// inference_tensor_tile_test.dart
// Tests for Inference Tensor Tile.
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

  test('preserves typed tensor shape, masks, and clone metadata', () async {
    final format = InferenceNumericFormat.signedInteger(8);
    final tile = inferenceLogicTensorTile(
      rowCount: 2,
      columnCount: 3,
      format: format,
      name: 'inputTile',
    );
    final dut = _TensorTilePassThrough(tile);
    await dut.build();

    for (var index = 0; index < tile.data.arrayElements.length; index++) {
      tile.data.arrayElements[index].inject(index + 1);
    }
    tile.rowMask.inject(1);
    tile.columnMask.inject(5);
    await Simulator.tick();

    expect(tile.data, isA<TypedLogicArray<Logic, LogicValue>>());
    expect(tile.data.dimensions, [2, 3]);
    expect(tile.data.arrayElements, hasLength(6));
    expect(dut.outputTile.format, same(format));
    expect(dut.outputTile.data.dimensions, [2, 3]);
    expect(
      dut.outputTile.data.value.arrayValues.map((value) => value.toInt()),
      [1, 2, 3, 4, 5, 6],
    );
    expect(dut.outputTile.rowMask.value.toInt(), 1);
    expect(dut.outputTile.columnMask.value.toInt(), 5);
    expect(tile.activeAt(0, 0).value, LogicValue.one);
    expect(tile.activeAt(1, 0).value, LogicValue.zero);
    expect(() => tile.activeAt(2, 0), throwsRangeError);
  });

  test('rejects element widths that do not match the numeric format', () {
    expect(
      () => InferenceTensorTile<Logic, LogicValue>(
        rowCount: 2,
        columnCount: 2,
        elementBuilder: ({name}) => Logic(name: name, width: 4),
        format: InferenceNumericFormat.signedInteger(8),
      ),
      throwsArgumentError,
    );
  });
}

class _TensorTilePassThrough extends Module {
  late final InferenceTensorTile<Logic, LogicValue> outputTile;

  _TensorTilePassThrough(InferenceTensorTile<Logic, LogicValue> inputTile)
      : super(definitionName: 'TensorTilePassThrough') {
    inputTile = addTypedInput('inputTile', inputTile);
    outputTile = addTypedOutput('outputTile', inputTile.clone);
    for (var index = 0; index < inputTile.data.arrayElements.length; index++) {
      outputTile.data.arrayElements[index] <=
          inputTile.data.arrayElements[index];
    }
    outputTile.rowMask <= inputTile.rowMask;
    outputTile.columnMask <= inputTile.columnMask;
  }
}
