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
import 'package:rohd_hcl/src/dataflow/serialization/ready_valid_depacketizer.dart';
import 'package:rohd_hcl/src/dataflow/serialization/ready_valid_packetizer.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/payloads/ready_valid_frame.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';
import 'package:rohd_hcl/src/inference/inference_tensor_tile.dart';
import 'package:rohd_hcl/src/interfaces/interface_port_helpers.dart';

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
  }) : super(
          [
            data,
            Logic(name: 'rowActive'),
            Logic(name: 'columnActive'),
          ],
          name: name ?? '${data.name}_tensor_element',
        ) {
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
    InferenceTensorTile<TLogic, TValue> resultClone({String? name}) =>
        outputPrototype.clone(name: name);
    result = addTypedOutput<InferenceTensorTile<TLogic, TValue>>(
      'result',
      resultClone,
    );
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

/// Converts ready/valid tiles into row-major framed element streams.
///
/// The implementation flattens data with [ReshapeDescriptor] and delegates all
/// buffering, iteration, framing, and backpressure behavior to
/// [ReadyValidPacketizer].
/// {@category Inference}
class TensorTileUntiler<TLogic extends Logic, TValue> extends Module {
  /// Index of the physical element currently offered downstream.
  Logic get index => output('index');

  /// High while one accepted tile is being emitted.
  Logic get active => output('active');

  /// Creates a row-major tile-to-stream transformer.
  TensorTileUntiler({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<InferenceTensorTile<TLogic, TValue>> upstream,
    required ReadyValidInterface<Frame<InferenceTensorStreamElement<TLogic>>>
        downstream,
    super.name = 'tensor_tile_untiler',
  }) : super(
          definitionName: 'TensorTileUntiler_'
              'R${upstream.data.rowCount}_C${upstream.data.columnCount}_'
              '${upstream.data.format.configurationSignature}',
        ) {
    _validateUntilerInterfaces(upstream, downstream);
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localUpstream = addPairInterface(
      upstream,
      PairRole.consumer,
      uniquify: (original) => 'upstream_$original',
    );
    final localDownstream = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(downstream.data.clone()),
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );
    final rows = upstream.data.rowCount;
    final columns = upstream.data.columnCount;
    final descriptor = ReshapeDescriptor(
      inputShape: LayoutShape([rows, columns]),
      outputShape: LayoutShape([rows * columns]),
    );
    final elementPrototype = localUpstream.data.data.arrayElements.first;
    final flattened =
        TypedLogicArray<InferenceTensorStreamElement<TLogic>, LogicValue>(
      [descriptor.elementCount],
      ({name}) => InferenceTensorStreamElement<TLogic>(
        elementPrototype.clone(name: 'data') as TLogic,
        rowCount: rows,
        columnCount: columns,
        name: name,
      ),
      name: '${name}_flattened',
    );
    for (var outputIndex = 0;
        outputIndex < descriptor.elementCount;
        outputIndex++) {
      final sourceIndex = descriptor.permutation.sourceIndex(outputIndex);
      final coordinates = descriptor.inputShape.unflatten(sourceIndex);
      final outputElement = flattened.arrayElements[outputIndex];
      outputElement.data <= localUpstream.data.data.arrayElements[sourceIndex];
      outputElement.rowActive <= localUpstream.data.rowMask[coordinates[0]];
      outputElement.columnActive <=
          localUpstream.data.columnMask[coordinates[1]];
    }
    final packetInput = ReadyValidInterface(flattened);
    packetInput.valid <= localUpstream.valid;
    localUpstream.ready <= packetInput.ready;
    final packetizer =
        ReadyValidPacketizer<InferenceTensorStreamElement<TLogic>>(
      clk: localClk,
      reset: localReset,
      upstream: packetInput,
      downstream: localDownstream,
      name: '${name}_packetizer',
    );
    addOutput('index', width: packetizer.index.width) <= packetizer.index;
    addOutput('active') <= packetizer.active;
  }
}

/// Collects a row-major framed element stream into a typed tensor tile.
///
/// [ReadyValidDepacketizer] owns storage and framing. The output tile is valid
/// even for a malformed frame, but both masks are cleared and [framingError]
/// or [maskInconsistent] identifies why the data must be discarded.
/// {@category Inference}
class TensorTileTiler<TLogic extends Logic, TValue> extends Module {
  /// High alongside a valid output when the frame length or marker is wrong.
  Logic get framingError => output('framingError');

  /// High alongside a valid output when repeated row/column mask bits differ.
  Logic get maskInconsistent => output('maskInconsistent');

  /// Number of elements collected in the current output frame.
  Logic get collectedElements => output('collectedElements');

