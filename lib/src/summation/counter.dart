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

class Counter extends SummationBase {
  /// The output value of the counter.
  Logic get count => output('count');

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
    String name = 'counter',
  }) : this([
          SumInterface(width: width, fixedAmount: by, hasEnable: enable != null)
            ..enable?.gets(enable!),
        ],
            clk: clk,
            reset: reset,
            resetValue: 0,
            restart: restart,
            maxValue: maxValue,
            minValue: minValue,
            width: width,
            saturates: saturates,
            name: name);

  factory Counter.ofLogics(
    List<Logic> logics, {
    required Logic clk,
    required Logic reset,
    Logic? restart,
    dynamic resetValue = 0,
    dynamic maxValue,
    dynamic minValue = 0,
    int? width,
    bool saturates = false,
    String name = 'counter',
  }) =>
      Counter(
        logics
            .map((e) => SumInterface(width: e.width)..amount.gets(e))
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

  /// TODO
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
}
