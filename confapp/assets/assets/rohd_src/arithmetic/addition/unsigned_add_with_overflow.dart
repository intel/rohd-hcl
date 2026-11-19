// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// unsigned_add_with_overflow.dart
// Unsigned addition that reports overflow out of a fixed-width sum.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';

/// Adds two unsigned values into a [sum] of [sumWidth] bits and reports
/// whether the true sum did not fit in [sumWidth] bits.
///
/// The [sumWidth] defaults to the wider of the two operands.
class UnsignedAddWithOverflow extends Module {
  /// The [sumWidth]-bit truncated sum.
  Logic get sum => output('sum');

  /// High when the true sum needs more than [sumWidth] bits.
  Logic get overflow => output('overflow');

  /// The width of [sum].
  final int sumWidth;

  /// Constructs an [UnsignedAddWithOverflow] of [a] and [b].
  UnsignedAddWithOverflow(Logic a, Logic b,
      {int? sumWidth,
      super.name = 'unsigned_add_with_overflow',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : sumWidth = sumWidth ?? max(a.width, b.width),
        super(
            definitionName: definitionName ??
                'UnsignedAddWithOverflow_A${a.width}_B${b.width}'
                    '_S${sumWidth ?? max(a.width, b.width)}') {
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    final sum = addOutput('sum', width: this.sumWidth);
    final overflow = addOutput('overflow');

    // One extra bit above the widest operand and sum keeps the true sum.
    final w = max(max(a.width, b.width), this.sumWidth) + 1;
    final full = a.zeroExtend(w) + b.zeroExtend(w);
    sum <= full.slice(this.sumWidth - 1, 0);
    overflow <= full.slice(w - 1, this.sumWidth).or();
  }
}
