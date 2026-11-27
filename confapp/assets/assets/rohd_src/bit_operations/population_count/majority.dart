// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// majority.dart
// Strict majority of a vector of bits.
//
// 2026 November 15
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Hardware operations for a strict majority of bits.
extension LogicMajority on Logic {
  /// Returns one if more than half of the bits are one.
  ///
  /// An even-width tie returns zero. X and Z bits are unknown: the result
  /// is known only when every possible assignment of those bits agrees.
  Logic majority() {
    if (width == 1) {
      return this[0] & Const(1);
    }
    if (width == 2) {
      return and();
    }
    if (width == 3) {
      return mux(this[0], slice(2, 1).or(), slice(2, 1).and());
    }

    var networkWidth = 1;
    while (networkWidth < width) {
      networkWidth *= 2;
    }
    final sorted = [
      for (var index = 0; index < networkWidth; index++)
        if (index < width) this[index] else Const(0)
    ];
    // AND/OR comparators sort known zeros, unknowns, and known ones.
    for (var block = 2; block <= networkWidth; block *= 2) {
      for (var stride = block ~/ 2; stride > 0; stride ~/= 2) {
        for (var index = 0; index < networkWidth; index++) {
          final peer = index ^ stride;
          if (peer > index) {
            final left = sorted[index];
            final right = sorted[peer];
            // Preserve shared nodes to prevent exponential RTL expansion.
            final high = (left | right).named(
                'majority_${block}_${stride}_${index}_high',
                naming: Naming.renameable);
            final low = (left & right).named(
                'majority_${block}_${stride}_${index}_low',
                naming: Naming.renameable);
            if (index & block == 0) {
              sorted[index] = high;
              sorted[peer] = low;
            } else {
              sorted[index] = low;
              sorted[peer] = high;
            }
          }
        }
      }
    }
    return sorted[width ~/ 2];
  }
}

/// A combinational strict-majority function on an input vector.
/// {@category Bit Operations}
class Majority extends Module {
  /// One when strictly more than half of the input bits are one.
  Logic get majority => output('majority');

  /// Creates a majority component for [bits].
  Majority(
    Logic bits, {
    super.name = 'majority',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(definitionName: definitionName ?? 'Majority_W${bits.width}') {
    bits = addInput('bits', bits, width: bits.width);
    addOutput('majority') <= bits.majority();
  }
}
