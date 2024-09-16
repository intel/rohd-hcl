// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// counter.dart
// A flexible counter implementation.
//
// 2024 August 26
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/summation/summation_base.dart';

/// Keeps a count of the running sum of any number of sources with optional
/// configuration for widths, saturation behavior, and restarting.
class Counter extends SummationBase {
  /// The output value of the counter.
  Logic get count => output('count');

  /// Creates a counter that increments according to the provided [interfaces].
  ///
  /// The [width] can be either explicitly provided or inferred from other
  /// values such as a [maxValue], [minValue], or [resetValue] that contain
  /// width information (e.g. a [LogicValue]), or by making it large enough to
  /// fit [maxValue], or by inspecting widths of [interfaces]. There must be
  /// enough information provided to determine the [width].
  ///
  /// If no [maxValue] is provided, one will be inferred by the maximum that can
  /// fit inside of the [width].
  ///
  /// The [restart] input can be used to restart the counter to a new value, but
  /// also continue to increment in that same cycle. This is distinct from
  /// [reset] which will reset the counter, holding the [count] at [resetValue].
  ///
  /// If [saturates] is `true`, then it will saturate at the [maxValue] and
  /// [minValue]. If `false`, will wrap around (overflow/underflow) at the
  /// [maxValue] and [minValue].  The [equalsMax], [equalsMin], [overflowed],
  /// and [underflowed] outputs can be used to determine if the sum is at the
  /// maximum, minimum, (would have) overflowed, or  (would have) underflowed,
  /// respectively.
  Counter(
    super.interfaces, {
    required Logic clk,
    required Logic reset,
    Logic? restart,
    dynamic resetValue = 0,
    super.maxValue,
    super.minValue = 0,
    super.width,
    super.saturates,
    super.name = 'counter',
  }) : super(initialValue: resetValue) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    if (restart != null) {
      restart = addInput('restart', restart);
    }

    addOutput('count', width: width);

    final sum = Sum(
      interfaces,
      initialValue:
          restart != null ? mux(restart, initialValueLogic, count) : count,
      maxValue: maxValueLogic,
      minValue: minValueLogic,
      width: width,
      saturates: saturates,
    );

    count <=
        flop(
          clk,
          sum.sum,
          reset: reset,
          resetValue: initialValueLogic,
        );

    // need to flop these since value is flopped
    overflowed <= flop(clk, sum.overflowed, reset: reset);
    underflowed <= flop(clk, sum.underflowed, reset: reset);

    equalsMax <= count.eq(maxValueLogic);
    equalsMin <= count.eq(minValueLogic);
  }

  /// A simplified constructor for [Counter] that accepts a single fixed amount
  /// to count [by] (up or down based on [increments]) along with much of the
  /// other available configuration in the default [Counter] constructor.
  Counter.simple({
    required Logic clk,
    required Logic reset,
    int by = 1,
    Logic? enable,
    int minValue = 0,
    int? maxValue,
    int? width,
    Logic? restart,
    bool saturates = false,
    bool increments = true,
    int resetValue = 0,
    String name = 'counter',
  }) : this([
          SumInterface(
              width: width,
              fixedAmount: by,
              hasEnable: enable != null,
              increments: increments)
            ..enable?.gets(enable!),
        ],
            clk: clk,
            reset: reset,
            resetValue: resetValue,
            restart: restart,
            maxValue: maxValue,
            minValue: minValue,
            width: width,
            saturates: saturates,
            name: name);

  /// Creates a [Counter] that counts up by all of the provided [logics],
  /// including much of the other available configuration in the default
  /// constructor.
  ///
  /// All [logics] are always incrementing and controlled optionally by a single
  /// [enable].
  factory Counter.ofLogics(
    List<Logic> logics, {
    required Logic clk,
    required Logic reset,
    Logic? restart,
    dynamic resetValue = 0,
    dynamic maxValue,
    dynamic minValue = 0,
    Logic? enable,
    int? width,
    bool saturates = false,
    String name = 'counter',
  }) =>
      Counter(
        logics
            .map((e) => SumInterface(width: e.width, hasEnable: enable != null)
              ..amount.gets(e)
              ..enable?.gets(enable!))
            .toList(),
        clk: clk,
        reset: reset,
        resetValue: resetValue,
        maxValue: maxValue,
        minValue: minValue,
        width: width,
        saturates: saturates,
        restart: restart,
        name: name,
      );
}
