// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_utilities.dart
// Utilities for dealing with floating point.
//
// 2024 August 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A utility class for floating point operations.
abstract class FloatingPointUtilities {
  /// Sort two [FloatingPoint]s and swap them if necessary so that the larger
  /// of the two is the first element in the returned tuple.
  static ({(FpType larger, FpType smaller) sorted, Logic didSwap})
      sort<FpType extends FloatingPoint>((FpType, FpType) toSort) {
    final ae = toSort.$1.exponent;
    final be = toSort.$2.exponent;
    final am = toSort.$1.mantissa;
    final bm = toSort.$2.mantissa;
    final doSwap = (ae.lt(be) |
            (ae.eq(be) & am.lt(bm)) |
            ((ae.eq(be) & am.eq(bm)) & toSort.$1.sign))
        .named('doSwap');

    final swapped = logicSwap(doSwap, toSort);
    final larger =
        (swapped.$1.clone(name: 'larger')..gets(swapped.$1)) as FpType;
    final smaller =
        (swapped.$2.clone(name: 'smaller')..gets(swapped.$2)) as FpType;

    return (sorted: (larger, smaller), didSwap: doSwap);
  }

  /// Sort two [FloatingPoint]s and swap them if necessary so that the one
  /// the larger exponent is the first element in the returned tuple.
  static ({(FpType larger, FpType smaller) sorted, Logic didSwap})
      sortByExp<FpType extends FloatingPoint>((FpType, FpType) toSort) {
    final ae = toSort.$1.exponent;
    final be = toSort.$2.exponent;
    final doSwap = (ae.lt(be) | ((ae.eq(be)) & toSort.$1.sign)).named('doSwap');

    final swapped = logicSwap(doSwap, toSort);

    final larger =
        (swapped.$1.clone(name: 'larger')..gets(swapped.$1)) as FpType;
    final smaller =
        (swapped.$2.clone(name: 'smaller')..gets(swapped.$2)) as FpType;
    return (sorted: (larger, smaller), didSwap: doSwap);
  }
}

/// A module that swaps two floating point values.
abstract class FloatingPointSwap<FpType extends FloatingPoint> extends Module {
  /// The first output floating point values after the swap.
  FpType get outA => (a.clone(name: 'outA') as FpType)..gets(output('outA'));

  /// The second output floating point values after the swap.
  FpType get outB => (b.clone(name: 'outB') as FpType)..gets(output('outB'));

  /// The first output metadata value after the swap.
  Logic? get outMetaA => tryOutput('outMetaA');

  /// The second output metadata value after the swap.
  Logic? get outMetaB => tryOutput('outMetaB');

  /// The first floating point value to swap.
  @protected
  late final FpType a;

  /// The first metadata value to swap.
  @protected
  late final Logic? metaA;

  /// The second floating point value to swap.
  @protected
  late final FpType b;

  /// The second  metadata value to swap.
  @protected
  late final Logic? metaB;

  /// Constructs a [FloatingPointSwap] module that swaps two floating point
  /// values.
  FloatingPointSwap(FpType a, FpType b,
      {Logic? metaA,
      Logic? metaB,
      super.name = 'floating_point_swap',
      String definitionName = 'floating_point_swap'})
      : super(definitionName: definitionName) {
    if (a.width != b.width) {
      throw RohdHclException(
          'FloatingPointSwap requires inputs a and b to have the same width.');
    }
    if ((metaA == null) != (metaB == null)) {
      throw RohdHclException(
          'FloatingPointSwap requires both metaA and metaB to be either '
          'both null or both non-null.');
    }
    this.metaA =
        (metaA != null) ? addInput('inMetaA', metaA, width: metaA.width) : null;
    this.metaB =
        (metaB != null) ? addInput('inMetaB', metaB, width: metaB.width) : null;

    if (metaA != null && metaB != null) {
      // We have metadata to swap.
      if (metaA.width != metaB.width) {
        throw RohdHclException('FloatingPointSwap requires metaA and metaB to '
            'have the same width.');
      }
      addOutput('outMetaA', width: metaA.width);
      addOutput('outMetaB', width: metaB.width);
    }
    this.a = (a.clone(name: 'a') as FpType)
      ..gets(addInput('a', a, width: a.width));
    this.b = (b.clone(name: 'b') as FpType)
      ..gets(addInput('b', b, width: b.width));

    addOutput('outA', width: a.width);
    addOutput('outB', width: b.width);
  }
}

/// A module that swaps two floating point values based on a condition.
class FloatingPointConditionalSwap<FpType extends FloatingPoint>
    extends FloatingPointSwap<FpType> {
  /// The swap condition.
  @protected
  late final Logic swap;

  /// Constructs a [FloatingPointConditionalSwap] module that swaps two floating
  /// point values based on the [swap] condition.
  FloatingPointConditionalSwap(super.a, super.b, Logic swap,
      {super.metaA,
      super.metaB,
      super.name = 'floating_point_conditional_swap'})
      : super(definitionName: 'FloatingPointSwap_W${a.width}') {
    this.swap = addInput('swap', swap);

    final (swapA, swapB) = logicSwap(this.swap, (super.a, super.b));
    output('outA') <= swapA;
    output('outB') <= swapB;
    if ((metaA != null) & (metaB != null)) {
      final (swapMetaA, swapMetaB) =
          logicSwap(this.swap, (super.metaA!, super.metaB!));
      output('outMetaA') <= swapMetaA;
      output('outMetaB') <= swapMetaB;
    }
  }
}

/// A module that sorts two floating point values, output the larger one
/// first.
class FloatingPointSort<FpType extends FloatingPoint>
    extends FloatingPointSwap<FpType> {
  /// Constructs a [FloatingPointSort] module that sorts two floating point
  /// values so that the larger one is first.
  FloatingPointSort(super.a, super.b,
      {super.metaA, super.metaB, super.name = 'floating_point_sort'})
      : super(definitionName: 'FloatingPointSort_W${a.width}') {
    final (sorted: (larger, smaller), didSwap: doSwap) =
        FloatingPointUtilities.sort((super.a, super.b));
    output('outA') <= larger;
    output('outB') <= smaller;
    if ((metaA != null) & (metaB != null)) {
      final (swapMetaA, swapMetaB) =
          logicSwap(doSwap, (super.metaA!, super.metaB!));
      output('outMetaA') <= swapMetaA;
      output('outMetaB') <= swapMetaB;
    }
  }
}

/// A module that sorts two floating point values by exponent output the one
/// with the larger exponent first.
class FloatingPointSortByExp<FpType extends FloatingPoint>
    extends FloatingPointSwap<FpType> {
  /// Constructs a [FloatingPointSortByExp] module that sorts two floating point
  /// values so that the one with the larger exponent is first.
  FloatingPointSortByExp(super.a, super.b,
      {super.metaA, super.metaB, super.name = 'floating_point_sort_by_exp'})
      : super(definitionName: 'FloatingPointSortByExp_W${a.width}') {
    final (sorted: (larger, smaller), didSwap: doSwap) =
        FloatingPointUtilities.sortByExp((super.a, super.b));

    output('outA') <= larger;
    output('outB') <= smaller;
    if ((metaA != null) & (metaB != null)) {
      final (swapMetaA, swapMetaB) =
          logicSwap(doSwap, (super.metaA!, super.metaB!));
      output('outMetaA') <= swapMetaA;
      output('outMetaB') <= swapMetaB;
    }
  }
}
