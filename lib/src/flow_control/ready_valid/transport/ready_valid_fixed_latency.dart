// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_fixed_latency.dart
// Ready/valid wrapper for fixed-latency compute cores.
//
// 2026 November 15
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/flow_control/control/fixed_latency_tracker.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/queues/ready_valid_queue.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/src/pipeline_timing_contract.dart';

/// Builds an in-order fixed-latency core from wrapper-owned signals.
///
/// The returned payload must be produced exactly `latency` cycles after a
/// `start` edge. The core must continue advancing through bubbles and must
/// accept requests at the wrapper's configured initiation interval.
typedef FixedLatencyCoreGenerator<Input extends Logic, Output extends Logic>
    = Output Function({
  required Logic clk,
  required Logic reset,
  required Logic start,
  required Input data,
});

class _FixedLatencyResult<T extends Logic, Id extends Logic>
    extends LogicStructure {
  T get payload => elements[0] as T;
  Id? get id => elements.length == 1 ? null : elements[1] as Id;

  _FixedLatencyResult(T schema, Id? idSchema, {String? name})
      : super([
          schema.cloneTyped(name: 'payload'),
          if (idSchema != null) idSchema.cloneTyped(name: 'id'),
        ], name: name ?? 'result');

  @override
  _FixedLatencyResult<T, Id> clone({String? name}) =>
      _FixedLatencyResult(payload, id, name: name ?? this.name);
}

/// Ready/valid admission and result retention around a fixed-latency core.
///
/// The compute core is never stalled. Result capacity is reserved when a
/// request is accepted, so backpressure cannot overflow the result queue.
/// Optional IDs are captured with accepted inputs and returned with outputs.
/// Results remain ordered and valid until accepted.
/// {@category Flow Control}
class ReadyValidFixedLatency<Input extends Logic, Output extends Logic,
    Id extends Logic> extends Module {
  /// Configured number of core cycles from acceptance to completion.
  final int latency;

  /// Minimum number of cycles between accepted requests.
  final int initiationInterval;

  /// Number of reserved result slots, including in-flight operations.
  final int capacity;

  /// Timing contract of the continuously advancing compute core.
  late final PipelineTimingContract timing;

  final bool _hasId;

  /// ID associated with the offered output, or null when IDs are disabled.
  Id? get resultId => _hasId ? output('result_id') as Id : null;

  /// High on a scheduling or result-buffer overflow error.
  Logic get error => output('error');

  /// Wraps a core constructed by [coreGenerator].
  ///
  /// [coreIdentity] must uniquely identify the generated core configuration
  /// and be a valid SystemVerilog identifier fragment. [requestId], when
  /// supplied, retains its declared schema even when [Id] is [Logic] and
  /// must remain stable alongside a stalled input payload. Use [Logic] as
  /// [Id] when IDs are omitted.
  /// [capacity] defaults to `latency + 1` and may be reduced at the cost of
  /// throughput. Reset discards all outstanding requests and results.
  ReadyValidFixedLatency({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<Input> upstream,
    required ReadyValidInterface<Output> downstream,
    required FixedLatencyCoreGenerator<Input, Output> coreGenerator,
    required String coreIdentity,
    required this.latency,
    this.initiationInterval = 1,
    int? capacity,
    Id? requestId,
    String name = 'ready_valid_fixed_latency',
  })  : capacity = capacity ?? latency + 1,
        _hasId = requestId != null,
        super(
          name: name,
          definitionName: 'ReadyValidFixedLatency_${coreIdentity}_'
              'L${latency}_I${initiationInterval}_C${capacity ?? latency + 1}_'
              'Id${requestId?.width ?? 0}_'
              '${requestId == null ? 'none' : payloadShapeIdentity(requestId)}_'
              '${payloadShapeIdentity(upstream.data)}_'
              '${payloadShapeIdentity(downstream.data)}',
        ) {
    if (latency < 0 || initiationInterval < 1 || this.capacity < 1) {
      throw ArgumentError(
          'Latency must be nonnegative; initiation interval and capacity '
          'must be positive.');
    }
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(coreIdentity)) {
      throw ArgumentError.value(coreIdentity, 'coreIdentity',
          'Must be a valid SystemVerilog identifier fragment.');
    }
    final minimumInFlight =
        (latency + initiationInterval - 1) ~/ initiationInterval;
    timing = PipelineTimingContract(
      latency: latency,
      initiationInterval: initiationInterval,
      stallability: PipelineStallability.none,
      acceptsBubbles: true,
      supportsFlush: false,
      maximumInFlight: minimumInFlight < 1 ? 1 : minimumInFlight,
    );
    upstream.requireProviderComposableWith(ReadyValidContract.readyAndValid,
        consumerName: name);
    downstream.requireConsumerComposableWith(ReadyValidContract.irrevocable,
        providerName: name);

    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    final input = addPairInterfacePorts(upstream, PairRole.consumer,
        uniquify: (original) => 'upstream_$original');
    final output = addPairInterfaceFrom(
      IrrevocableReadyValidInterface<Output>(downstream.data.cloneTyped()),
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );
    final localId =
        requestId == null ? null : addTypedInput<Id>('request_id', requestId);
    if (localId != null) {
      addTypedPayloadOutput<Id>(this, 'result_id', localId);
    }

    final retire = Logic(name: 'retire');
    final tracker = FixedLatencyTracker(
      clk: clk,
      reset: reset,
      request: input.valid,
      retire: retire,
      latency: latency,
      initiationInterval: initiationInterval,
      capacity: this.capacity,
      name: '${name}_tracker',
    );
    input.ready <= tracker.canAccept;
    final result = coreGenerator(
      clk: clk,
      reset: reset,
      start: tracker.accepted,
      data: input.data,
    );
    if (!sameDeclaredPayloadShape(downstream.data, result,
        ignoreConstantNames: true)) {
      throw ArgumentError(
          'Core result must match the downstream payload shape.');
    }

    Id? delayedId;
    if (localId != null) {
      var id = localId;
      for (var stage = 0; stage < latency; stage++) {
        id = flop<Id>(clk, id,
            outputGenerator:
                hasDeclaredPayloadShape(id) ? id.cloneTyped : null);
      }
      delayedId = id;
    }
    final queueInput = ReadyValidInterface(
        _FixedLatencyResult<Output, Id>(output.data, delayedId));
    final queueOutput = ReadyValidInterface(
        _FixedLatencyResult<Output, Id>(output.data, delayedId));
    queueInput.data.payload <= result;
    if (delayedId != null) {
      queueInput.data.id! <= delayedId;
    }
    queueInput.valid <= tracker.completed;
    ReadyValidQueue<_FixedLatencyResult<Output, Id>>(
      clk: clk,
      reset: reset,
      upstream: queueInput,
      downstream: queueOutput,
      depth: this.capacity,
      storage: ReadyValidQueueStorage.ring,
      name: '${name}_results',
    );
    queueOutput.ready <= output.ready & ~reset;
    output.valid <= queueOutput.valid & ~reset;
    output.data <= queueOutput.data.payload;
    if (delayedId != null) {
      resultId! <= queueOutput.data.id!;
    }
    retire <= queueOutput.accepted;
    addOutput('error') <=
        tracker.error | (queueInput.valid & ~queueInput.ready);
  }
}
