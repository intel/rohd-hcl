// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// set_bits.dart
// Sets a count of bits at one end of a signal to a fill value.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Sets the `count` least significant bits (`lsbs` true) or most significant
/// bits (`lsbs` false) of `inp` to `fill`.
///
/// The count saturates at the width of `inp`, so a count at or above the width
/// sets every bit. Keeping the low `n` bits is `SetBits` on the most
/// significant end with a count of `width - n`.
/// {@category Bit Operations}
class SetBits extends Module {
  /// The modified signal.
  Logic get result => output('result');

  /// Creates set-to-fill hardware over [inp] and [count].
  SetBits(
    Logic inp,
    Logic count, {
    bool lsbs = true,
    bool fill = false,
    super.name = 'set_bits',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
            definitionName: definitionName ??
                'SetBits_${lsbs ? 'Lsbs' : 'Msbs'}_'
                    'F${fill ? 1 : 0}_W${inp.width}') {
    inp = addInput('inp', inp, width: inp.width);
    count = addInput('count', count, width: count.width);
    final result = addOutput('result', width: inp.width);

    // Bit `i` is selected when its distance from the chosen end is below
    // `count`. Comparing per bit, rather than shifting, saturates correctly
    // for counts at or above the width.
    final selectBits = [
      for (var i = inp.width - 1; i >= 0; i--)
        Const(lsbs ? i : inp.width - 1 - i, width: count.width).lt(count)
    ];
    final selected = selectBits.swizzle();
    result <= (fill ? inp | selected : inp & ~selected);
  }
}
