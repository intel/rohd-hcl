// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// grouped_query_attention_distribution.dart
// MHA, GQA, and MQA tensor-tile distribution.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';
import 'package:rohd_hcl/src/inference/inference_tensor_tile.dart';
import 'package:rohd_hcl/src/inference/tensor_multicast.dart';
import 'package:rohd_hcl/src/interfaces/interface_port_helpers.dart';
import 'package:rohd_hcl/src/utils.dart';

/// Static mapping from KV heads to their associated query heads.
///
/// Equal head counts describe multi-head attention, one KV head describes
/// multi-query attention, and intermediate divisors describe grouped-query
/// attention. Query heads associated with one KV head are contiguous.
/// {@category Inference}
@immutable
class GroupedQueryHeadMapping {
  /// Number of query heads.
  final int queryHeadCount;

  /// Number of independently stored key/value heads.
  final int keyValueHeadCount;

  /// Number of query heads sharing each key/value head.
  int get queryHeadsPerKeyValueHead => queryHeadCount ~/ keyValueHeadCount;

  /// Creates a validated MHA, GQA, or MQA mapping.
  const GroupedQueryHeadMapping({
    required this.queryHeadCount,
    required this.keyValueHeadCount,
  }) : assert(
          queryHeadCount > 0 &&
              keyValueHeadCount > 0 &&
              queryHeadCount % keyValueHeadCount == 0,
          'Query heads must be a positive multiple of key/value heads.',
        );

  /// Returns the query-head destination mask for [keyValueHead].
  BigInt destinationMask(int keyValueHead) {
    if (keyValueHead < 0 || keyValueHead >= keyValueHeadCount) {
      throw RangeError.range(
        keyValueHead,
        0,
        keyValueHeadCount - 1,
        'keyValueHead',
      );
    }
    final first = keyValueHead * queryHeadsPerKeyValueHead;
    return ((BigInt.one << queryHeadsPerKeyValueHead) - BigInt.one) << first;
  }
}

/// Routes one KV tile to the query heads that share its KV head.
///
/// [mapping] selects MHA, GQA, or MQA behavior. The runtime `keyValueHead`
/// input is converted to a query-head destination mask and delivered through
/// [TensorTileMulticast]. An out-of-range head is consumed without delivery
/// and pulses [invalidKeyValueHead].
/// {@category Inference}
class GroupedQueryAttentionTileDistributor<TLogic extends Logic, TValue>
    extends Module {
  /// Static query-to-KV head mapping.
  final GroupedQueryHeadMapping mapping;

  /// High while a tile remains pending for selected query heads.
  Logic get occupied => output('occupied');

  /// Pulses when an accepted tile names an invalid KV head.
  Logic get invalidKeyValueHead => output('invalidKeyValueHead');

  late final ReadyValidInterface<InferenceTensorTile<TLogic, TValue>> _upstream;
  late final List<
          IrrevocableReadyValidInterface<InferenceTensorTile<TLogic, TValue>>>
      _downstreams;

  /// Creates a grouped-query tile distributor.
  GroupedQueryAttentionTileDistributor({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<InferenceTensorTile<TLogic, TValue>> upstream,
    required List<ReadyValidInterface<InferenceTensorTile<TLogic, TValue>>>
        downstreams,
    required Logic keyValueHead,
    required this.mapping,
    super.name = 'grouped_query_attention_tile_distributor',
  }) : super(
          definitionName: 'GroupedQueryAttentionTileDistributor_'
              'Q${mapping.queryHeadCount}_K${mapping.keyValueHeadCount}_'
              'R${upstream.data.rowCount}_C${upstream.data.columnCount}_'
              '${upstream.data.format.configurationSignature}',
        ) {
    if (downstreams.length != mapping.queryHeadCount) {
      throw ArgumentError.value(
        downstreams.length,
        'downstreams',
        'Must equal the configured query-head count.',
      );
    }
    final requiredHeadWidth = widthFor(mapping.keyValueHeadCount);
    if (keyValueHead.width < requiredHeadWidth) {
      throw ArgumentError.value(
        keyValueHead.width,
        'keyValueHead',
        'Must represent every configured key/value head.',
      );
    }

    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localKeyValueHead =
        addInput('keyValueHead', keyValueHead, width: keyValueHead.width);
    _upstream = addPairInterface(
      upstream,
      PairRole.consumer,
      uniquify: (original) => 'upstream_$original',
    );
    _downstreams = UnmodifiableListView([
      for (var index = 0; index < downstreams.length; index++)
        addPairInterfaceFrom(
          IrrevocableReadyValidInterface<InferenceTensorTile<TLogic, TValue>>(
            downstreams[index].data.clone(),
          ),
          downstreams[index],
          PairRole.provider,
          uniquify: (original) => 'downstream_${index}_$original',
        ),
    ]);

    final keyValueHeadRangeIsFull = BigInt.from(mapping.keyValueHeadCount) ==
        (BigInt.one << localKeyValueHead.width);
    final validHead = keyValueHeadRangeIsFull
        ? Const(1)
        : localKeyValueHead.lt(mapping.keyValueHeadCount);
    Logic mappedDestinations = Const(0, width: mapping.queryHeadCount);
    for (var head = mapping.keyValueHeadCount - 1; head >= 0; head--) {
      mappedDestinations = mux(
        localKeyValueHead.eq(head),
        Const(
          mapping.destinationMask(head),
          width: mapping.queryHeadCount,
        ),
        mappedDestinations,
      ).named('${name}_destinations_for_head_$head');
    }
    final destinationMask = mux(
      validHead,
      mappedDestinations,
      Const(0, width: mapping.queryHeadCount),
    ).named('${name}_destination_mask');
    final multicast = TensorTileMulticast<TLogic, TValue>(
      clk: localClk,
      reset: localReset,
      upstream: _upstream,
      downstreams: _downstreams,
      destinationMask: destinationMask,
      name: '${name}_multicast',
    );

    addOutput('occupied') <= multicast.occupied;
    addOutput('invalidKeyValueHead') <= _upstream.accepted & ~validHead;
  }
}
