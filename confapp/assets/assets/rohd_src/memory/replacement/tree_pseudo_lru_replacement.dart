// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tree_pseudo_lru_replacement.dart
// Tree-based pseudo-LRU replacement policy.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/replacement/replacement_policy.dart';

/// A binary-tree pseudo-LRU policy for a power-of-two number of entries.
///
/// A single entry is supported without tree state. Pseudo-LRU approximates
/// recency; it does not necessarily choose the exact least-recently-used entry.
class TreePseudoLruReplacement extends ReplacementPolicy {
  /// Creates a tree pseudo-LRU policy.
  TreePseudoLruReplacement({
    required super.clk,
    required super.reset,
    required super.validMask,
    required super.eligibleMask,
    required super.accesses,
    required super.allocations,
    required super.entryCount,
    super.commits,
    super.name = 'tree_pseudo_lru_replacement',
  }) : super(
            definitionName: 'TreePseudoLruReplacement_E${entryCount}_'
                'H${accesses.length}_A${allocations.length}'
                '${commits.isEmpty ? '' : '_C${commits.length}'}') {
    if ((entryCount & (entryCount - 1)) != 0) {
      throw ArgumentError.value(
          entryCount, 'entryCount', 'Must be a power of two.');
    }

    Logic update(Logic state, Logic index) {
      if (entryCount == 1) {
        return state;
      }
      final nodes = List<({int start, int end})?>.filled(entryCount - 1, null);
      void visit(int node, int start, int end) {
        if (end - start == 1) {
          return;
        }
        nodes[node] = (start: start, end: end);
        final middle = (start + end) ~/ 2;
        visit(node * 2 + 1, start, middle);
        visit(node * 2 + 2, middle, end);
      }

      visit(0, 0, entryCount);
      final extended = index.zeroExtend(indexWidth + 1);
      return [
        for (var node = 0; node < nodes.length; node++)
          mux<Logic>(
            extended.gte(Const(nodes[node]!.start, width: indexWidth + 1)) &
                extended.lt(Const(nodes[node]!.end, width: indexWidth + 1)),
            mux(
                extended.lt(Const((nodes[node]!.start + nodes[node]!.end) ~/ 2,
                    width: indexWidth + 1)),
                Const(1),
                Const(0)),
            state[node],
          )
      ].rconcat();
    }

    ReplacementSelection select(Logic state, Logic candidates) {
      ReplacementSelection visit(int node, int start, int end) {
        if (end - start == 1) {
          return (
            valid: candidates[start],
            index: Const(start, width: indexWidth)
          );
        }
        final middle = (start + end) ~/ 2;
        final left = visit(node * 2 + 1, start, middle);
        final right = visit(node * 2 + 2, middle, end);
        final chooseRight =
            mux(state[node], right.valid, ~left.valid & right.valid);
        return (
          valid: left.valid | right.valid,
          index: mux(chooseRight, right.index, left.index)
        );
      }

      return visit(0, 0, entryCount);
    }

    buildPolicy(
      stateWidth: entryCount == 1 ? 1 : entryCount - 1,
      onAccess: update,
      select: select,
      onAllocation: update,
    );
  }
}
