// Copyright (C) 2024-2026 Intel Corporation
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

import 'package:rohd_hcl/src/arithmetic/accumulation/summation_base.dart';

/// Keeps a count of the running sum of any number of sources with optional
/// configuration for widths, saturation behavior, and restarting.
class Counter extends SummationBase {
  /// The output value of the counter.
  Logic get count => output('count');

  /// Registered overflow status for the current update cycle, if
  /// [trackOverflow] is true.
  ///
  /// This is not a sticky "has ever overflowed" flag: a following update
  /// without a raw overflow clears it.
  @override
  Logic? get overflowed => super.overflowed;

  /// Registered underflow status for the current update cycle, if
  /// [trackUnderflow] is true.
  ///
  /// This is not a sticky "has ever underflowed" flag: a following update
  /// without a raw underflow clears it.
  @override
  Logic? get underflowed => super.underflowed;

  /// The main clock signal.
  @visibleForTesting
  @protected
  late final Logic clk;

  /// The reset signal.
  @protected
  late final Logic reset;

  /// Whether the [reset] is asynchronous.
  final bool asyncReset;

  /// Whether [overflowed] is generated to record overflow history.
  ///
  /// This affects reporting only; it does not change whether [count] wraps or
  /// saturates. When `false`, the output port is omitted and [overflowed] is
  /// `null`.
  final bool trackOverflow;

  /// Whether [underflowed] is generated to record underflow history.
  ///
  /// This affects reporting only; it does not change whether [count] wraps or
  /// saturates. When `false`, the output port is omitted and [underflowed] is
  /// `null`.
  final bool trackUnderflow;

  /// Internal overflow history, retained independently of the public port.
  @protected
  late final Logic overflowHistory;

  /// Internal underflow history, retained independently of the public port.
  @protected
  late final Logic underflowHistory;

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
  /// [saturates] chooses whether a raw result outside [maxValue] and
  /// [minValue] is corrected by clamping or wrapping. It does not determine
  /// whether a raw overflow or underflow occurs: enabled [overflowed] and
  /// [underflowed] status report that raw violation in either correction mode.
  /// [trackOverflow] and [trackUnderflow] control only that status reporting
  /// and do not alter [count].
  Counter(
    super.interfaces, {
    required Logic clk,
    required Logic reset,
    Logic? restart,
    dynamic resetValue = 0,
    this.asyncReset = false,
    this.trackOverflow = true,
    this.trackUnderflow = true,
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
            definitionName: definitionName ??
                'Counter_L${interfaces.length}'
                    '${trackOverflow ? "" : "_NO"}'
                    '${trackUnderflow ? "" : "_NU"}',
            generateOverflowedOutput: trackOverflow,
            generateUnderflowedOutput: trackUnderflow) {
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
    // Preserve constant bounds so Sum can prune unreachable overflow paths.
    maxValue: constantMaxValue != null && !constantMaxValue!.isNegative
        ? constantMaxValue
        : maxValueLogic,
    minValue: constantMinValue != null && !constantMinValue!.isNegative
        ? constantMinValue
        : minValueLogic,
    width: width,
    saturates: saturates,
  );

  /// Builds the internal logic for the counter.
  void _buildLogic() {
    buildFlops();

    overflowHistory = Logic(name: 'overflowHistory');
    underflowHistory = Logic(name: 'underflowHistory');

    // These histories are internal counter state. GatedCounter uses them for
    // behavior independent of whether callers request public status ports.
    if (trackOverflow && summer.canOverflow) {
      overflowHistory <=
          flop(clk, summer.overflowed, reset: reset, asyncReset: asyncReset);
    } else {
      overflowHistory <= Const(0);
    }
    if (trackUnderflow && summer.canUnderflow) {
      underflowHistory <=
          flop(clk, summer.underflowed, reset: reset, asyncReset: asyncReset);
    } else {
      underflowHistory <= Const(0);
    }
    if (trackOverflow) {
      overflowed! <= overflowHistory;
    }
    if (trackUnderflow) {
      underflowed! <= underflowHistory;
    }

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
    bool trackOverflow = true,
    bool trackUnderflow = true,
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
            trackOverflow: trackOverflow,
            trackUnderflow: trackUnderflow,
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
  Counter.upDown({
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
    bool trackOverflow = true,
    bool trackUnderflow = true,
    int resetValue = 0,
    String name = 'counter',
  }) : this([
          SumInterface(
            width: width,
            fixedAmount: by,
            hasEnable: true,
          )..enable!.gets(enableInc),
          SumInterface(
              width: width, fixedAmount: by, hasEnable: true, increments: false)
            ..enable!.gets(enableDec),
        ],
            clk: clk,
            reset: reset,
            resetValue: resetValue,
            asyncReset: asyncReset,
            trackOverflow: trackOverflow,
            trackUnderflow: trackUnderflow,
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
    bool trackOverflow = true,
    bool trackUnderflow = true,
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
        trackOverflow: trackOverflow,
        trackUnderflow: trackUnderflow,
        maxValue: maxValue,
        minValue: minValue,
        width: width,
        saturates: saturates,
        restart: restart,
        name: name,
      );
}
