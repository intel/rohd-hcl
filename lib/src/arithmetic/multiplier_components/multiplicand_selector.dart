// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// multiplicand_selector.dart
// Selection of muliples of the multiplicand for booth recoding
//
// 2024 May 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A class accessing the multiples of the multiplicand at a position.
class MultiplicandSelector {
  /// The radix of the selector.
  int radix;

  /// The bit shift of the selector (typically overlaps 1).
  int shift;

  /// New width of partial products generated from the [multiplicand].
  int get width => multiplicand.width + shift - 1;

  /// The base [multiplicand] from which to generate multiples to select.
  Logic multiplicand = Logic();

  /// Place to store [multiples] of the [multiplicand] (e.g. *1, *2, *-1,
  /// *-2..).
  late LogicArray multiples;

  /// Multiples sliced into columns for select to access.
  late final multiplesSlice = <Logic>[];

  /// Build a [MultiplicandSelector] generating required [multiples] of
  /// [multiplicand] to [select] using a [RadixEncoder] output.
  ///
  /// The optional [signedMultiplicand] parameter configures the [multiplicand]
  /// statically using a bool to indicate a signed multiplicand (default is
  /// false, or unsigned) or dynamically with a 1-bit [Logic] input. Passing
  /// something other null, bool, or [Logic] will result in a throw.
  MultiplicandSelector(
    this.radix,
    this.multiplicand, {
    dynamic signedMultiplicand,
  }) : shift = log2Ceil(radix) {
    final signedMultiplicandParameter =
        StaticOrDynamicParameter.ofDynamic(signedMultiplicand);
    if (radix > 16) {
      throw RohdHclException('Radices beyond 16 are not yet supported');
    }
    final width = multiplicand.width + shift;
    final numMultiples = radix ~/ 2;
    multiples = LogicArray([numMultiples], width, name: 'multiples');

    final Logic extendedMultiplicand;
    if (signedMultiplicandParameter.dynamicConfig == null) {
      extendedMultiplicand = signedMultiplicandParameter.staticConfig
          ? multiplicand.signExtend(width)
          : multiplicand.zeroExtend(width);
    } else {
      final len = multiplicand.width;
      final sign = multiplicand[len - 1];
      final extension = [
        for (var i = len; i < width; i++)
          mux(signedMultiplicandParameter.dynamicConfig!, sign, Const(0))
      ];
      extendedMultiplicand = (multiplicand.elements + extension).rswizzle();
    }
    for (var pos = 0; pos < numMultiples; pos++) {
      final ratio = pos + 1;
      multiples.elements[pos] <=
          switch (ratio) {
            1 => extendedMultiplicand,
            2 => extendedMultiplicand << 1,
            3 => (extendedMultiplicand << 2) - extendedMultiplicand,
            4 => extendedMultiplicand << 2,
            5 => (extendedMultiplicand << 2) + extendedMultiplicand,
            6 => (extendedMultiplicand << 3) - (extendedMultiplicand << 1),
            7 => (extendedMultiplicand << 3) - extendedMultiplicand,
            8 => extendedMultiplicand << 3,
            _ => throw RohdHclException('Radix is beyond 16')
          };
    }
    for (var c = 0; c < width; c++) {
      multiplesSlice.add(getMultiples(c));
    }
  }

  /// Compute the multiples of the [multiplicand] at current bit position.
  Logic getMultiples(int col) {
    final columnMultiples = [
      for (var i = 0; i < multiples.elements.length; i++)
        multiples.elements[i][col]
    ].swizzle().named('multiples_c$col', naming: Naming.mergeable);
    return columnMultiples.reversed;
  }

  /// Retrieve the multiples of the [multiplicand] at current bit position.
  Logic fetchMultiples(int col) => multiplesSlice[col];

  // _select attempts to name signals that [RadixEncode] cannot due to trace.
  Logic _select(Logic multiples, RadixEncode encode) {
    final eMultiples = encode.multiples
        .named('encoded_multiple_r${encode.row}', naming: Naming.mergeable);
    final eSign = encode.sign
        .named('encode_sign_r${encode.row}', naming: Naming.mergeable);
    return (eMultiples & multiples).or() ^ eSign;
  }

  /// Select the partial product term from the multiples using a [RadixEncode].
  Logic select(int col, RadixEncode encode) {
    final mults = fetchMultiples(col)
        .named('select_r${encode.row}_c$col', naming: Naming.mergeable);
    return _select(mults, encode);
  }
}
