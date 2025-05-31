// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_rounding.dart
// Floating-point rounding support.
//
// 2025 January 28 2025
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

// TODO(desmonddak): this can be made a module with other rounding
// algorithms.

/// A rounding class that performs rounding-nearest-even
class RoundRNE {
  /// Return whether to round the input or not.
  Logic get doRound => _doRound;

  late final Logic _doRound;

  /// Determine whether the input should be rounded up given
  /// - [inp] the input bitvector to consider rounding
  /// - [lsb] the bit position at which to consider rounding
  RoundRNE(Logic inp, int lsb) {
    final last = inp[lsb];
    final guard = (lsb > 0) ? inp[lsb - 1] : Const(0);
    final round = (lsb > 1) ? inp[lsb - 2] : Const(0);
    final sticky = (lsb > 2) ? inp.getRange(0, lsb - 2).or() : Const(0);

    _doRound = guard & (last | round | sticky);
  }
}
// TODO(desmondak): investigate how to implement other forms of rounding.
