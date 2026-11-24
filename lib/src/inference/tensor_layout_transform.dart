// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_layout_transform.dart
// Typed tensor transpose, tiling, and untiling transformations.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/dataflow/layout/layout_shape.dart';
import 'package:rohd_hcl/src/dataflow/layout/reshape_descriptor.dart';
import 'package:rohd_hcl/src/dataflow/layout/transpose_descriptor.dart';
import 'package:rohd_hcl/src/dataflow/layout/typed_static_permutation.dart';
import 'package:rohd_hcl/src/dataflow/serialization/scheduled_deserializer_engine.dart';
import 'package:rohd_hcl/src/dataflow/serialization/scheduled_serializer_engine.dart';
import 'package:rohd_hcl/src/flow_control/attachments/directional_attachments.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/payloads/ready_valid_frame.dart';
import 'package:rohd_hcl/src/inference/inference_tensor_tile.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/src/utils.dart';

/// One row-major tensor element with repeated tile-mask metadata.
///
/// Repeating [rowActive] and [columnActive] on every physical element lets a
/// framed stream preserve independent row and column masks without carrying
/// the complete vectors on every beat.
/// {@category Inference}
class InferenceTensorStreamElement<TLogic extends Logic>
    extends LogicStructure {
  /// Tensor element data.
  TLogic get data => elements[0] as TLogic;

  /// Activity of this element's physical row.
  Logic get rowActive => elements[1];

  /// Activity of this element's physical column.
  Logic get columnActive => elements[2];

  /// Number of physical rows in the represented tile.
  final int rowCount;

  /// Number of physical columns in the represented tile.
  final int columnCount;

  /// Creates a streamed tensor element.
  InferenceTensorStreamElement(
    TLogic data, {
    required this.rowCount,
    required this.columnCount,
    String? name,
  }) : super([
          data,
          Logic(name: 'rowActive'),
          Logic(name: 'columnActive'),
        ], name: name ?? '${data.name}_tensor_element') {
    if (rowCount < 1 || columnCount < 1) {
      throw ArgumentError('Streamed tensor dimensions must be positive.');
    }
  }

  InferenceTensorStreamElement._clone(
    LogicStructure original, {
    required this.rowCount,
    required this.columnCount,
    String? name,
  }) : super(
          original.elements
              .map((element) => element.clone(name: element.name))
              .toList(),
          name: name ?? original.name,
        );

  @override
  InferenceTensorStreamElement<TLogic> clone({String? name}) =>
      InferenceTensorStreamElement<TLogic>._clone(
        this,
        rowCount: rowCount,
        columnCount: columnCount,
        name: name,
      );
}

/// Statically transposes a typed inference tile.
///
/// Element mapping comes from [TransposeDescriptor] and is implemented by
/// [TypedStaticPermutation]. Row and column masks exchange roles.
/// {@category Inference}
class TensorTileTranspose<TLogic extends Logic, TValue> extends Module {
  /// Matrix-transpose descriptor used by this instance.
  final TransposeDescriptor descriptor;

  /// Transposed tile.
  late final InferenceTensorTile<TLogic, TValue> result;

  /// Creates a combinational tile transpose.
  TensorTileTranspose(
    InferenceTensorTile<TLogic, TValue> inputTile, {
    super.name = 'tensor_tile_transpose',
  })  : descriptor = TransposeDescriptor.matrix(
          rows: inputTile.rowCount,
          columns: inputTile.columnCount,
        ),
        super(
          definitionName: 'TensorTileTranspose_'
              'R${inputTile.rowCount}_C${inputTile.columnCount}_'
              '${inputTile.format.configurationSignature}',
        ) {
    final outputPrototype = _tileLike(
      inputTile,
      rows: inputTile.columnCount,
      columns: inputTile.rowCount,
      name: '${name}_result_prototype',
    );
    final localInput = addTypedInput<InferenceTensorTile<TLogic, TValue>>(
      'inputTile',
      inputTile,
    );
    result = addTypedPayloadOutput(this, 'result', outputPrototype);
    final localResult = result;
    final permutation = TypedStaticPermutation<TLogic, TValue>(
      localInput.data,
      outputPrototype: outputPrototype.data,
      descriptor: descriptor.permutation,
      name: '${name}_permutation',
    );

    for (var index = 0;
        index < localResult.data.arrayElements.length;
        index++) {
      localResult.data.arrayElements[index] <=
          permutation.result.arrayElements[index];
    }
    localResult.rowMask <= localInput.columnMask;
    localResult.columnMask <= localInput.rowMask;
  }
}

