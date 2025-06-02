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
  /// Swap two [FloatingPoint] structures based on a conditional [swap].
  static (FpType, FpType) swap<FpType extends FloatingPoint>(
      Logic swap, (FpType, FpType) toSwap) {
    final in1 = toSwap.$1.named('swapIn1_${toSwap.$1.name}');
    final in2 = toSwap.$2.named('swapIn2_${toSwap.$2.name}');

    FpType clone1({String? name}) => toSwap.$1.clone(name: name) as FpType;
    FpType clone2({String? name}) => toSwap.$2.clone(name: name) as FpType;

    final out1 = mux(swap, in2, in1).named('swapOut1');
    final out2 = mux(swap, in1, in2).named('swapOut2');
    final first = clone2(name: 'swapOut1')..gets(out1);
    final second = clone1(name: 'swapOut2')..gets(out2);

    return (first, second);
  }

  /// Sort two [FloatingPoint]s and swap them if necessary so that the larger
  /// of the two is the first element in the returned tuple.
  static (FpType larger, FpType smaller) sort<FpType extends FloatingPoint>(
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
    final larger =
        (swapped.$1.clone(name: 'larger')..gets(swapped.$1)) as FpType;
    final smaller =
        (swapped.$2.clone(name: 'smaller')..gets(swapped.$2)) as FpType;

    return (larger, smaller);
  }

  /// Sort two [FloatingPoint]s and swap them if necessary so that the one
  /// the larger exponent is the first element in the returned tuple.
  static (FpType larger, FpType smaller)
      sortByExp<FpType extends FloatingPoint>((FpType, FpType) toSort) {
    final ae = toSort.$1.exponent;
    final be = toSort.$2.exponent;
    final doSwap = (ae.lt(be) | ((ae.eq(be)) & toSort.$1.sign)).named('doSwap');

    final swapped = swap(doSwap, toSort);

    final larger =
        (swapped.$1.clone(name: 'larger')..gets(swapped.$1)) as FpType;
    final smaller =
        (swapped.$2.clone(name: 'smaller')..gets(swapped.$2)) as FpType;
    return (larger, smaller);
  }
}

/// A module that swaps two floating point values.
abstract class FloatingPointSwap<FpType extends FloatingPoint> extends Module {
  /// The first output floating point values after the swap.
  FpType get outA => (a.clone(name: 'outA') as FpType)..gets(output('outA'));

  /// The second output floating point values after the swap.
  FpType get outB => (b.clone(name: 'outB') as FpType)..gets(output('outB'));

  /// The first floating point value to swap.
  @protected
  late final FpType a;

  /// The second floating point value to swap.
  @protected
  late final FpType b;

  /// Internal storage of the first swapped output.
  @protected
  late final FpType outputA;

  /// Internal storage of the second swapped output.
  @protected
  late final FpType outputB;

  /// Constructs a [FloatingPointSwap] module that swaps two floating point
  /// values.
  FloatingPointSwap(FpType a, FpType b,
      {super.name = 'floating_point_swap',
      String definitionName = 'floating_point_swap'})
      : super(definitionName: definitionName) {
    if (a.width != b.width) {
      throw RohdHclException(
          'FloatingPointSwap requires inputs a and b to have the same width.');
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
      {super.name = 'floating_point_conditional_swap'})
      : super(definitionName: 'FloatingPointSwap_W${a.width}') {
    this.swap = addInput('swap', swap);

    final (swapA, swapB) =
        FloatingPointUtilities.swap(this.swap, (super.a, super.b));
    output('outA') <= swapA;
    output('outB') <= swapB;
  }
}

/// A module that sorts two floating point values, output the larger one
/// first.
class FloatingPointSort<FpType extends FloatingPoint>
    extends FloatingPointSwap<FpType> {
  /// Constructs a [FloatingPointSort] module that sorts two floating point
  /// values so that the larger one is first.
  FloatingPointSort(super.a, super.b, {super.name = 'floating_point_sort'})
      : super(definitionName: 'FloatingPointSort_W${a.width}') {
    final (larger, smaller) = FloatingPointUtilities.sort((super.a, super.b));
    output('outA') <= larger;
    output('outB') <= smaller;
  }
}

/// A module that sorts two floating point values by exponent output the one
/// with the larger exponent first.
class FloatingPointSortByExp<FpType extends FloatingPoint>
    extends FloatingPointSwap<FpType> {
  /// Constructs a [FloatingPointSortByExp] module that sorts two floating point
  /// values so that the one with the larger exponent is first.
  FloatingPointSortByExp(super.a, super.b,
      {super.name = 'floating_point_sort_by_exp'})
      : super(definitionName: 'FloatingPointSortByExp_W${a.width}') {
    final (larger, smaller) =
        FloatingPointUtilities.sortByExp((super.a, super.b));
    // TODO(desmonddak): I know I can assign to a field instead, but I'm
    // struggling getting it to work with explicit
    output('outA') <= larger;
    output('outB') <= smaller;
  }
}

/// [FloatingPoint] class which wraps in a Logic for the JBit.
class FloatingPointWithJBit extends FloatingPoint {
  /// Return the explicitJBit as a Logic signal.
  Logic get explicit => explicitJBitLogic;

  /// Store the explicitness of the J bit.
  late final Logic explicitJBitLogic;

  /// Construct a [FloatingPointWithJBit] from a [FloatingPoint] instance.
  FloatingPointWithJBit(FloatingPoint fp, {super.name})
      : super(
            mantissaWidth: fp.mantissa.width,
            exponentWidth: fp.exponent.width,
            explicitJBit: fp.explicitJBit) {
    explicitJBitLogic = Const(fp.explicitJBit ? 1 : 0);
    // gets(fp);
  }

  @override
  FloatingPointWithJBit clone({String? name, bool explicitJBit = false}) =>
      FloatingPointWithJBit(this);
  @override
  FloatingPointValuePopulator<FloatingPointValue> valuePopulator() =>
      FloatingPointValue.populator(
          mantissaWidth: mantissa.width,
          exponentWidth: exponent.width,
          explicitJBit: explicitJBit);
}
