// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// counter.dart
// A flexible counter implementation.
//
// 2024 August 26
// Author: Max Korbel <max.korbel@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/summation/summation_base.dart';

/// Keeps a count of the running sum of any number of sources with optional
/// configuration for widths, saturation behavior, and restarting.
class Counter extends SummationBase {
  /// The output value of the counter.
  Logic get count => output('count');

  /// The main clock signal.
  @visibleForTesting
  @protected
  late final Logic clk;

  /// The reset signal.
  @protected
  late final Logic reset;

  /// Whether the [reset] is asynchronous.
  final bool asyncReset;

  /// The restart signal.
  @protected
  late final Logic? restart;

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
    this.asyncReset = false,
    super.maxValue,
    super.minValue = 0,
    super.width,
    super.saturates,
    super.name = 'counter',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
            initialValue: resetValue,
            definitionName:
                definitionName ?? 'Counter_L${interfaces.length}}') {
    this.clk = addInput('clk', clk);
    this.reset = addInput('reset', reset);
    if (restart != null) {
      this.restart = addInput('restart', restart);
    } else {
      this.restart = null;
    }

    addOutput('count', width: width);

    _buildLogic();
  }

  /// The internal [Sum] that is used to keep track of the count.
  @protected
  late final Sum summer = Sum(
    interfaces,
    initialValue:
        restart != null ? mux(restart!, initialValueLogic, count) : count,
    maxValue: maxValueLogic,
    minValue: minValueLogic,
    width: width,
    saturates: saturates,
  );

  /// Builds the internal logic for the counter.
  void _buildLogic() {
    buildFlops();

    // need to flop these since value is flopped
    overflowed <=
        flop(clk, summer.overflowed, reset: reset, asyncReset: asyncReset);
    underflowed <=
        flop(clk, summer.underflowed, reset: reset, asyncReset: asyncReset);

    equalsMax <= count.eq(maxValueLogic);
    equalsMin <= count.eq(minValueLogic);
  }

  /// Builds the flops that store the [count].
  @protected
  void buildFlops() {
    count <=
        flop(
          clk,
          summer.sum,
          reset: reset,
          resetValue: initialValueLogic,
          asyncReset: asyncReset,
        );
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
    bool asyncReset = false,
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
            asyncReset: asyncReset,
            restart: restart,
            maxValue: maxValue,
            minValue: minValue,
            width: width,
            saturates: saturates,
            name: name);

  /// A simplified constructor for [Counter] that accepts a single fixed amount
  /// to count [by] along with much of the
  /// other available configuration in the default [Counter] constructor.
  /// And allows for both incrementing and decrementing the count.
  Counter.updn({
    required Logic clk,
    required Logic reset,
    required Logic enableInc,
    required Logic enableDec,
    int by = 1,
    int minValue = 0,
    int? maxValue,
    int? width,
    Logic? restart,
    bool saturates = false,
    bool asyncReset = false,
    int resetValue = 0,
    String name = 'counter',
  }) : this([
          SumInterface(
            width: width,
            fixedAmount: by,
            hasEnable: true,
          )..enable?.gets(enableInc),
          SumInterface(
              width: width, fixedAmount: by, hasEnable: true, increments: false)
            ..enable?.gets(enableDec),
        ],
            clk: clk,
            reset: reset,
            resetValue: resetValue,
            asyncReset: asyncReset,
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
    bool asyncReset = false,
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
        asyncReset: asyncReset,
        maxValue: maxValue,
        minValue: minValue,
        width: width,
        saturates: saturates,
        restart: restart,
        name: name,
      );
}
