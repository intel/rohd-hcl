// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// log2_ceil.dart
// Ceiling of the base-2 logarithm of an unsigned value.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/bit_operations/search/count_leading_trailing_zeros.dart';

/// Computes the ceiling of the base-2 logarithm of `inp`.
///
/// This is the hardware form of `log2Ceil`. The result is zero for an input of
/// zero or one. It is computed as the bit width minus the leading zero count of
/// `inp - 1`, which is valid because `ceil(log2(x))` equals the bit length of
/// `x - 1` for `x` of at least one.
class Log2Ceil extends Module {
  /// The ceiling of the base-2 logarithm of `inp`.
  Logic get log => output('log');

  /// Constructs a [Log2Ceil] of [inp].
  Log2Ceil(Logic inp,
      {super.name = 'log2Ceil',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(definitionName: definitionName ?? 'Log2Ceil_W${inp.width}') {
    inp = addInput('inp', inp, width: inp.width);
    final w = inp.width;
    final outWidth = w.bitLength;
    final log = addOutput('log', width: outWidth);

    final predecessor =
        mux(inp.eq(0), Const(0, width: w), inp - Const(1, width: w));
    final leadingZeros = CountLeadingZeros(predecessor).count;
    log <=
        (Const(w, width: outWidth) - leadingZeros.slice(outWidth - 1, 0))
            .slice(outWidth - 1, 0);
  }
}
