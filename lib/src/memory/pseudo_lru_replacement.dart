// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// pseudo_lru_replacement.dart
// An implementation of a Pseudo LRU replacement policy algorithm.
//
// 2025 September 12
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A tree-based pseudo-LRU replacement policy.
class PseudoLRUReplacement extends ReplacementPolicy {
  /// Constructs a pseudo Least-Recently-Used policy for a cache line.
  PseudoLRUReplacement(
      super.clk, super.reset, super.hits, super.allocs, super.invalidates,
      {super.ways,
      super.name = 'plru',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'psuedo_lru_replacement_'
                    'H${hits.length}_A${allocs.length}_WAYS=$ways') {
    _buildLogic();
  }

  /// Declare a miss and ask for the least-recently-used way.
  @visibleForTesting
  @protected
  Logic allocPLRU(Logic v, {int base = 0, int sz = 0}) {
    final lsz = sz == 0 ? max(log2Ceil(v.width), 1) : sz;
    Logic convertInt(int i) => Const(i, width: lsz);

    final mid = v.width ~/ 2;
    return v.width == 1
        ? mux(v[0], convertInt(base), convertInt(base + 1))
        : mux(
            v[mid],
            allocPLRU(
                v.slice(mid - 1, 0).named(
                    'miss_${v.name}_${mid + base - 1}_$base',
                    naming: Naming.mergeable),
                base: base,
                sz: lsz),
            allocPLRU(
                v.getRange(mid + 1).named(
                    'miss_${v.name}_${v.width - 1}_${mid + 1}',
                    naming: Naming.mergeable),
                base: mid + 1 + base,
                sz: lsz));
  }

  /// Access a given way and mark the LRU path in the tree with 0s.
  ///
  /// At a node, 0 means LRU is right.
  /// - If we hit left, we set to 0 to indicate LRU is right.
  /// - If we hit right, we set to 1, indicating LRU is left.
  /// - Invalidate reverses these meanings as we are marking the way
  /// as an invalid and therefore LRU.
  ///   @visibleForTesting
  @visibleForTesting
  @protected
  Logic hitPLRU(Logic v, Logic way, {int base = 0, Logic? invalidate}) {
    Logic convertInt(int i) => Const(i, width: way.width);
    invalidate ??= Const(0);

    if (v.width == 1) {
      return mux(way.eq(convertInt(base)), invalidate,
          mux(way.eq(convertInt(base + 1)), ~invalidate, v[0]));
    } else {
      final mid = v.width ~/ 2;
      final lower = hitPLRU(
          v.slice(mid - 1, 0).named('${v.name}_${mid + base - 1}_$base',
              naming: Naming.mergeable),
          way,
          base: base,
          invalidate: invalidate);
      final upper = hitPLRU(
          v.getRange(mid + 1).named(
              '${v.name}_${v.width - 1}_${mid + 1 + base}',
              naming: Naming.mergeable),
          way,
          base: mid + base + 1,
          invalidate: invalidate);
      final midVal = mux(
          way.lt(convertInt(base)) | way.gt(convertInt(base + v.width)),
          v[mid],
          mux(way.lte(convertInt(mid + base)), invalidate, ~invalidate));
      return [lower, midVal, upper].rswizzle();
    }
  }

  void _buildLogic() {
    // Storage for pseudo-LRU bits that represent the tree.
    final treePLRUIn =
        Logic(name: 'plru_in', naming: Naming.mergeable, width: ways - 1);
    final treePLRU =
        Logic(name: 'plru', naming: Naming.mergeable, width: ways - 1);

    treePLRU <= flop(clk, reset: reset, treePLRUIn);

    // Process access invalidates, then hits, then allocs.
    var updateTreePLRU = treePLRU;
    for (var i = 0; i < invalidates.length; i++) {
      final invalidate = invalidates[i];
      updateTreePLRU = mux(
              invalidate.access,
              hitPLRU(updateTreePLRU, invalidate.way,
                  invalidate: invalidate.access),
              updateTreePLRU)
          .named('update_invalidate$i', naming: Naming.mergeable);
    }
    for (var i = 0; i < hits.length; i++) {
      final hit = hits[i];
      updateTreePLRU =
          mux(hit.access, hitPLRU(updateTreePLRU, hit.way), updateTreePLRU)
              .named('update_hit$i', naming: Naming.mergeable);
    }
    for (var i = 0; i < allocs.length; i++) {
      final alloc = allocs[i];
      alloc.way <= allocPLRU(updateTreePLRU);
      updateTreePLRU =
          mux(alloc.access, hitPLRU(updateTreePLRU, alloc.way), updateTreePLRU)
              .named('update_alloc$i', naming: Naming.renameable);
    }
    treePLRUIn <= updateTreePLRU;
  }
}
