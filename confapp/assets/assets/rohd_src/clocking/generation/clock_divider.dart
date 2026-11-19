// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// clock_divider.dart
// Divided-rate clock-enable generation.
//
// 2026 November 8
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Generates a periodic clock enable without creating a new clock domain.
///
/// After reset, [enable] is high for the edge completing each [divisor]
/// input-clock cycles. Reset suppresses the enable and restarts the period.
/// A divisor of one enables every non-reset edge.
/// {@category Clocking}
class ClockDivider extends Module {
  /// Input-clock cycles per enable.
  final int divisor;

  /// Enable for an edge of the original input clock.
  Logic get enable => output('enable');

  /// Creates a divided-rate clock-enable generator.
  ClockDivider({
    required Logic clk,
    required Logic reset,
    required this.divisor,
    super.name = 'clock_divider',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(definitionName: definitionName ?? 'ClockDivider_D$divisor') {
    if (divisor < 1) {
      throw ArgumentError.value(divisor, 'divisor', 'Must be positive.');
    }
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    final countWidth = divisor <= 2 ? 1 : (divisor - 1).bitLength;
    final count = Logic(name: 'count', width: countWidth);
    final last = count.eq(Const(divisor - 1, width: countWidth));
    addOutput('enable') <= last & ~reset;
    Sequential(clk, reset: reset, resetValues: {
      count: 0
    }, [
      If(last, then: [count < 0], orElse: [count < count + 1]),
    ]);
  }
}
