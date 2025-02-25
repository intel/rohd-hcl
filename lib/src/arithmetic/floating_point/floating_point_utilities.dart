// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_utilities.dart
// Utilities for dealing with floating point.
//
// 2024 August 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A utility class for floating point operations.
abstract class FloatingPointUtilities {
  /// Swap two [FloatingPoint] structures based on a conditional [swap].
  static (FpType, FpType) swap<FpType extends FloatingPoint>(
      Logic swap, (FpType, FpType) toSwap) {
    final in1 = toSwap.$1.named('swapIn1_${toSwap.$1.name}');
    final in2 = toSwap.$2.named('swapIn2_${toSwap.$2.name}');

    FpType clone({String? name}) => toSwap.$1.clone(name: name) as FpType;

    final out1 = mux(swap, in2, in1).named('swapOut1');
    final out2 = mux(swap, in1, in2).named('swapOut2');
    final first = clone(name: 'swapOut1')..gets(out1);
    final second = clone(name: 'swapOut2')..gets(out2);
    return (first, second);
  }

  /// Sort two [FloatingPoint]s and swap them if necessary so that the larger
  /// of the two is the first element in the returned tuple.
  static (FpType larger, FpType smaller) sortFp<FpType extends FloatingPoint>(
      (FpType, FpType) toSort) {
    final ae = toSort.$1.exponent;
    final be = toSort.$2.exponent;
    final am = toSort.$1.mantissa;
    final bm = toSort.$2.mantissa;
    final doSwap = (ae.lt(be) |
            (ae.eq(be) & am.lt(bm)) |
            ((ae.eq(be) & am.eq(bm)) & toSort.$1.sign))
        .named('doSwap');

    final swapped = swap(doSwap, toSort);

    FpType clone({String? name}) => toSort.$1.clone(name: name) as FpType;

    final larger = clone(name: 'larger')..gets(swapped.$1);
    final smaller = clone(name: 'smaller')..gets(swapped.$2);

    return (larger, smaller);
  }
}
