// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sum_interface.dart
// Interface for summation and counting.
//
// 2024 August 26
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/summation/summation_base.dart';

/// A [PairInterface] representing an amount and behavior for inclusion in a
/// sum or count.
class SumInterface extends PairInterface {
  /// Whether an [enable] signal is present on this interface.
  final bool hasEnable;

  /// The [amount] to increment/decrement by, depending on [increments].
  late final Logic amount =
      fixedAmount != null ? Const(fixedAmount, width: width) : port('amount');

  /// Controls whether it should increment or decrement (based on [increments])
  /// (active high).
  ///
  /// Present if [hasEnable] is `true`.
  Logic? get enable => tryPort('enable');

  /// The [width] of the [amount].
  final int width;

  /// If `true`, will increment. If `false`,  will decrement.
  final bool increments;

  /// If non-`null`, the constant value of [amount].
  final dynamic fixedAmount;

  BigInt get maxIncrementMagnitude => fixedAmount != null
      ? LogicValue.ofInferWidth(fixedAmount).toBigInt()
      : SummationBase.biggestVal(width);

  /// Creates a new [SumInterface] with a fixed or variable [amount], optionally
  /// with an [enable], in either positive or negative direction based on
  /// [increments].
  ///
  /// If [width] is `null`, it can be inferred from [fixedAmount] if provided
  /// with a type that contains width information (e.g. a [LogicValue]). There
  /// must be enough information provided to determine the [width].
  ///
  /// If a [fixedAmount] is provided, then [amount] will be tied to a [Const]. A
  /// provided [fixedAmount] must be parseable by [LogicValue.of]. Note that the
  /// [fixedAmount] will always be interpreted as a positive value truncated to
  /// [width]. If no [fixedAmount] is provided, then [amount] will be a normal
  /// [port] with [width] bits.
  ///
  /// If [hasEnable] is `true`, then an [enable] port will be added to the
  /// interface.
  SumInterface(
      {this.fixedAmount,
      this.increments = true,
      int? width,
      this.hasEnable = false})
      : width = (width == null && fixedAmount == null)
            ? throw RohdHclException(
                'Must provide either a fixedAmount or width.')
            : width ?? max(LogicValue.ofInferWidth(fixedAmount).width, 1) {
    if (this.width <= 0) {
      throw RohdHclException('Width must be positive.');
    }
    setPorts([
      if (fixedAmount == null) Port('amount', this.width),
      if (hasEnable) Port('enable'),
    ], [
      PairDirection.fromProvider
    ]);
  }

  /// Creates a clone of this [SumInterface] for things like [pairConnectIO].
  SumInterface.clone(SumInterface other)
      : this(
          fixedAmount: other.fixedAmount,
          increments: other.increments,
          width: other.width,
          hasEnable: other.hasEnable,
        );

  @override
  String toString() => [
        'SumInterface[$width]',
        if (fixedAmount != null) ' = $fixedAmount',
        if (increments) ' ++ ' else ' -- ',
        if (hasEnable) ' (enable)',
      ].join();
}
