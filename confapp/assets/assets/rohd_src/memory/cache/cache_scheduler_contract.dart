// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cache_scheduler_contract.dart
// Resource scheduling boundary for cache controllers.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';

/// One candidate for an atomic grant from a cache scheduler.
@experimental
class CacheScheduleRequest extends PairInterface {
  final List<int> _capacities;

  /// Whether this candidate may be granted.
  Logic get valid => port('valid');

  /// Resource units needed this cycle, in the scheduler's resource order.
  List<Logic> get demand => List.unmodifiable(
      [for (var i = 0; i < _capacities.length; i++) port('demand_$i')]);

  /// Whether this candidate is granted on the sampling edge.
  Logic get grant => port('grant');

  CacheScheduleRequest._(this._capacities)
      : super(
          portsFromProvider: [
            Logic.port('valid'),
            for (final (i, capacity) in _capacities.indexed)
              Logic.port('demand_$i', capacity.bitLength),
          ],
          portsFromConsumer: [Logic.port('grant')],
        );

  @override
  CacheScheduleRequest clone() => CacheScheduleRequest._(_capacities);
}

/// Resource and conflict signals shared by one scheduling decision.
///
/// Every granted request consumes its complete demand vector in that cycle.
/// A pair conflicts if either corresponding bit in [conflicts] is asserted.
/// The controller owns requests, availability, conflicts, and all resources;
/// the scheduler drives only grants. Reservations spanning cycles are separate.
@experimental
class CacheSchedulerPorts extends PairInterface {
  /// Maximum units of each resource; order defines demand-vector indices.
  final List<int> capacities;

  /// Candidates in arbitration order.
  final List<CacheScheduleRequest> requests;

  /// Available units this cycle, one signal per resource.
  List<Logic> get available => List.unmodifiable(
      [for (var i = 0; i < capacities.length; i++) port('available_$i')]);

  /// Per-candidate conflict bit vectors, indexed by candidate.
  List<Logic> get conflicts => List.unmodifiable(
      [for (var i = 0; i < requests.length; i++) port('conflicts_$i')]);

  /// Invalid resource availability or enabled demand exceeds its capacity.
  Logic get invalidInputs => port('invalidInputs');

  /// Creates the signals for [requestCount] candidates and [capacities].
  factory CacheSchedulerPorts({
    required int requestCount,
    required List<int> capacities,
  }) {
    if (requestCount < 1 ||
        capacities.isEmpty ||
        capacities.any((capacity) => capacity < 1)) {
      throw ArgumentError('Scheduling needs requests and positive resources.');
    }
    return CacheSchedulerPorts._(requestCount, List.unmodifiable(capacities));
  }

  CacheSchedulerPorts._(int count, this.capacities)
      : requests = List.unmodifiable([
          for (var i = 0; i < count; i++) CacheScheduleRequest._(capacities)
        ]),
        super(
          portsFromProvider: [
            for (final (i, capacity) in capacities.indexed)
              Logic.port('available_$i', capacity.bitLength),
            for (var i = 0; i < count; i++) Logic.port('conflicts_$i', count),
          ],
          portsFromConsumer: [Logic.port('invalidInputs')],
        ) {
    for (final (i, request) in requests.indexed) {
      addSubInterface('request_$i', request,
          uniquify: (signal) => 'request_${i}_$signal');
    }
  }

  @override
  CacheSchedulerPorts clone() => CacheSchedulerPorts(
      requestCount: requests.length, capacities: capacities);
}

/// Builds a scheduler which drives grants on caller-owned [ports].
///
/// Each grant must imply a valid request; granted demands must fit [ports]'
/// availability and no granted pair may conflict. A grant and valid together
/// transfer the complete decision on a rising edge. No fairness, ordering,
/// state, or maximality is implied by this signature.
/// The scheduler drives [CacheSchedulerPorts.invalidInputs] and suppresses all
/// grants when a definitely invalid input is present or reset is asserted.
@experimental
typedef CacheSchedulerBuilder = Module Function({
  required Logic clk,
  required Logic reset,
  required CacheSchedulerPorts ports,
  required String name,
});
