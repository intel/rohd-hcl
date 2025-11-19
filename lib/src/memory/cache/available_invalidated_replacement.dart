// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// available_invalidated_replacement.dart
// A replacement policy that returns an available invalidated way when asked
// via allocs, supports invalidates, and throws on access (hits).
//
// 2025 November 14
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A replacement policy that guarantees that if an invalid way is available,
/// it will be returned for use.
class AvailableInvalidatedReplacement extends ReplacementPolicy {
  /// Construct the policy.
  AvailableInvalidatedReplacement(
      super.clk, super.reset, super._hits, super._allocs, super._invalidates,
      {super.ways,
      super.name = 'available_invalidated',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'available_invalidated_H${_hits.length}_'
                    'A${_allocs.length}_WAYS=$ways') {
    _buildLogic();
  }

  void _buildLogic() {
    // This policy ignores hit/access inputs; callers should not drive them.

    // Per-way valid bit storage (one Logic per way) to simplify bit ops.
    final validBits = List<Logic>.generate(ways, (w) => Logic(name: 'vb_$w'));
    final validBitsNext =
        List<Logic>.generate(ways, (w) => Logic(name: 'vb_next_$w'));

    // Register the bits (reset initializes to 0 = invalid)
    for (var w = 0; w < ways; w++) {
      validBits[w] <= flop(clk, validBitsNext[w], reset: reset);
    }

    // (No debug outputs added here.)

    // Compute way address width.
    final wayWidth = log2Ceil(ways) == 0 ? 1 : log2Ceil(ways);

    // Compute the post-invalidate valid bit state combinationally.
    // Start with registered validBits, then apply all invalidates.
    // Use variable reassignment like PseudoLRU to chain updates.
    var updateValidBits = List<Logic>.generate(
        ways, (w) => validBits[w].named('updateValid_start_w$w'));

    for (var i = 0; i < intInvalidates.length; i++) {
      final inval = intInvalidates[i];
      final nextValidBits = List<Logic>.generate(ways, (w) {
        final match = inval.way.eq(Const(w, width: log2Ceil(ways)));
        return mux(inval.access & match, Const(0), updateValidBits[w])
            .named('validAfterInv${i}_w$w');
      });
      updateValidBits = nextValidBits;
    }

    // Chain allocs so each sees the effect of earlier allocs' claims.
    // This follows the PseudoLRU pattern of updating state between allocs.
    for (var i = 0; i < intAllocs.length; i++) {
      final a = intAllocs[i];

      // Build invalid bits from current valid bit state.
      final invalidBits = List<Logic>.generate(
          ways, (w) => (~updateValidBits[w]).named('invalidBit${i}_w$w'));

      // Pick the lowest-index invalid way.
      Logic pickWay;
      if (ways == 1) {
        pickWay = Const(0, width: wayWidth);
      } else {
        pickWay = RecursivePriorityEncoder(invalidBits.rswizzle())
            .out
            .slice(wayWidth - 1, 0)
            .named('pickWay$i');
      }

      // Drive the alloc interface with the picked way.
      a.way <= pickWay;

      // Update the valid bits to reflect this alloc's claim, so next alloc sees
      // it.
      final nextValidBits = List<Logic>.generate(ways, (w) {
        final isPickedWay = pickWay.eq(Const(w, width: wayWidth));
        final thisClaim = a.access & isPickedWay;
        return mux(thisClaim, Const(1), updateValidBits[w])
            .named('validAfterAlloc${i}_w$w');
      });
      updateValidBits = nextValidBits;
    }

    // Register the final valid bit state.
    for (var w = 0; w < ways; w++) {
      validBitsNext[w] <= updateValidBits[w];
    }
  }
}