  /// Creates a row-major stream-to-tile transformer.
  TensorTileTiler({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<Frame<InferenceTensorStreamElement<TLogic>>>
        upstream,
    required ReadyValidInterface<InferenceTensorTile<TLogic, TValue>>
        downstream,
    super.name = 'tensor_tile_tiler',
  }) : super(
          definitionName: 'TensorTileTiler_'
              'R${downstream.data.rowCount}_C${downstream.data.columnCount}_'
              '${downstream.data.format.configurationSignature}',
        ) {
    _validateTilerInterfaces(upstream, downstream);
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localUpstream = addPairInterface(
      upstream,
      PairRole.consumer,
      uniquify: (original) => 'upstream_$original',
    );
    final localDownstream = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(downstream.data.clone()),
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );
    final rows = downstream.data.rowCount;
    final columns = downstream.data.columnCount;
    final descriptor = ReshapeDescriptor(
      inputShape: LayoutShape([rows * columns]),
      outputShape: LayoutShape([rows, columns]),
    );
    final streamPrototype = localUpstream.data.data;
    final collected = ReadyValidInterface(
      CollectedPacket(
        TypedLogicArray<InferenceTensorStreamElement<TLogic>, LogicValue>(
          [descriptor.elementCount],
          streamPrototype.clone,
          name: '${name}_collected_elements',
        ),
        name: '${name}_collected_packet',
      ),
    );
    ReadyValidDepacketizer<InferenceTensorStreamElement<TLogic>>(
      clk: localClk,
      reset: localReset,
      upstream: localUpstream,
      downstream: collected,
      name: '${name}_depacketizer',
    );

    localDownstream.valid <= collected.valid;
    collected.ready <= localDownstream.ready;
    for (var outputIndex = 0;
        outputIndex < descriptor.elementCount;
        outputIndex++) {
      final sourceIndex = descriptor.permutation.sourceIndex(outputIndex);
      localDownstream.data.data.arrayElements[outputIndex] <=
          collected.data.data.arrayElements[sourceIndex].data;
    }

    final exactLength =
        collected.data.validElements.eq(descriptor.elementCount);
    final frameFailure = collected.data.framingError | ~exactLength;
    final rowReferences = [
      for (var row = 0; row < rows; row++)
        collected.data.data
            .arrayElements[descriptor.outputShape.flatten([row, 0])].rowActive,
    ];
    final columnReferences = [
      for (var column = 0; column < columns; column++)
        collected
            .data
            .data
            .arrayElements[descriptor.outputShape.flatten([0, column])]
            .columnActive,
    ];
    final maskDifferences = <Logic>[];
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final elementIndex = descriptor.outputShape.flatten([row, column]);
        final element = collected.data.data.arrayElements[elementIndex];
        final elementValid = collected.data.validElements.gt(
          Const(elementIndex, width: collected.data.validElements.width),
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
    localDownstream.data.rowMask <=
        [for (final rowActive in rowReferences) metadataValid & rowActive]
            .rconcat();
    localDownstream.data.columnMask <=
        [
          for (final columnActive in columnReferences)
            metadataValid & columnActive,
        ].rconcat();
    addOutput('framingError') <= collected.valid & frameFailure;
    addOutput('maskInconsistent') <= collected.valid & inconsistentMask;
    addOutput(
          'collectedElements',
          width: collected.data.validElements.width,
        ) <=
        collected.data.validElements;
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
      elementBuilder: ({name}) =>
          source.data.arrayElements.first.clone(name: name) as TLogic,
      format: source.format,
      valueCodec: source.data.valueCodec,
      name: name,
      numUnpackedDimensions: min(source.data.numUnpackedDimensions, 2),
    );

void _validateUntilerInterfaces<TLogic extends Logic, TValue>(
  ReadyValidInterface<InferenceTensorTile<TLogic, TValue>> upstream,
  ReadyValidInterface<Frame<InferenceTensorStreamElement<TLogic>>> downstream,
) {
  if (downstream.data.data.rowCount != upstream.data.rowCount ||
      downstream.data.data.columnCount != upstream.data.columnCount ||
      downstream.data.data.data.width != upstream.data.data.elementWidth) {
    throw ArgumentError('Tensor untiler interface shapes do not match.');
  }
}

void _validateTilerInterfaces<TLogic extends Logic, TValue>(
  ReadyValidInterface<Frame<InferenceTensorStreamElement<TLogic>>> upstream,
  ReadyValidInterface<InferenceTensorTile<TLogic, TValue>> downstream,
) {
  if (upstream.data.data.rowCount != downstream.data.rowCount ||
      upstream.data.data.columnCount != downstream.data.columnCount ||
      upstream.data.data.data.width != downstream.data.data.elementWidth) {
    throw ArgumentError('Tensor tiler interface shapes do not match.');
  }
}
