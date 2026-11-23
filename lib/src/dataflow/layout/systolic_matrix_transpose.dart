// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/sequential/shift_register.dart';

/// Transposes a continuous sequence of square matrices one row per step.
///
/// Each enabled step accepts one packed input row and, once [primed] is high,
/// exposes the corresponding row of the previous matrix's transpose before
/// the active clock edge. Lane zero occupies the least significant bits.
/// Input and output advance together; this is not an independently
/// backpressured ready/valid interface. When `step` is low, data and position
/// are held. Reset discards a partial matrix and invalidates the output but
/// does not reset the data registers.
///
/// Unlike a combinational tile transpose, this systolic implementation accepts
/// and emits rows concurrently after its initial [dimension]-step fill.
/// {@category Dataflow}
class SystolicMatrixTranspose extends Module {
  /// Current output row. It is meaningful only when [primed] is high.
  Logic get dataOut => output('dataOut');

  /// At least one complete input matrix has been accepted since reset.
  Logic get primed => output('primed');

  /// Number of rows and columns per matrix.
  final int dimension;

  /// Width of one matrix element.
  final int elementWidth;

  /// Creates a step-driven transposer.
  SystolicMatrixTranspose({
    required Logic clk,
    required Logic reset,
    required Logic step,
    required Logic dataIn,
    required this.dimension,
    required this.elementWidth,
    super.name = 'systolic_matrix_transpose',
  }) : super(
          definitionName:
              'SystolicMatrixTranspose_N${dimension}_W$elementWidth',
        ) {
    if (dimension < 1 ||
        elementWidth < 1 ||
        dataIn.width != dimension * elementWidth) {
      throw ArgumentError(
          'Matrix dimension and element width must be positive, and the '
          'input width must equal their product.');
    }
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    step = addInput('step', step);
    dataIn = addInput('dataIn', dataIn, width: dimension * elementWidth);

    final direction = Logic(name: 'direction');
    final counter = Logic(name: 'counter', width: max(1, dimension.log2Ceil));
    final filled = Logic(name: 'filled');
    final cells = List.generate(
        dimension,
        (row) => List.generate(
            dimension,
            (column) =>
                Logic(name: 'cell_${row}_$column', width: elementWidth)));
    Logic lane(int index) =>
        dataIn.getRange(index * elementWidth, (index + 1) * elementWidth);
    for (var row = 0; row < dimension; row++) {
      for (var column = 0; column < dimension; column++) {
        final fromRight =
            column == dimension - 1 ? lane(row) : cells[row][column + 1];
        final fromBelow =
            row == dimension - 1 ? lane(column) : cells[row + 1][column];
        cells[row][column] <=
            ShiftRegister<Logic>(
              mux(direction, fromBelow, fromRight),
              clk: clk,
              enable: step & ~reset,
              depth: 1,
              name: '${name}_${row}_$column',
            ).dataOut;
      }
    }
    addOutput('dataOut', width: dimension * elementWidth) <=
        [
          for (var index = 0; index < dimension; index++)
            mux(direction, cells[0][index], cells[index][0])
        ].rconcat();
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
