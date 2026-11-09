// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_queue.dart
// Configurable ready/valid queue policies built on elastic storage.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Empty-queue visibility policy for [ReadyValidQueue].
enum ReadyValidQueuePolicy {
  /// An empty queue accepts an item before presenting it downstream.
  registered,

  /// An empty queue presents its upstream offer combinationally downstream.
  fallThrough
}

/// Storage architecture used by [ReadyValidQueue].
enum ReadyValidQueueStorage {
  /// A chain of one-entry elastic registers.
  registers,

  /// A pointer-based ring buffer backed by the released [Fifo].
  ring
}

/// A configurable ready/valid queue assembled from elastic storage stages.
///
/// [policy] selects whether empty storage may bypass data. [storage] selects
/// either elastic registers or a pointer-based ring buffer. [flush]
/// synchronously discards all retained entries at its active clock edge. The
/// downstream offer is irrevocable once any item is retained.
/// {@category Memory}
class ReadyValidQueue<LogicType extends Logic> extends Module
    implements ReadyValidStorageStatus {
  /// Number of entries in the queue.
  final int depth;

  @override
  int get capacity => depth;

  /// Empty-queue visibility behavior.
  final ReadyValidQueuePolicy policy;

  /// Storage architecture used to retain queued items.
  final ReadyValidQueueStorage storage;

  /// Occupancy at or above this value asserts [almostFull].
  final int almostFullThreshold;

  /// Occupancy at or below this value asserts [almostEmpty].
  final int almostEmptyThreshold;

  /// Upstream interface accepted by this queue.
  late final ReadyValidInterface<LogicType> upstream;

  /// Downstream interface driven by this queue.
  late final IrrevocableReadyValidInterface<LogicType> downstream;

  /// Number of retained entries.
  @override
  Logic get occupancy => output('occupancy');

  /// High when no entry is retained.
  @override
  Logic get empty => output('empty');

  /// High when every entry is retained.
  @override
  Logic get full => output('full');

  /// High when occupancy reaches [almostFullThreshold].
  Logic get almostFull => output('almostFull');

  /// High when occupancy is at most [almostEmptyThreshold].
  Logic get almostEmpty => output('almostEmpty');

  /// Clock used by the queue.
  @protected
  late final Logic clk;

  /// Reset used by the queue.
  @protected
  late final Logic reset;

  /// Optional synchronous retained-data flush.
  @protected
  late final Logic flush;

  /// Creates a ready/valid queue with explicit storage policy.
  ReadyValidQueue(
      {required Logic clk,
      required Logic reset,
      required ReadyValidInterface<LogicType> upstream,
      required ReadyValidInterface<LogicType> downstream,
      required this.depth,
      this.policy = ReadyValidQueuePolicy.registered,
      this.storage = ReadyValidQueueStorage.registers,
      int? almostFullThreshold,
      int? almostEmptyThreshold,
      Logic? flush,
      String name = 'ready_valid_queue'})
      : almostFullThreshold = almostFullThreshold ?? depth,
        almostEmptyThreshold = almostEmptyThreshold ?? 0,
        super(
            definitionName: 'ReadyValidQueue_D${depth}_'
                '${policy == ReadyValidQueuePolicy.fallThrough ? 'F' : 'R'}_'
                '${storage == ReadyValidQueueStorage.ring ? 'Ring' : 'Regs'}_'
                'AF${almostFullThreshold ?? depth}_'
                'AE${almostEmptyThreshold ?? 0}_'
                '${upstream.data.name}',
            name: name) {
    if (depth < 1) {
      throw ArgumentError.value(depth, 'depth', 'Must be at least one.');
    }
    if (this.almostFullThreshold < 0 ||
        this.almostFullThreshold > depth ||
        this.almostEmptyThreshold < 0 ||
        this.almostEmptyThreshold > depth) {
      throw ArgumentError(
          'Queue thresholds must be between zero and depth inclusive.');
    }

    this.clk = addInput('clk', clk);
    this.reset = addInput('reset', reset);
    this.flush = flush == null ? Const(0) : addInput('flush', flush);
    this.upstream = addPairInterfacePorts(upstream, PairRole.consumer,
        uniquify: (original) => 'upstream_$original');
    this.downstream = addPairInterfaceFrom(
      IrrevocableReadyValidInterface<LogicType>(downstream.data.cloneTyped()),
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );
    final occupancyWidth = (depth + 1).log2Ceil;
    addOutput('occupancy', width: occupancyWidth);
    addOutput('empty');
    addOutput('full');
    addOutput('almostFull');
    addOutput('almostEmpty');

    final storageReset =
        (this.reset | this.flush).named('${name}_storage_reset');
    if (storage == ReadyValidQueueStorage.registers) {
      ReadyValidElasticPipeline<LogicType>(
          clk: this.clk,
          reset: storageReset,
          upstream: this.upstream,
          downstream: this.downstream,
          depth: depth,
          fallThrough: policy == ReadyValidQueuePolicy.fallThrough,
          name: '${name}_storage');
    } else {
      final fifo = Fifo<LogicType>(
        this.clk,
        storageReset,
        writeEnable: this.upstream.accepted,
        readEnable: this.downstream.accepted,
        writeData: this.upstream.data,
        depth: depth,
        generateBypass: policy == ReadyValidQueuePolicy.fallThrough,
        name: '${name}_storage',
      );
      this.downstream.valid <=
          ~fifo.empty |
              (policy == ReadyValidQueuePolicy.fallThrough
                  ? this.upstream.valid
                  : Const(0));
      this.downstream.data <= fifo.readData;
      this.upstream.ready <= ~full | this.downstream.accepted;
    }

    final inputAccepted = this.upstream.accepted;
    final outputAccepted = this.downstream.accepted;
    final inputOnlyAccepted =
        (inputAccepted & ~outputAccepted).named('${name}_input_only_accepted');
    final outputOnlyAccepted =
        (~inputAccepted & outputAccepted).named('${name}_output_only_accepted');
    empty <= occupancy.eq(0);
    full <= occupancy.eq(depth);
    almostFull <=
        ~occupancy.lt(Const(this.almostFullThreshold, width: occupancyWidth));
    almostEmpty <=
        occupancy.lte(Const(this.almostEmptyThreshold, width: occupancyWidth));
    Sequential(this.clk, reset: storageReset, resetValues: {
      occupancy: 0
    }, [
      If(inputOnlyAccepted, then: [
        occupancy < occupancy + Const(1, width: occupancyWidth),
      ]),
      If(outputOnlyAccepted, then: [
        occupancy < occupancy - Const(1, width: occupancyWidth),
      ]),
    ]);
  }
}
