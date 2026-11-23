// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// accumulator.dart
// A lightweight increment-only accumulator.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// Accumulates an unsigned `amount` with optional natural-width saturation.
///
/// This value-only module avoids the underflow, arbitrary-range, and
/// diagnostic hardware provided by a fully bounded counter. `clear` loads
/// `resetValue` without adding, while `restart` loads `resetValue` and then
/// applies the enabled `amount`.
/// {@category Arithmetic}
class Accumulator extends Module {
  /// The width of [value].
  final int width;

  /// Whether [value] saturates at its natural maximum instead of wrapping.
  final bool saturates;

  /// Whether `reset` is asynchronous.
  final bool asyncReset;

  /// The accumulated value.
  Logic get value => output('value');

  /// Creates an unsigned increment-only accumulator.
  Accumulator(
    Logic amount, {
    required Logic clk,
    required Logic reset,
    required this.width,
    Logic? enable,
    Logic? clear,
    Logic? restart,
    dynamic resetValue = 0,
    this.saturates = false,
    this.asyncReset = false,
    super.name = 'accumulator',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          definitionName: definitionName ??
              'Accumulator_W${width}_A${amount.width}_'
                  'S${saturates ? 1 : 0}_R${restart == null ? 0 : 1}_'
                  'C${clear == null ? 0 : 1}_E${enable == null ? 0 : 1}_'
                  'A${asyncReset ? 1 : 0}',
        ) {
    if (width <= 0) {
      throw RohdHclException('Accumulator width must be greater than zero.');
    }

    amount = addInput('amount', amount, width: amount.width);
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    if (enable != null) {
      enable = addInput('enable', enable);
    }
    if (clear != null) {
      clear = addInput('clear', clear);
    }
    if (restart != null) {
      restart = addInput('restart', restart);
    }

    final resetValueLogic = _makeResetValue(resetValue);
    final value = addOutput('value', width: width);
    final accumulationWidth = max(width, amount.width) + 1;
    final baseValue = mux(
      restart ?? Const(0),
      resetValueLogic,
      value,
    ).zeroExtend(accumulationWidth);
    final enabledAmount = mux(
      enable ?? Const(1),
      amount,
      Const(0, width: amount.width),
    ).zeroExtend(accumulationWidth);
    final wideSum =
        (baseValue + enabledAmount).named('wideSum', naming: Naming.mergeable);
    final nextValue = saturates
        ? mux(
            wideSum.getRange(width).or(),
            Const((BigInt.one << width) - BigInt.one, width: width),
            wideSum.getRange(0, width),
          )
        : wideSum.getRange(0, width);

    Sequential(
      clk,
      reset: reset,
      asyncReset: asyncReset,
      resetValues: {value: resetValueLogic},
      [
        If(clear ?? Const(0), then: [
          value < resetValueLogic,
        ], orElse: [
          If((restart ?? Const(0)) | (enable ?? Const(1)), then: [
            value < nextValue,
          ]),
        ]),
      ],
    );
  }

  Logic _makeResetValue(dynamic resetValue) {
    if (resetValue is Logic) {
      if (resetValue.width > width) {
        throw RohdHclException(
            'Accumulator reset value width must not exceed $width.');
      }
      return addInput(
        'resetValue',
        resetValue.zeroExtend(width),
        width: width,
      );
    }

    final value = resetValue is LogicValue ? resetValue.toBigInt() : resetValue;
    if (value is! int && value is! BigInt) {
      throw RohdHclException(
        'Accumulator reset value must be an int, BigInt, LogicValue, or Logic.',
      );
    }
    final bigValue = value is int ? BigInt.from(value) : value as BigInt;
    if (bigValue.isNegative || bigValue >= (BigInt.one << width)) {
      throw RohdHclException(
          'Accumulator reset value must fit in $width unsigned bits.');
    }
    return Const(bigValue, width: width);
  }
}
