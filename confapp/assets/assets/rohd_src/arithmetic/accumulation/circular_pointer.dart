// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// circular_pointer.dart
// Wrapping pointer over an arbitrary number of slots.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';
import 'package:rohd_hcl/src/utils.dart';

/// A registered pointer that advances by a variable increment and wraps
/// modulo [slots].
///
/// The [pointer] holds a value in `0..slots-1` and is reset to zero. Each
/// cycle it advances by `increment`, wrapping back to the start of the range
/// when it reaches [slots]. [wrapped] is high when the pointer plus the
/// current increment reaches [slots].
///
/// [slots] need not be a power of two. Each `increment` must be less than
/// [slots], so a single advance crosses the boundary at most once.
/// {@category Arithmetic}
class CircularPointer extends Module {
  /// The number of slots the pointer cycles through.
  final int slots;

  /// The current pointer value, in `0..slots-1`.
  Logic get pointer => output('pointer');

  /// High when the current increment wraps the pointer past [slots].
  Logic get wrapped => output('wrapped');

  /// Creates a wrapping pointer over [slots] slots.
  CircularPointer(
    Logic clk,
    Logic reset,
    Logic increment, {
    required this.slots,
    super.name = 'circular_pointer',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          definitionName:
              definitionName ?? 'CircularPointer_S${slots}_W${increment.width}',
        ) {
    if (slots < 2) {
      throw RohdHclException('CircularPointer needs at least 2 slots, got '
          '$slots.');
    }

    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    increment = addInput('increment', increment, width: increment.width);

    final pointerWidth = widthFor(slots);
    final sumWidth =
        (pointerWidth > increment.width ? pointerWidth : increment.width) + 2;

    final current = Logic(name: 'current', width: pointerWidth);
    final sum = (current.zeroExtend(sumWidth) + increment.zeroExtend(sumWidth))
        .named('sum', naming: Naming.mergeable);
    final wrap = sum
        .gte(Const(slots, width: sumWidth))
        .named('wrapped', naming: Naming.mergeable);
    final next = mux(wrap, sum - Const(slots, width: sumWidth), sum)
        .slice(pointerWidth - 1, 0);

    Sequential(clk, reset: reset, [
      current < next,
    ]);

    addOutput('pointer', width: pointerWidth) <= current;
    addOutput('wrapped') <= wrap;
  }
}
