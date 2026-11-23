// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_priority_cache_scheduler.dart
// Atomic fixed-priority resource arbitration for cache controllers.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/cache/cache_scheduler_contract.dart';

/// Greedily grants feasible requests in ascending port order.
///
/// Every selected request consumes its complete demand vector. Conflicts are
/// symmetric even if only one of the corresponding input bits is set.
/// Lower-priority requests can starve; no cross-cycle fairness is provided.
/// {@category Memory}
@experimental
class FixedPriorityCacheScheduler extends Module {
  /// Creates a stateless scheduler on caller-owned [ports].
  FixedPriorityCacheScheduler({
    required Logic clk,
    required Logic reset,
    required CacheSchedulerPorts ports,
    super.name = 'fixed_priority_cache_scheduler',
  }) : super(
          definitionName:
              'FixedPriorityCacheScheduler_N${ports.requests.length}'
              '_C${ports.capacities.join('_')}',
        ) {
    if (clk.width != 1 || reset.width != 1) {
      throw ArgumentError('Scheduler clock and reset must be one bit.');
    }
    addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localPorts = addInterfacePorts(ports,
        inputTags: [PairDirection.fromProvider],
        outputTags: [PairDirection.fromConsumer],
        uniquify: (signal) => signal.startsWith('conflicts_')
            ? 'request_${signal.substring('conflicts_'.length)}_conflicts'
            : signal);
    final available = localPorts.available;
    final valid = [for (final request in localPorts.requests) request.valid];
    final demand = [for (final request in localPorts.requests) request.demand];
    final conflicts = localPorts.conflicts;
    Logic invalid = Const(0);
    for (final (resource, capacity) in ports.capacities.indexed) {
      final limit = Const(capacity, width: capacity.bitLength);
      invalid = invalid | available[resource].gt(limit);
      for (var index = 0; index < valid.length; index++) {
        invalid = invalid | (valid[index] & demand[index][resource].gt(limit));
      }
    }
    localPorts.invalidInputs <= invalid;

    var remaining = available;
    final granted = <Logic>[];
    for (var index = 0; index < valid.length; index++) {
      var feasible = ~localReset & ~invalid & valid[index];
      for (var resource = 0; resource < available.length; resource++) {
        feasible = feasible & demand[index][resource].lte(remaining[resource]);
      }
      for (var earlier = 0; earlier < index; earlier++) {
        feasible = feasible &
            ~(granted[earlier] &
                (conflicts[earlier][index] | conflicts[index][earlier]));
      }
      granted.add(feasible);
      localPorts.requests[index].grant <= feasible;
      remaining = [
        for (var resource = 0; resource < available.length; resource++)
          remaining[resource] -
              mux(feasible, demand[index][resource],
                  Const(0, width: ports.capacities[resource].bitLength))
      ];
    }
  }
}
