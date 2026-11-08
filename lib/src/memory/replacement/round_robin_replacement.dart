// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// round_robin_replacement.dart
// Round-robin replacement policy.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/associative/associative_match_selector.dart';
import 'package:rohd_hcl/src/memory/replacement/replacement_policy.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';

/// Chooses eligible entries cyclically, advancing after each allocation.
///
/// Hits do not affect round-robin ordering. Any positive entry count is valid.
class RoundRobinReplacement extends ReplacementPolicy {
  /// Creates a round-robin policy.
  RoundRobinReplacement({
    required super.clk,
    required super.reset,
    required super.validMask,
    required super.eligibleMask,
    required super.accesses,
    required super.allocations,
    required super.entryCount,
    super.commits,
    super.name = 'round_robin_replacement',
  }) : super(
            definitionName: 'RoundRobinReplacement_E${entryCount}_'
                'H${accesses.length}_A${allocations.length}'
                '${commits.isEmpty ? '' : '_C${commits.length}'}') {
    buildPolicy(
      stateWidth: indexWidth,
      onAccess: (state, index) => state,
      select: (state, candidates) {
        final width = entryCount.bitLength;
        final pointer = state.zeroExtend(width);
        final selector = AssociativeMatchSelector(
          matchVector: candidates,
          selectionValues: [
            for (var index = 0; index < entryCount; index++)
              mux(
                Const(index, width: width).gte(pointer),
                Const(index, width: width) - pointer,
                Const(entryCount, width: width) -
                    pointer +
                    Const(index, width: width),
              )
          ],
          selectionName: 'roundRobin',
        );
        return (valid: selector.valid, index: selector.selectedIndex);
      },
      onAllocation: (state, index) => mux(
          storedIndexMatches(index, entryCount - 1),
          Const(0, width: indexWidth),
          index + Const(1, width: indexWidth)),
    );
  }
}
