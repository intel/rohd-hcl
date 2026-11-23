// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// iterative_divider_engine.dart
// Implementation of Iterative Divider Engine.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/division_and_roots/divider.dart';

/// Direct scheduled shell for the iterative multi-cycle divider.
///
/// A high `start` is accepted only while [busy] is low. [done] pulses for one
/// cycle with valid [quotient], [remainder], and [divZero] outputs. Results are
/// consumed immediately by this direct engine; a transport shell must add
/// retention if its consumer can stall.
/// {@category Arithmetic}
class IterativeDividerEngine extends Module {
  /// Quotient valid while [done] is high.
  Logic get quotient => output('quotient');

  /// Remainder valid while [done] is high.
  Logic get remainder => output('remainder');

  /// Division-by-zero status valid while [done] is high.
  Logic get divZero => output('divZero');

  /// High from an accepted start until completion.
  Logic get busy => output('busy');

  /// Pulses when the current operation completes.
  Logic get done => output('done');

  /// Width of both operands and each result.
  final int dataWidth;

  /// Creates a direct-control iterative divider.
  IterativeDividerEngine({
    required Logic clk,
    required Logic reset,
    required Logic start,
    required Logic dividend,
    required Logic divisor,
    required Logic isSigned,
    String name = 'iterative_divider_engine',
  })  : dataWidth = dividend.width,
        super(
          definitionName: 'IterativeDividerEngine_W${dividend.width}',
          name: name,
        ) {
    if (dividend.width != divisor.width) {
      throw ArgumentError('Dividend and divisor widths must match.');
    }
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    start = addInput('start', start);
    dividend = addInput('dividend', dividend, width: dividend.width);
    divisor = addInput('divisor', divisor, width: divisor.width);
    isSigned = addInput('isSigned', isSigned);

    final dividerInterface = MultiCycleDividerInterface(dataWidth: dataWidth);
    dividerInterface.clk <= clk;
    dividerInterface.reset <= reset;
    dividerInterface.validIn <= start;
    dividerInterface.dividend <= dividend;
    dividerInterface.divisor <= divisor;
    dividerInterface.isSigned <= isSigned;
    dividerInterface.readyOut <= Const(1);
    final divider = MultiCycleDivider(dividerInterface, name: '${name}_core');

    addOutput('quotient', width: dataWidth) <= divider.quotient;
    addOutput('remainder', width: dataWidth) <= divider.remainder;
    addOutput('divZero') <= divider.divZero;
    addOutput('busy') <= ~divider.readyIn;
    addOutput('done') <= divider.validOut;
  }
}
