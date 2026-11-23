// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/accumulation/accumulator.dart';

/// Traverses rectangular pooling windows and optional horizontal output splits.
///
/// The caller validates and retains the geometry until traversal ends.
/// Dimensions, groups, kernels and strides must be nonzero; split widths must
/// be valid for the selected split count. Inputs are unsigned and at most
/// 16 bits wide. `restart` clears the coordinates and takes priority over
/// advances. `advanceTerm` consumes a kernel position in x-then-y order.
/// After the last term the caller must assert `advanceOutput` before consuming
/// another term. That signal resets the kernel coordinates and advances output
/// x, y, group, then split. The caller must not assert both advances together.
///
/// [inputX] and [inputY] are unsigned 64-bit values. They are meaningful only
/// when [inBounds] is high; otherwise the caller supplies its padding value or
/// ignores the term. The component neither stores samples nor initiates
/// transactions. The caller stalls the advances until its stream or memory
/// handshake has completed and handles aborts and geometry errors itself.
/// {@category Inference}
class PoolingWindowSequencer extends Module {
  /// Current x coordinate within the current output split.
  Logic get x => output('x');

  /// Current output row.
  Logic get y => output('y');

  /// Current output channel group.
  Logic get group => output('group');

  /// Current horizontal split index.
  Logic get split => output('split');

  /// Current horizontal kernel position.
  Logic get kernelX => output('kernelX');

  /// Current vertical kernel position.
  Logic get kernelY => output('kernelY');

  /// Global output x coordinate across splits.
  Logic get outputX => output('outputX');

  /// Input x coordinate, valid only when [inBounds] is high.
  Logic get inputX => output('inputX');

  /// Input y coordinate, valid only when [inBounds] is high.
  Logic get inputY => output('inputY');

  /// Whether the current term is within the input rectangle.
  Logic get inBounds => output('inBounds');

  /// Whether the current output is the final one in the traversal.
  Logic get lastOutput => output('lastOutput');

  /// Whether the current term is the final one in its window.
  Logic get lastTerm => output('lastTerm');

