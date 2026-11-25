// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_multicast.dart
// Typed tensor-tile distribution over the generic selective fork.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/flow_control/control/selective_fork_core.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';
import 'package:rohd_hcl/src/inference/inference_tensor_tile.dart';
import 'package:rohd_hcl/src/interfaces/interface_port_helpers.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// Retains one typed tile until every selected destination completes.
///
/// `advance` acknowledges the currently offered copies, independently of
/// `load`. A new tile may be loaded on the final completion cycle. A zero
/// selection is consumed without retaining a tile.
/// {@category Inference}
class TensorTileMulticastCore<TLogic extends Logic, TValue> extends Module {
  /// Whether a new tile can be loaded on this cycle.
  Logic get canLoad => output('canLoad');

  /// Whether the current load is accepted.
  Logic get loadAccepted => output('loadAccepted');

  /// Whether any selected destination still has a pending copy.
  Logic get occupied => output('occupied');

  /// One bit per destination that currently has a pending copy.
  Logic get outputValidMask => output('outputValidMask');

  /// The retained tile, meaningful for the destinations in [outputValidMask].
  late final InferenceTensorTile<TLogic, TValue> retainedTile;

  /// Creates a tile core with explicit load and per-destination advance.
  TensorTileMulticastCore({
    required Logic clk,
    required Logic reset,
    required InferenceTensorTile<TLogic, TValue> tile,
    required Logic selection,
    required Logic load,
    required Logic advance,
    super.name = 'tensor_tile_multicast_core',
  }) : super(
          definitionName: 'TensorTileMulticastCore_'
              '${selection.width}_${tile.format.configurationSignature}_'
              '${payloadShapeIdentity(tile)}',
        ) {
    if (advance.width != selection.width) {
      throw ArgumentError('Advance and selection masks must match in width.');
    }
    final localTile = addTypedInput('tile', tile);
    final binding =
        SelectiveForkCoreFunctor<InferenceTensorTile<TLogic, TValue>>(
      outputCount: selection.width,
    ).construct(
      SelectiveForkCoreRequest(
        clk: addInput('clk', clk),
        reset: addInput('reset', reset),
        payload: localTile,
        selection: addInput('selection', selection, width: selection.width),
        load: addInput('load', load),
        advance: addInput('advance', advance, width: selection.width),
      ),
      name: '${name}_fork',
    );
    retainedTile = addTypedPayloadOutput(this, 'retainedTile', localTile);
    retainedTile <= binding.retainedPayload;
    addOutput('canLoad') <= binding.canLoad;
    addOutput('loadAccepted') <= binding.loadAccepted;
    addOutput('occupied') <= binding.occupied;
    addOutput('outputValidMask', width: selection.width) <=
        binding.outputValidMask;
  }
}

/// Distributes each accepted tensor tile to selected ready/valid consumers.
///
/// The destination mask is captured atomically with the tile. Each selected
/// consumer receives exactly one irrevocable copy, independently of the other
/// consumers' backpressure. Omitting `destinationMask` broadcasts every tile
/// to every consumer.
///
/// Storage and per-destination completion tracking are delegated to
/// [TensorTileMulticastCore]. This adapter is internal to inference.
/// {@category Inference}
class TensorTileMulticast<TLogic extends Logic, TValue> extends Module {
  /// Number of independently completed destinations.
  final int destinationCount;

  /// High while a tile remains pending for at least one destination.
  Logic get occupied => output('occupied');

  late final ReadyValidInterface<InferenceTensorTile<TLogic, TValue>> _upstream;
  late final List<
          IrrevocableReadyValidInterface<InferenceTensorTile<TLogic, TValue>>>
      _downstreams;

  /// Creates a lossless tensor-tile multicast.
  TensorTileMulticast({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<InferenceTensorTile<TLogic, TValue>> upstream,
    required List<ReadyValidInterface<InferenceTensorTile<TLogic, TValue>>>
        downstreams,
    Logic? destinationMask,
    super.name = 'tensor_tile_multicast',
  })  : destinationCount = downstreams.length,
        super(
          definitionName: 'TensorTileMulticast_'
              'N${downstreams.length}_R${upstream.data.rowCount}_'
              'C${upstream.data.columnCount}_'
              '${upstream.data.format.configurationSignature}_'
              'M${destinationMask == null ? 'A' : 'R'}',
        ) {
    if (downstreams.isEmpty) {
      throw ArgumentError.value(
        downstreams,
        'downstreams',
        'Must contain at least one destination.',
      );
    }
    if (destinationMask != null &&
        destinationMask.width != downstreams.length) {
      throw ArgumentError.value(
        destinationMask,
        'destinationMask',
        'Must have one bit per destination.',
      );
    }
    for (var index = 0; index < downstreams.length; index++) {
      final destination = downstreams[index].data;
      if (destination.format != upstream.data.format ||
          !samePayloadShapeAllowingRenamedClone(upstream.data, destination)) {
        throw ArgumentError(
          'Destination $index tile shape and format must match upstream.',
        );
      }
    }

    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localDestinationMask = destinationMask == null
        ? Const((BigInt.one << destinationCount) - BigInt.one,
            width: destinationCount)
        : addInput(
            'destinationMask',
            destinationMask,
            width: destinationCount,
          );
    _upstream = addPairInterface(
      upstream,
      PairRole.consumer,
      uniquify: (original) => 'upstream_$original',
    );
    _downstreams = UnmodifiableListView([
      for (var index = 0; index < destinationCount; index++)
        addPairInterfaceFrom(
          IrrevocableReadyValidInterface<InferenceTensorTile<TLogic, TValue>>(
            downstreams[index].data.clone(),
          ),
          downstreams[index],
          PairRole.provider,
          uniquify: (original) => 'downstream_${index}_$original',
        ),
    ]);

    final advance = Logic(width: destinationCount);
    final core = TensorTileMulticastCore<TLogic, TValue>(
      clk: localClk,
      reset: localReset,
      tile: _upstream.data,
      selection: localDestinationMask,
      load: _upstream.valid,
      advance: advance,
      name: '${name}_core',
    );
    advance <=
        core.outputValidMask &
            _downstreams
                .map((downstream) => downstream.ready)
                .toList()
                .rconcat();
    _upstream.ready <= core.canLoad;
    for (final (index, downstream) in _downstreams.indexed) {
      downstream.valid <= core.outputValidMask[index];
      downstream.data <= core.retainedTile;
    }
    addOutput('occupied') <= core.occupied;
  }
}
