// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// replacement.dart
// Cache line replacement policies.
//
// 2025 September 12
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An interface to a replacement policy that tracks a hit on a [way] or
/// responds to a miss by choosing the [way] to evict to make room for the new
/// data.
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

/// A module [Replacement] for choosing which way to use for a set-associative
/// cache upon a store miss. It tracks accesses to ways to implement policies
/// like LRU for choosing the way to return on a miss.
abstract class Replacement extends Module {
  /// Number of ways in the cache line.
  late final int ways;

  /// Access interfaces to communicate hits on ways.
  @protected
  final List<AccessInterface> hits = [];

  /// Miss interfaces to communicate misses and retrieve ways to evict.
  @protected
  final List<AccessInterface> misses = [];

  /// Clock.
  Logic get clk => input('clk');

  /// Reset.
  Logic get reset => input('reset');

  /// Constructs a [Replacement] policy for a cache line.
  ///
  /// The [hits] interfaces are used to mark ways that are recently accessed.
  /// The [misses] interfaces are used to signal a miss and retrieve a way to
  /// evict. The [ways] parameter indicates the number of ways in the cache
  /// line.
  Replacement(Logic clk, Logic reset, List<AccessInterface> hits,
      List<AccessInterface> misses,
      {this.ways = 2,
      super.name = 'replacement',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'replacement_H${hits.length}_M${misses.length}_WAYS=$ways') {
    if (hits.isEmpty) {
      throw ArgumentError('at least one access interface is required');
    }
    if (misses.isEmpty) {
      throw ArgumentError('at least one miss interface is required');
    }
    if (misses.length > ways) {
      throw ArgumentError('number of miss interfaces (${misses.length}) '
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
    for (var i = 0; i < misses.length; i++) {
      this.misses.add(misses[i].clone()
        ..connectIO(this, misses[i],
            inputTags: {DataPortGroup.control},
            outputTags: {DataPortGroup.data},
            uniquify: (original) => 'miss_${original}_$i'));
    }

    _buildLogic();
  }
  @mustBeOverridden
  void _buildLogic();
}

/// A tree-based pseudo-LRU replacement policy.
class PseudoLRUReplacement extends Replacement {
  /// Constructs a pseudo Least-Recently-Used policy for a cache line.
  PseudoLRUReplacement(super.clk, super.reset, super.hits, super.misses,
      {super.ways,
      super.name = 'plru',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'psuedo_lru_replacement_'
                    '${hits.length}_M${misses.length}_WAYS=$ways') {
    if (ways < 2 || (ways & (ways - 1)) != 0) {
      throw ArgumentError('ways must be a power of two and at least 2');
    }
  }

  /// Declare a miss and ask for the least-recently-used way.
  Logic missPLRU(Logic v, {int base = 0, int sz = 0}) {
    final lsz = sz == 0 ? max(log2Ceil(v.width), 1) : sz;
    final mid = v.width ~/ 2;
    return v.width == 1
        ? mux(v[0], Const(base, width: lsz), Const(base + 1, width: lsz))
        : mux(
            v[mid],
            missPLRU(
                v.slice(mid - 1, 0).named(
                    'miss_${v.name}_${mid + base - 1}_$base',
                    naming: Naming.mergeable),
                base: base,
                sz: lsz),
            missPLRU(
                v.getRange(mid + 1).named(
                    'miss_${v.name}_${v.width - 1}_${mid + 1}',
                    naming: Naming.mergeable),
                base: mid + 1 + base,
                sz: lsz));
  }

  /// Access a given way and mark the LRU path in the tree with 0s.
  Logic hitPLRU(Logic v, Logic way, {int base = 0}) {
    if (v.width == 1) {
      return mux(way.eq(Const(base, width: way.width)), Const(0),
          mux(way.eq(Const(base + 1, width: way.width)), Const(1), v[0]));
    } else {
      final mid = v.width ~/ 2;
      final lowSlice = v
          .slice(mid - 1, 0)
          .named('${v.name}_${mid + base - 1}_$base', naming: Naming.mergeable);
      final hiSlice = v.getRange(mid + 1).named(
          '${v.name}_${v.width - 1}_${mid + 1 + base}',
          naming: Naming.mergeable);
      final lower = hitPLRU(lowSlice, way, base: base);
      final upper = hitPLRU(hiSlice, way, base: mid + base + 1);
      final midVal = mux(
          way.lt(Const(base, width: way.width)) |
              way.gt(Const(base + v.width, width: way.width)),
          v[mid],
          // 0 means LRU is right. So if we hit left, we set to 0,
          // if we hit right, we set to 1, indicating LRU is left.
          mux(way.lte(Const(mid + base, width: way.width)), Const(0),
              Const(1)));
      return [lower, midVal, upper].rswizzle();
    }
  }

  @override
  void _buildLogic() {
    // Storage for pseudo-LRU bits that represent the tree.
    final treePLRUIn =
        Logic(name: 'plru_in', naming: Naming.mergeable, width: ways - 1);
    final treePLRU =
        Logic(name: 'plru', naming: Naming.mergeable, width: ways - 1);
    Sequential(clk, [
      If(reset,
          then: [treePLRU < Const(0, width: ways - 1)],
          orElse: [treePLRU < treePLRUIn])
    ]);

    // Process access hits first.
    var updateTreePLRU = treePLRU;
    for (var i = 0; i < hits.length; i++) {
      final hit = hits[i];
      updateTreePLRU =
          mux(hit.access, hitPLRU(updateTreePLRU, hit.way), updateTreePLRU)
              .named('update_hit$i', naming: Naming.mergeable);
    }

    // Then process misses.
    for (var i = 0; i < misses.length; i++) {
      final miss = misses[i];
      miss.way <= missPLRU(updateTreePLRU);
      updateTreePLRU =
          mux(miss.access, hitPLRU(updateTreePLRU, miss.way), updateTreePLRU)
              .named('update_miss$i', naming: Naming.renameable);
    }
    treePLRUIn <= updateTreePLRU;
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