/// Captures a tile on `load` and emits row-major framed elements.
///
/// The implementation flattens data with [ReshapeDescriptor] and delegates all
/// storage and iteration to [ScheduledSerializerEngine]. With `advance`
/// omitted, the first element appears immediately after the load edge,
/// followed by one element each cycle for exactly `rows * columns` cycles,
/// without backpressure. A scheduler may instead drive `advance` explicitly.
/// Load only while idle or when advancing the final element; that final edge
/// can load the next tile without a bubble. Synchronous reset discards it.
/// {@category Inference}
class TensorTileUntiler<TLogic extends Logic, TValue> extends Module {
  /// Currently offered element and final-element marker.
  late final Frame<InferenceTensorStreamElement<TLogic>> result;

  /// Index of the physical element currently offered downstream.
  Logic get index => output('index');

  /// High while one accepted tile is being emitted.
  Logic get active => output('active');

  /// Creates a row-major tile-to-stream transformer.
  TensorTileUntiler({
    required Logic clk,
    required Logic reset,
    required InferenceTensorTile<TLogic, TValue> inputTile,
    required InferenceTensorStreamElement<TLogic> elementSchema,
    required Logic load,
    Logic? advance,
    super.name = 'tensor_tile_untiler',
  }) : super(
          definitionName: 'TensorTileUntiler_'
              '${payloadShapesIdentity([inputTile, elementSchema])}',
        ) {
    _validateTileStream(inputTile, elementSchema);
    advance ??= Const(1);
    const actionPolicy = SynchronousActionAttachmentPolicy();
    actionPolicy
      ..validateAction(load, name: 'load')
      ..validateAction(advance, name: 'advance');
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localLoad = addInput('load', load);
    final localAdvance = addInput('advance', advance);
    final localInput = addTypedInput<InferenceTensorTile<TLogic, TValue>>(
      'inputTile',
      inputTile,
    );
    result = addTypedPayloadOutput(
      this,
      'result',
      Frame(cloneTypedPayload(elementSchema)),
    );
    final rows = inputTile.rowCount;
    final columns = inputTile.columnCount;
    final descriptor = ReshapeDescriptor(
      inputShape: LayoutShape([rows, columns]),
      outputShape: LayoutShape([rows * columns]),
    );
    final flattened =
        TypedLogicArray<InferenceTensorStreamElement<TLogic>, LogicValue>(
      [descriptor.elementCount],
      result.data.clone,
      name: '${name}_flattened',
    );
    for (var outputIndex = 0;
        outputIndex < descriptor.elementCount;
        outputIndex++) {
      final sourceIndex = descriptor.permutation.sourceIndex(outputIndex);
      final coordinates = descriptor.inputShape.unflatten(sourceIndex);
      final outputElement = flattened.arrayElements[outputIndex];
      outputElement.data <= localInput.data.arrayElements[sourceIndex];
      outputElement.rowActive <= localInput.rowMask[coordinates[0]];
      outputElement.columnActive <= localInput.columnMask[coordinates[1]];
    }
    final engine =
        ScheduledSerializerEngine<InferenceTensorStreamElement<TLogic>>(
      clk: localClk,
      reset: localReset,
      loadData: flattened,
      load: localLoad,
      advance: localAdvance,
      clear: Const(0),
      name: '${name}_engine',
    );
    result.data <= engine.data;
    result.last <= engine.last;
    addOutput('index', width: engine.index.width) <= engine.index;
    addOutput('active') <= engine.active;
  }
}

/// Collects a row-major framed element stream into a typed tensor tile.
///
/// Each asserted `write` stores one element; there is no ownership-transfer
/// protocol or backpressure. Drive `write` on consecutive edges for strict
/// cycle-accurate collection. [complete] pulses immediately after the final
/// physical element or an early `last` marker is written. The next write starts
/// a new tile, so the caller must consume or retain the result before it.
/// Synchronous reset discards partial collection without clearing data storage.
///
/// A malformed frame also completes, but both masks are cleared and
/// [framingError] or [maskInconsistent] identifies why it must be discarded.
/// Diagnostics are meaningful on completion; subsequent writes may change them.
/// {@category Inference}
class TensorTileTiler<TLogic extends Logic, TValue> extends Module {
  /// Collected tile, meaningful on [complete] until the next write.
  late final InferenceTensorTile<TLogic, TValue> result;

  /// Pulses after a write completes a tile.
  Logic get complete => output('complete');

  /// Index receiving the next written element.
  Logic get index => output('index');

  /// High when the completed frame length or marker is wrong.
  Logic get framingError => output('framingError');

  /// High when repeated row/column mask bits differ in the completed frame.
  Logic get maskInconsistent => output('maskInconsistent');

  /// Number of elements collected in the current output frame.
  Logic get collectedElements => output('collectedElements');

