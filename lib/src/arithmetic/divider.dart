// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// divider.dart
// Implementation of Integer Divider Module.
//
// 2024 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// States for the shared divider FSM.
enum MultiCycleDividerStates {
  /// Ready for a new division.
  ready,

  /// Processing a current step in the algorithm.
  process,

  /// Accumulating the result of a current step in the algorithm.
  accumulate,

  /// Converting the final result of the algorithm.
  convert,

  /// Division complete.
  done,
}

/// Internal interface to the Divider.
class MultiCycleDividerInterface extends PairInterface {
  /// Clock for sequential logic.
  Logic get clk => port('clk');

  /// Reset for sequential logic (active high).
  Logic get reset => port('reset');

  /// Dividend (numerator) for the division operation.
  Logic get dividend => port('dividend');

  /// Divisor (denominator) for the division operation.
  Logic get divisor => port('divisor');

  /// Are the division operands signed.
  Logic get isSigned => port('isSigned');

  /// The integrating environment is ready to accept the output of the module.
  Logic get readyOut => port('readyOut');

  /// Request for a new division operation to be performed.
  Logic get validIn => port('validIn');

  /// Quotient (result) for the division operation.
  Logic get quotient => port('quotient');

  /// Remainder (modulus) for the division operation.
  Logic get remainder => port('remainder');

  /// A Division by zero occurred.
  Logic get divZero => port('divZero');

  /// The result of the current division operation is ready.
  Logic get validOut => port('validOut');

  /// The module is ready to accept new inputs.
  Logic get readyIn => port('readyIn');

  /// The width of the data operands and result.
  final int dataWidth;

  /// A constructor for the divider interface.
  MultiCycleDividerInterface({this.dataWidth = 32})
      : super(portsFromProvider: [
          Logic.port('clk'),
          Logic.port('reset'),
          Logic.port('dividend', dataWidth),
          Logic.port('divisor', dataWidth),
          Logic.port('isSigned'),
          Logic.port('validIn'),
          Logic.port('readyOut'),
        ], portsFromConsumer: [
          Logic.port('quotient', dataWidth),
          Logic.port('remainder', dataWidth),
          Logic.port('divZero'),
          Logic.port('validOut'),
          Logic.port('readyIn'),
        ]);

  /// A match constructor for the divider interface.
  @Deprecated('Use clone() instead.')
  MultiCycleDividerInterface.match(MultiCycleDividerInterface other)
      : this(dataWidth: other.dataWidth);

  /// Clones this [MultiCycleDividerInterface].
  @override
  MultiCycleDividerInterface clone() =>
      MultiCycleDividerInterface(dataWidth: dataWidth);
}

/// The Divider module definition.
class TwosComplementDivider extends MultiCycleDividerBase {
  /// The Divider module's constructor.
  TwosComplementDivider(
    super.interface, {
    super.computeRemainder = true,
    super.name = 'multi_cycle_divider',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          definitionName:
              definitionName ?? 'MultiCycleDivider_W${interface.dataWidth}',
        );

  /// Factory method to create a [TwosComplementDivider]
  /// from explicit [Logic] signals instead of an interface.
  factory TwosComplementDivider.ofLogics({
    required Logic clk,
    required Logic reset,
    required Logic validIn,
    required Logic dividend,
    required Logic divisor,
    required Logic isSigned,
    required Logic readyOut,
    bool computeRemainder = true,
    bool reserveName = false,
    bool reserveDefinitionName = false,
    String? definitionName,
  }) {
    assert(dividend.width == divisor.width,
        'Widths of all data signals do not match!');
    final dataWidth = dividend.width;
    final intf = MultiCycleDividerInterface(dataWidth: dataWidth);
    intf.clk <= clk;
    intf.reset <= reset;
    intf.validIn <= validIn;
    intf.dividend <= dividend;
    intf.divisor <= divisor;
    intf.isSigned <= isSigned;
    intf.readyOut <= readyOut;
    return TwosComplementDivider(intf,
        computeRemainder: computeRemainder,
        reserveName: reserveName,
        reserveDefinitionName: reserveDefinitionName,
        definitionName:
            definitionName ?? 'MultiCycleDivider_W${intf.dataWidth}');
  }

  @override
  Logic negate(Logic x) => ~x + 1;

  @override
  Logic isZeroDivisor(Logic rawDivisor) => ~rawDivisor.or();

  @override
  Logic overflowSpecialCase(Logic bBuf, Logic signOut, Logic signNum) =>
      bBuf[dataWidth - 1] &
      ~bBuf.getRange(0, dataWidth - 2).or() &
      (signOut ^ signNum);
}

/// Deprecated alias for [TwosComplementDivider].
@Deprecated(
  'Use TwosComplementDivider instead. This alias is kept for compatibility.',
)
typedef MultiCycleDivider = TwosComplementDivider;