  /// Creates a window sequencer with runtime geometry.
  ///
  /// [splitCount] is the number of additional splits. When it is zero,
  /// [outputWidth] is used; otherwise first, middle and last split widths
  /// describe the output and must sum to [outputWidth].
  PoolingWindowSequencer({
    required Logic clk,
    required Logic reset,
    required Logic restart,
    required Logic advanceTerm,
    required Logic advanceOutput,
    required Logic inputWidth,
    required Logic inputHeight,
    required Logic outputWidth,
    required Logic outputHeight,
    required Logic groups,
    required Logic kernelWidth,
    required Logic kernelHeight,
    required Logic strideX,
    required Logic strideY,
    required Logic padLeft,
    required Logic padTop,
    required Logic splitCount,
    required Logic outputWidthFirst,
    required Logic outputWidthMiddle,
    required Logic outputWidthLast,
    super.name = 'pooling_window_sequencer',
  }) : super(
          definitionName: 'PoolingWindowSequencer_'
              '${[
            inputWidth,
            inputHeight,
            outputWidth,
            outputHeight,
            groups,
            kernelWidth,
            kernelHeight,
            strideX,
            strideY,
            padLeft,
            padTop,
            splitCount,
            outputWidthFirst,
            outputWidthMiddle,
            outputWidthLast,
          ].map((signal) => signal.width).join('_')}',
        ) {
    final geometry = [
      inputWidth,
      inputHeight,
      outputWidth,
      outputHeight,
      groups,
      kernelWidth,
      kernelHeight,
      strideX,
      strideY,
      padLeft,
      padTop,
      splitCount,
      outputWidthFirst,
      outputWidthMiddle,
      outputWidthLast,
    ];
    if (geometry.any((signal) => signal.width < 1 || signal.width > 16)) {
      throw ArgumentError('Geometry input widths must be between 1 and 16.');
    }
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    restart = addInput('restart', restart);
    advanceTerm = addInput('advanceTerm', advanceTerm);
    advanceOutput = addInput('advanceOutput', advanceOutput);
    Logic input(String name, Logic value) =>
        addInput(name, value, width: value.width);
    inputWidth = input('inputWidth', inputWidth);
    inputHeight = input('inputHeight', inputHeight);
    outputWidth = input('outputWidth', outputWidth);
    outputHeight = input('outputHeight', outputHeight);
    groups = input('groups', groups);
    kernelWidth = input('kernelWidth', kernelWidth);
    kernelHeight = input('kernelHeight', kernelHeight);
    strideX = input('strideX', strideX);
    strideY = input('strideY', strideY);
    padLeft = input('padLeft', padLeft);
    padTop = input('padTop', padTop);
    splitCount = input('splitCount', splitCount);
    outputWidthFirst = input('outputWidthFirst', outputWidthFirst);
    outputWidthMiddle = input('outputWidthMiddle', outputWidthMiddle);
    outputWidthLast = input('outputWidthLast', outputWidthLast);

    Logic wide(Logic value) => value.zeroExtend(64);
    Logic counter(String name, int width, Logic step, Logic clear) =>
        Accumulator(Const(1),
                clk: clk,
                reset: reset,
                width: width,
                enable: step,
                clear: clear,
                name: name)
            .value;
    final lastX = Logic(name: 'lastX');
    final lastY = Logic(name: 'lastY');
    final lastGroup = Logic(name: 'lastGroup');
    final lastKernelX = Logic(name: 'lastKernelX');
    final lastKernelY = Logic(name: 'lastKernelY');
    final x = counter('x_count', outputWidth.width, advanceOutput,
        restart | (advanceOutput & lastX));
    final y = counter('y_count', outputHeight.width, advanceOutput & lastX,
        restart | (advanceOutput & lastX & lastY));
    final splitFinished = advanceOutput & lastX & lastY & lastGroup;
    final group = counter('group_count', groups.width,
        advanceOutput & lastX & lastY, restart | splitFinished);
    final split =
        counter('split_count', splitCount.width, splitFinished, restart);
    final kx = counter('kernel_x_count', kernelWidth.width, advanceTerm,
        restart | advanceOutput | (advanceTerm & lastKernelX));
    final ky = counter('kernel_y_count', kernelHeight.width,
        advanceTerm & lastKernelX, restart | advanceOutput);
    final splitEnabled = splitCount.neq(0);
    final splitWidth = mux(
        ~splitEnabled,
        wide(outputWidth),
        mux(
            split.eq(0),
            wide(outputWidthFirst),
            mux(split.eq(splitCount), wide(outputWidthLast),
                wide(outputWidthMiddle))));
    lastX <= wide(x).eq(splitWidth - 1);
    lastY <= wide(y).eq(wide(outputHeight) - 1);
    lastGroup <= wide(group).eq(wide(groups) - 1);
    lastKernelX <= wide(kx).eq(wide(kernelWidth) - 1);
    lastKernelY <= wide(ky).eq(wide(kernelHeight) - 1);
    final splitOffset = mux(split.eq(0), Const(0, width: 64),
        wide(outputWidthFirst) + (wide(split) - 1) * wide(outputWidthMiddle));
    final outputX =
        wide(x) + mux(splitEnabled, splitOffset, Const(0, width: 64));
    final rawX = outputX * wide(strideX) + wide(kx);
    final rawY = wide(y) * wide(strideY) + wide(ky);
    final inputX = rawX - wide(padLeft);
    final inputY = rawY - wide(padTop);
    addOutput('x', width: x.width) <= x;
    addOutput('y', width: y.width) <= y;
    addOutput('group', width: group.width) <= group;
    addOutput('split', width: split.width) <= split;
    addOutput('kernelX', width: kx.width) <= kx;
    addOutput('kernelY', width: ky.width) <= ky;
    addOutput('outputX', width: 64) <= outputX;
    addOutput('inputX', width: 64) <= inputX;
    addOutput('inputY', width: 64) <= inputY;
    addOutput('inBounds') <=
        rawX.gte(wide(padLeft)) &
            rawY.gte(wide(padTop)) &
            inputX.lt(wide(inputWidth)) &
            inputY.lt(wide(inputHeight));
    addOutput('lastOutput') <= lastX & lastY & lastGroup & split.eq(splitCount);
    addOutput('lastTerm') <= lastKernelX & lastKernelY;
  }
}
