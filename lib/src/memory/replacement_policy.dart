// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// replacement_policy.dart
// Cache line replacement policies.
//
// 2025 September 12
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An interface to a replacement policy that tracks [way] accesses, either
/// responds with a hit on a [way] or responds to a miss by choosing the [way]
/// to evict to make room for the new data.
///
/// Can be used for signaling [way] access or miss providing a way to evict by
/// grouping signals using [DataPortGroup].
class AccessInterface extends Interface<DataPortGroup> {
  /// The number of ways in a cache line.
  final int numWays;

  /// The access signal indicating a way is being accessed.
  Logic get access => port('access');

  /// The way being accessed.
  Logic get way => port('way');

  /// Constructs a new interface of specified [numWays] for interacting with a
  /// way replacement policy.
  AccessInterface(this.numWays) {
    setPorts([
      Logic.port('access'),
    ], [
      DataPortGroup.control
    ]);

    setPorts([
      Logic.port('way', log2Ceil(numWays)),
    ], [
      DataPortGroup.data
    ]);
  }

  /// Makes a copy of this [Interface] with matching configuration.
  @override
  AccessInterface clone() => AccessInterface(numWays);
}

/// A module [ReplacementPolicy] for choosing which way to use for a
/// set-associative cache upon a store miss. It tracks accesses to ways to
/// implement policies like LRU for choosing the way to return on a miss.
abstract class ReplacementPolicy extends Module {
  /// Number of ways in the cache line.
  late final int ways;

  /// Access interfaces to communicate hits on ways.
  @protected
  final List<AccessInterface> hits = [];

  /// Miss interfaces to communicate misses and retrieve ways to evict.
  @protected
  final List<AccessInterface> allocs = [];

  /// Invalidate interfaces to communicate invalidates on ways.
  @protected
  final List<AccessInterface> invalidates = [];

  /// Clock.
  Logic get clk => input('clk');

  /// Reset.
  Logic get reset => input('reset');

  /// Constructs a [ReplacementPolicy] policy for a cache line.
  ///
  /// The [hits] interfaces are used to mark ways that are recently accessed.
  /// The [allocs] interfaces are used to signal a miss and retrieve a way to
  /// evict. The [ways] parameter indicates the number of ways in the cache
  /// line.
  ReplacementPolicy(Logic clk, Logic reset, List<AccessInterface> hits,
      List<AccessInterface> allocs, List<AccessInterface> invalidates,
      {this.ways = 2,
      super.name = 'replacement',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'replacement_H${hits.length}_M${allocs.length}_WAYS=$ways') {
    if (ways < 2 || (ways & (ways - 1)) != 0) {
      throw ArgumentError('ways must be a power of two and at least 2');
    }
    if (hits.isEmpty) {
      throw ArgumentError('at least one access interface is required');
    }
    if (allocs.isEmpty) {
      throw ArgumentError('at least one miss interface is required');
    }
    if (allocs.length > ways) {
      throw ArgumentError('number of miss interfaces (${allocs.length}) '
          'cannot exceed number of ways ($ways)');
    }
    addInput('clk', clk);
    addInput('reset', reset);

    for (var i = 0; i < hits.length; i++) {
      this.hits.add(hits[i].clone()
        ..connectIO(this, hits[i],
            inputTags: {DataPortGroup.control, DataPortGroup.data},
            uniquify: (original) => 'hit_${original}_$i'));
    }
    for (var i = 0; i < allocs.length; i++) {
      this.allocs.add(allocs[i].clone()
        ..connectIO(this, allocs[i],
            inputTags: {DataPortGroup.control},
            outputTags: {DataPortGroup.data},
            uniquify: (original) => 'miss_${original}_$i'));
    }
    for (var i = 0; i < invalidates.length; i++) {
      this.invalidates.add(invalidates[i].clone()
        ..connectIO(this, invalidates[i],
            inputTags: {DataPortGroup.control, DataPortGroup.data},
            uniquify: (original) => 'invalidate_${original}_$i'));
    }
  }
}

// Other policies to implement Full LRU, LFU, Random, FIFO, MRU, Adaptive
// - LRU:
//   - Full some say prohibively expensive but I have an interesting approach.
//      - Full  n!  (log): exact order
//   - Tree-based LRU:  leaves are ways:  1 marking is more recent DONE
//   - NRU:  Not recently used. single bit marked to 0.  find the '1', flip all
//       to 1 when all 0
// - Quad-Age LRU
//   - 2 bits per way, on access set to 0, all < incremented by 1
//   - on replacement, choose a '3', if none, choose a '2', etc
//   - on write, set to 0, all < incremented by 1
//   - on read, set to 0, all < incremented by 1
//   - on reset, set all to 3
//   - on hit, set to 0, all < incremented by 1
//   - on miss, replace a 3, if none, replace a 2, etc
//   - on miss, set to 0, all < incremented by 1
//   - on miss, if no 3,2,1, replace a 0
