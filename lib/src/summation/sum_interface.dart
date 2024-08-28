// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sum_interface.dart
// Interface for summation and counting.
//
// 2024 August 26
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';

class SumInterface extends PairInterface {
  final bool hasEnable;

  /// The [amount] to increment/decrement by, depending on [increments].
  late final Logic amount =
      fixedAmount != null ? Const(fixedAmount, width: width) : port('amount');

  /// Controls whether it should increment or decrement (based on [increments])
  /// (active high).
  ///
  /// Present if [hasEnable] is `true`.
  Logic? get enable => tryPort('enable');

  final int width;

  /// If `true`, will increment. If `false`,  will decrement.
  final bool increments;

  final dynamic fixedAmount;

  /// TODO
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
      : width = width ?? LogicValue.ofInferWidth(fixedAmount).width {
    setPorts([
      if (fixedAmount == null) Port('amount', this.width),
      if (hasEnable) Port('enable'),
    ], [
      PairDirection.fromProvider
    ]);
  }

  SumInterface.clone(SumInterface other)
      : this(
          fixedAmount: other.fixedAmount,
          increments: other.increments,
          width: other.width,
          hasEnable: other.hasEnable,
        );
}
