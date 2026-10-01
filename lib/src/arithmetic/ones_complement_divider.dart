// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ones_complement_divider.dart
// Integer Divider using one's complement signed arithmetic.
//
// 2025 April
// Author: Jose Rojas Chaves <jose.rojas.chaves@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A multi-cycle integer divider that uses **one's complement** signed
/// arithmetic.
///
/// This implementation shares the same FSM/state-management logic as
/// [TwosComplementDivider], but overrides the signed-arithmetic hooks to use
/// one's complement conventions in the datapath.
class OnesComplementDivider extends MultiCycleDividerBase {
  /// Creates a one's complement multi-cycle divider.
  OnesComplementDivider(
    super.interface, {
    super.computeRemainder = true,
    super.name = 'ones_complement_divider',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          definitionName:
              definitionName ?? 'OnesComplementDivider_W${interface.dataWidth}',
        );

  /// Factory constructor matching [TwosComplementDivider.ofLogics].
  factory OnesComplementDivider.ofLogics({
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
    return OnesComplementDivider(intf,
        computeRemainder: computeRemainder,
        reserveName: reserveName,
        reserveDefinitionName: reserveDefinitionName,
        definitionName:
            definitionName ?? 'OnesComplementDivider_W${intf.dataWidth}');
  }

  @override
  Logic negate(Logic x) => ~x;

  @override
  Logic isZeroDivisor(Logic rawDivisor) =>
      ~rawDivisor.or() | (rawDivisor.and() & intf.isSigned);
}

// =============================================================================
