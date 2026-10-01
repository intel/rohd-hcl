// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_rounding.dart
// Floating-point rounding support.
//
// 2025 January 28 2025
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

// TODO(desmonddak): https://github.com/intel/rohd-hcl/issues/191 This can be
// made a module with other rounding algorithms.

// TODO(desmonddak): https://github.com/intel/rohd-hcl/issues/190 This does not
// check for evenness of the input which requires an API change to provide the
// final mantissa length as the entire mantissa may not be provided.

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
// TODO(desmondak): https://github.com/intel/rohd-hcl/issues/173 investigate how
// to implement other forms of rounding. Unify rounding modes. Here is what
// CoPilot says: We can have a full Rounding class that takes
// FloatingPointRoundingMode and does the appropriate rounding based on the
// mode.
