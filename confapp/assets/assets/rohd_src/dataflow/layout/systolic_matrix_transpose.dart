// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// systolic_matrix_transpose.dart
// Stepped streaming transpose of square matrices.
//
// 2026 November 23
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/src/memory/sequential/shift_register.dart';

/// Transposes a continuous sequence of square matrices one row per step.
///
/// Each enabled step accepts one typed input row and, once [primed] is high,
/// exposes the corresponding row of the previous matrix's transpose before
/// the active clock edge. Lane zero occupies the least significant bits.
/// Input and output advance together; this is not an independently
/// backpressured ready/valid interface. When `step` is low, data and position
/// are held. Reset discards a partial matrix and invalidates the output but
/// does not reset the data registers.
///
/// Unlike a combinational tile transpose, this systolic implementation accepts
/// and emits rows concurrently after its initial [dimension]-step fill.
///
/// [dataOut] retains the input row's element schemas, value codec, and
/// packed/unpacked representation. No numeric conversion is performed.
/// {@category Dataflow}
class SystolicMatrixTranspose<T extends Logic, V> extends Module {
  /// Current transposed row, meaningful only while [primed] is high.
  late final TypedLogicArray<T, V> dataOut;

  /// At least one complete input matrix has been accepted since reset.
  Logic get primed => output('primed');

  /// Number of rows and columns per matrix.
  final int dimension;

  /// Width of one matrix element.
  final int elementWidth;

  /// Creates a transposer for a nonempty, one-dimensional typed row.
  SystolicMatrixTranspose({
    required Logic clk,
    required Logic reset,
    required Logic step,
    required TypedLogicArray<T, V> dataIn,
    super.name = 'systolic_matrix_transpose',
  })  : dimension =
            dataIn.dimensions.length == 1 ? dataIn.dimensions.single : 0,
        elementWidth = dataIn.elementWidth,
        super(
          definitionName:
              'SystolicMatrixTranspose_${payloadShapeIdentity(dataIn)}',
        ) {
    if (dimension < 1 || elementWidth < 1) {
      throw ArgumentError('Matrix input must be a nonempty typed row.');
    }
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    step = addInput('step', step);
    dataIn = addTypedInput('dataIn', dataIn);
    dataOut = addTypedPayloadOutput(this, 'dataOut', dataIn);
    final direction = Logic(name: 'direction');
    final counter = Logic(name: 'counter', width: max(1, dimension.log2Ceil));
    final filled = Logic(name: 'filled');
    final cells = TypedLogicArray<T, V>(
      [dimension, dimension],
      dataIn.arrayElements.first.cloneTyped,
      valueCodec: dataIn.valueCodec,
      name: 'cells',
    );
    T cell(int row, int column) =>
        cells.arrayElements[row * dimension + column];
    for (var row = 0; row < dimension; row++) {
      for (var column = 0; column < dimension; column++) {
        final fromRight = column == dimension - 1
            ? dataIn.arrayElements[row]
            : cell(row, column + 1);
        final fromBelow = row == dimension - 1
            ? dataIn.arrayElements[column]
            : cell(row + 1, column);
        cell(row, column) <=
            ShiftRegister<T>(
              mux<T>(direction, fromBelow, fromRight),
              clk: clk,
              enable: step & ~reset,
              depth: 1,
              name: '${name}_${row}_$column',
              definitionName:
                  'SystolicTransposeCell_${payloadShapeIdentity(fromRight)}',
            ).dataOut;
      }
    }
    for (var index = 0; index < dimension; index++) {
      dataOut.arrayElements[index] <=
          mux<T>(direction, cell(0, index), cell(index, 0));
    }
    addOutput('primed') <= filled & ~reset;
    Sequential(clk, reset: reset, resetValues: {
      counter: 0,
      direction: 0,
      filled: 0,
    }, [
      If(step, then: [
        If(counter.eq(dimension - 1), then: [
          counter < 0,
          direction < ~direction,
          filled < 1,
        ], orElse: [
          counter < counter + 1,
        ]),
      ]),
    ]);
  }
}