  /// Creates a row-major stream-to-tile transformer.
  TensorTileTiler({
    required Logic clk,
    required Logic reset,
    required Frame<InferenceTensorStreamElement<TLogic>> element,
    required Logic write,
    required InferenceTensorTile<TLogic, TValue> tileSchema,
    super.name = 'tensor_tile_tiler',
  }) : super(
          definitionName: 'TensorTileTiler_'
              '${payloadShapesIdentity([element, tileSchema])}',
        ) {
    _validateTileStream(tileSchema, element.data);
    const SynchronousActionAttachmentPolicy()
        .validateAction(write, name: 'write');
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localWrite = addInput('write', write);
    final localElement =
        addTypedInput<Frame<InferenceTensorStreamElement<TLogic>>>(
      'element',
      element,
    );
    result = addTypedPayloadOutput(this, 'result', tileSchema);
    final rows = tileSchema.rowCount;
    final columns = tileSchema.columnCount;
    final descriptor = ReshapeDescriptor(
      inputShape: LayoutShape([rows * columns]),
      outputShape: LayoutShape([rows, columns]),
    );
    final engine =
        ScheduledDeserializerEngine<InferenceTensorStreamElement<TLogic>>(
      clk: localClk,
      reset: localReset,
      element: localElement.data,
      write: localWrite,
      last: localElement.last,
      clear: Const(0),
      length: descriptor.elementCount,
      name: '${name}_engine',
    );
    final count = Logic(
      name: '${name}_count',
      width: widthFor(descriptor.elementCount + 1),
    );
    final missingLast = Logic(name: '${name}_missing_last');
    Sequential(localClk, reset: localReset, resetValues: {
      count: 0,
      missingLast: 0,
    }, [
      If(
          localWrite &
              (localElement.last |
                  engine.index.eq(descriptor.elementCount - 1)),
          then: [
            count <
                engine.index.zeroExtend(count.width) +
                    Const(1, width: count.width),
            missingLast < ~localElement.last,
          ]),
    ]);

    for (var outputIndex = 0;
        outputIndex < descriptor.elementCount;
        outputIndex++) {
      final sourceIndex = descriptor.permutation.sourceIndex(outputIndex);
      result.data.arrayElements[outputIndex] <=
          engine.data.arrayElements[sourceIndex].data;
    }

    final exactLength = count.eq(
      descriptor.elementCount,
    );
    final frameFailure = missingLast | ~exactLength;
    final rowReferences = [
      for (var row = 0; row < rows; row++)
        engine.data.arrayElements[descriptor.outputShape.flatten([row, 0])]
            .rowActive,
    ];
    final columnReferences = [
      for (var column = 0; column < columns; column++)
        engine.data.arrayElements[descriptor.outputShape.flatten([0, column])]
            .columnActive,
    ];
    final maskDifferences = <Logic>[];
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final elementIndex = descriptor.outputShape.flatten([row, column]);
        final element = engine.data.arrayElements[elementIndex];
        final elementValid = count.gt(
          Const(elementIndex, width: count.width),
        );
        maskDifferences
          ..add(elementValid & element.rowActive.neq(rowReferences[row]))
          ..add(
            elementValid & element.columnActive.neq(columnReferences[column]),
          );
      }
    }
    final inconsistentMask = maskDifferences.rconcat().or();
    final metadataValid = ~frameFailure & ~inconsistentMask;
    result.rowMask <=
        [for (final rowActive in rowReferences) metadataValid & rowActive]
            .rconcat();
    result.columnMask <=
        [
          for (final columnActive in columnReferences)
            metadataValid & columnActive,
        ].rconcat();
    addOutput('framingError') <= frameFailure;
    addOutput('maskInconsistent') <= inconsistentMask;
    addOutput('collectedElements', width: count.width) <= count;
    addOutput('index', width: engine.index.width) <= engine.index;
    addOutput('complete') <= engine.complete;
  }
}

InferenceTensorTile<TLogic, TValue> _tileLike<TLogic extends Logic, TValue>(
  InferenceTensorTile<TLogic, TValue> source, {
  required int rows,
  required int columns,
  required String name,
}) =>
    InferenceTensorTile<TLogic, TValue>(
      rowCount: rows,
      columnCount: columns,
      elementBuilder: ({name}) => cloneTypedPayload<TLogic>(
          source.data.arrayElements.first,
          name: name),
      format: source.format,
      valueCodec: source.data.valueCodec,
      name: name,
      numUnpackedDimensions: min(source.data.numUnpackedDimensions, 2),
    );

void _validateTileStream<TLogic extends Logic, TValue>(
  InferenceTensorTile<TLogic, TValue> tile,
  InferenceTensorStreamElement<TLogic> element,
) {
  if (element.rowCount != tile.rowCount ||
      element.columnCount != tile.columnCount ||
      tile.data.arrayElements.any(
        (lane) => !compatiblePayloadConnection(lane, element.data),
      )) {
    throw ArgumentError('Tensor tile and stream shapes do not match.');
  }
}
