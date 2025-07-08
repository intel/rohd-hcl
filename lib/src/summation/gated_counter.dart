// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// gated_counter.dart
// A flexible counter implementation with clock and toggle gating.
//
// 2024 October
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A version of a [Counter] which includes [ClockGate]ing and [ToggleGate]ing
/// for power savings.
class GatedCounter extends Counter {
  /// If `true`, then the counter will gate the toggles of the interfaces when
  /// they are not enabled.
  final bool gateToggles;

  /// The [ClockGateControlInterface] to use for clock gating internally.
  final ClockGateControlInterface? _clockGateControlInterface;

  @override
  @protected
  List<SumInterface> get interfaces => _interfaces;
  late final _interfaces = gateToggles
      ? super.interfaces.map((e) {
          final intf = SumInterface.clone(e);

          intf.enable?.gets(e.enable!);

          if (intf.hasEnable && intf.fixedAmount == null) {
            // only need to ungate if enable is high

            intf.amount <=
                (Logic(name: 'toggle_gated_amount', width: e.width)
                  ..gets(ToggleGate(
                    enable: e.enable!,
                    data: e.amount,
                    clk: clk,
                    reset: reset,
                    clockGateControlIntf: _clockGateControlInterface,
                  ).gatedData));
          } else if (intf.fixedAmount == null) {
            intf.amount <= e.amount;
          }

          return intf;
        }).toList()
      : super.interfaces;

  /// The index at which to partition the counter for clock gating.
  ///
  /// If less than 0 or greater than the [width], then the entire counter will
  /// be gated together rather than partitioned.
  late final int clkGatePartitionIndex;

  /// A provided [clkGatePartitionIndex], if one was provided.
  final int? _providedClkGateParitionIndex;

  /// Constructs a [GatedCounter] in the same way as a [Counter], but with the
  /// added ability to [gateToggles] of the interfaces when they are not enabled
  /// and gate the clocks of the counter in a partitioned way.
  ///
  /// Clock gating is performed on the same cycle as the increment/decrement(s),
  /// so the functionality when compared to the base [Counter] is identical with
  /// no added latency to the [count].
  ///
  /// The [clkGatePartitionIndex] is the index at which to partition the counter
  /// for clock gating. If the [clkGatePartitionIndex] is less than 0 or greater
  /// than the [width], then the entire counter will be gated together rather
  /// than partitioned. If no [clkGatePartitionIndex] is provided, the counter
  /// will attempt to infer a good partition index based on the interfaces
  /// provided.
  GatedCounter(super.interfaces,
      {required super.clk,
      required super.reset,
      super.restart,
      super.resetValue,
      super.maxValue,
      super.minValue,
      super.width,
      super.saturates,
      this.gateToggles = true,
      ClockGateControlInterface? clockGateControlInterface,
      int? clkGatePartitionIndex,
      super.name,
      super.definitionName})
      : _providedClkGateParitionIndex = clkGatePartitionIndex,
        _clockGateControlInterface = clockGateControlInterface == null
            ? null
            : ClockGateControlInterface.clone(clockGateControlInterface) {
    _clockGateControlInterface?.pairConnectIO(
        this, clockGateControlInterface!, PairRole.consumer);
  }

  /// All [interfaces] which are incrementing.
  late final _incrementingInterfaces =
      interfaces.where((intf) => intf.increments);

  /// All [interfaces] which are decrementing.
  late final _decrementingInterfaces =
      interfaces.where((intf) => !intf.increments);

  /// High if the counter may overflow.
  @visibleForTesting
  late final Logic mayOverflow = Logic(name: 'mayOverflow')
    ..gets(_calculateMayOverflow());

  Logic _calculateMayOverflow() {
    if (saturates) {
      // if this is a saturating counter, we will never wrap-around
      return Const(0);
    }

    if (_incrementingInterfaces.isEmpty) {
      // if we never increment, no chance of overflow
      return Const(0);
    }

    if (constantMaxValue == null) {
      // for now, this is hard to handle, so just always maybe overflow if
      // anything is incrementing
      return _anyIncrements;
    }

    Logic mayOverflow = Const(0);

    final maxValueBit = LogicValue.ofInferWidth(constantMaxValue).width - 1;

    final overflowDangerZoneStart = max(
      maxValueBit - log2Ceil(_incrementingInterfaces.length),
      0,
    );

    final inOverflowDangerZone = Logic(name: 'inOverflowDangerZone')
      ..gets(count.getRange(overflowDangerZoneStart).or());

    mayOverflow |= inOverflowDangerZone & _anyIncrements;

    Logic anyIntfInIncrDangerZone = Const(0);
    Logic anyIntfBigIncrement = Const(0);

    for (final intf in _incrementingInterfaces) {
      // if we're in the danger zone, and interface is enabled, and the amount
      // also reaches into the danger range

      if (intf.width <= overflowDangerZoneStart) {
        // if it's too short, don't worry about it
        continue;
      }

      var intfInDangerZone = intf.amount
          .getRange(
            overflowDangerZoneStart,
            min(intf.width, width),
          )
          .or();

      var intfBigIncrement = maxValueBit >= intf.width
          ? Const(0)
          : intf.amount.getRange(maxValueBit).or();

      if (intf.hasEnable) {
        intfInDangerZone &= intf.enable!;
        intfBigIncrement &= intf.enable!;
      }

      anyIntfInIncrDangerZone |= intfInDangerZone;
      anyIntfBigIncrement |= intfBigIncrement;
    }

    // if *any* interface is incrementing at all and upper-most bit(s) is 1,
    // then we may overflow
    Logic anyIntfIncrementing = Const(0);
    for (final intf in _incrementingInterfaces) {
      var intfIsIncrementing = intf.amount.or();
      if (intf.hasEnable) {
        intfIsIncrementing &= intf.enable!;
      }

      anyIntfIncrementing |= intfIsIncrementing;
    }
    final topMayOverflow =
        anyIntfIncrementing & count.getRange(maxValueBit).or();

    mayOverflow |= topMayOverflow;

    mayOverflow |= anyIntfInIncrDangerZone;

    mayOverflow |= anyIntfBigIncrement;

    return mayOverflow;
  }

  /// High if the counter may underflow.
  @visibleForTesting
  late final Logic mayUnderflow = Logic(name: 'mayUnderflow')
    ..gets(_calculateMayUnderflow());

  Logic _calculateMayUnderflow() {
    if (saturates) {
      // if this is a saturating counter, we will never wrap-around
      return Const(0);
    }

    if (_decrementingInterfaces.isEmpty) {
      // if we never decrement, no chance of underflow
      return Const(0);
    }

    if (constantMinValue == null) {
      // for now, this is hard to handle, so just always maybe underflow if
      // anything is decrementing
      return _anyDecrements;
    }

    Logic mayUnderflow = Const(0);

    final minValueBit =
        max(0, LogicValue.ofInferWidth(constantMinValue).width - 1);

    // if we're close enough to the minimum value (as judged by upper bits being
    // 0), and we are decrementing by a sufficiently large number (as judged by
    // enough lower bits of decr interfaces), then we may underflow

    final dangerRange = log2Ceil(_decrementingInterfaces.length + 1);
    final underflowDangerBit = minValueBit + dangerRange;
    final inUnderflowDangerZone = Logic(name: 'inUnderflowDangerZone')
      ..gets(underflowDangerBit >= count.width
          ? Const(1)
          : ~count.getRange(underflowDangerBit).or());

    mayUnderflow |= inUnderflowDangerZone & _anyDecrements;

    Logic anyIntfInDangerZone = Const(0);
    for (final intf in _decrementingInterfaces) {
      if (intf.width <= underflowDangerBit) {
        // if it's too short, don't worry about it
        continue;
      }

      var intfInDangerZone = intf.amount.getRange(underflowDangerBit).or();

      if (intf.hasEnable) {
        intfInDangerZone &= intf.enable!;
      }

      anyIntfInDangerZone |= intfInDangerZone;
    }

    return mayUnderflow | anyIntfInDangerZone;
  }

  /// High if the counter [mayUnderflow] or [mayOverflow].
  late final _mayWrap = Logic(name: 'mayWrap')
    ..gets(mayUnderflow | mayOverflow);

  /// Enable for the clock gate for the upper portion of the counter.
  late final _lowerEnable = Logic(name: 'lowerEnable')
    ..gets(_calculateLowerEnable());

  Logic _calculateLowerEnable() {
    Logic lowerEnable = Const(0); // default, not enabled

    // if any interface is enabled and has any 1's in the lower bits, enable
    for (final intf in interfaces) {
      var intfHasLowerBits =
          intf.amount.getRange(0, min(clkGatePartitionIndex, intf.width)).or();

      if (intf.hasEnable) {
        intfHasLowerBits &= intf.enable!;
      }

      lowerEnable |= intfHasLowerBits;
    }

    lowerEnable |= _mayWrap;

    if (saturates) {
      lowerEnable &= ~_stableSaturated;
    }

    lowerEnable |= _unstableValue;

    // always enable during restart
    if (restart != null) {
      lowerEnable |= restart!;
    }

    return lowerEnable;
  }

  /// High if we're in a stable saturation
  late final _stableSaturated = Logic(name: 'stableSaturated')
    ..gets(saturates
        ? (equalsMin & ~_anyIncrements) | (equalsMax & ~_anyDecrements)
        : Const(0));

  late final _anyDecrements = Logic(name: 'anyDecrements')
    ..gets(_decrementingInterfaces.isEmpty
        ? Const(0)
        : _decrementingInterfaces
            .map((intf) => intf.amount.or() & (intf.enable ?? Const(1)))
            .toList()
            .swizzle()
            .or());

  late final _anyIncrements = Logic(name: 'anyIncrements')
    ..gets(_incrementingInterfaces.isEmpty
        ? Const(0)
        : _incrementingInterfaces
            .map((intf) => intf.amount.or() & (intf.enable ?? Const(1)))
            .toList()
            .swizzle()
            .or());

  /// Enable for the clock gate for the upper portion of the counter.
  late final _upperEnable = Logic(name: 'upperEnable')
    ..gets(_calculateUpperEnable());

  Logic _calculateUpperEnable() {
    Logic upperEnable = Const(0); // default, not enabled

    // if any interface is enabled and has any 1's in the upper bits, enable
    for (final intf in interfaces) {
      if (clkGatePartitionIndex >= intf.width) {
        // if the interface doesnt even reach the partition index, then skip
        continue;
      }

      var intfHasUpperBits = intf.amount.getRange(clkGatePartitionIndex).or();

      if (intf.hasEnable) {
        intfHasUpperBits &= intf.enable!;
      }

      upperEnable |= intfHasUpperBits;
    }

    // the first bit of the total count that's "dangerous" for enabling clock
    final incrDangerZoneStart = max(
      0,
      clkGatePartitionIndex - log2Ceil(_incrementingInterfaces.length + 1),
    );

    final currentCountInIncrDangerZone =
        Logic(name: 'currentCountInIncrDangerZone')
          ..gets(count
              .getRange(
                min(incrDangerZoneStart, width),
                min(clkGatePartitionIndex, width),
              )
              .or());

    upperEnable |= currentCountInIncrDangerZone & _anyIncrements;

    Logic anyIntfInIncrDangerZone = Const(0);
    // for increments...
    for (final intf in _incrementingInterfaces) {
      // if we're in the danger zone, and interface is enabled, and the amount
      // also reaches into the danger range, then enable the upper gate

      if (intf.width <= incrDangerZoneStart) {
        // if it's too short, don't worry about it
        continue;
      }

      var intfInDangerZone = intf.amount
          .getRange(
            incrDangerZoneStart,
            min(clkGatePartitionIndex, intf.width),
          )
          .or();

      if (intf.hasEnable) {
        intfInDangerZone &= intf.enable!;
      }

      anyIntfInIncrDangerZone |= intfInDangerZone;
    }
    upperEnable |= anyIntfInIncrDangerZone;

    // for decrements...

    // if any decrement is "big enough" while the lower bits are "small enough',
    // then we have to enable the upper region since it can roll-over

    // let's just draw the line half way for now?
    final decrDangerZoneStart = clkGatePartitionIndex ~/ 2;
    final currentCountInDecrDangerZone =
        Logic(name: 'currentCountInDecrDangerZone')
          ..gets(~count
              .getRange(
                min(width - 1, decrDangerZoneStart),
                min(width, clkGatePartitionIndex),
              )
              .or());

    upperEnable |= currentCountInDecrDangerZone & _anyDecrements;

    Logic anyIntfEndangersDecr = Const(0);

    final decrDangerZoneStartIntf = max(
        0, decrDangerZoneStart - log2Ceil(_decrementingInterfaces.length + 1));
    for (final intf in _decrementingInterfaces) {
      if (intf.width <= decrDangerZoneStartIntf) {
        // if it's too short, don't worry about it
        continue;
      }

      var intfEndangersDecrZone = intf.amount
          .getRange(
            decrDangerZoneStartIntf,
            min(intf.width, clkGatePartitionIndex),
          )
          .or();

      if (intf.hasEnable) {
        intfEndangersDecrZone &= intf.enable!;
      }

      anyIntfEndangersDecr |= intfEndangersDecrZone;
    }

    upperEnable |= anyIntfEndangersDecr;

    upperEnable |= _mayWrap;

    if (saturates) {
      upperEnable &= ~_stableSaturated;
    }

    upperEnable |= _unstableValue;

    // always enable during restart
    if (restart != null) {
      upperEnable |= restart!;
    }

    return upperEnable;
  }

  /// The gated clock for the lower partition of the counter.
  @visibleForTesting
  @protected
  late final Logic lowerGatedClock;

  /// The gated clock for the upper partition of the counter.
  @visibleForTesting
  @protected
  late final Logic upperGatedClock;

  /// Whether the current value of the counter is not "stable" in that it's not
  /// legal according to the minimum and maximum values.
  ///
  /// Covers the scenario where reset value is less than the minimum value or
  /// greater than the maximum value. The first cycle after reset, we need to
  /// ungate the count.
  late final Logic _unstableValue = Logic(name: 'unstableValue')
    ..gets(
      (summer.underflowed & ~underflowed) | (summer.overflowed & ~overflowed),
    );

  /// Picks a partition index based on the interfaces provided.
  int _pickPartitionIndex() =>
      // simple implementation is just cut it in half
      width ~/ 2;

  @protected
  @override
  void buildFlops() {
    clkGatePartitionIndex =
        _providedClkGateParitionIndex ?? _pickPartitionIndex();

    if (clkGatePartitionIndex >= width || clkGatePartitionIndex < 0) {
      // just gate the whole thing together
      final clkGate = ClockGate(clk,
          enable: _lowerEnable | _upperEnable,
          reset: reset,
          controlIntf: _clockGateControlInterface);

      lowerGatedClock = clkGate.gatedClk;
      upperGatedClock = clkGate.gatedClk;

      count <=
          flop(
            clkGate.gatedClk,
            summer.sum,
            reset: reset,
            resetValue: initialValueLogic,
          );
    } else {
      final lowerClkGate = ClockGate(clk,
          enable: _lowerEnable,
          reset: reset,
          controlIntf: _clockGateControlInterface,
          name: 'lower_clock_gate');

      final upperClkGate = ClockGate(clk,
          enable: _upperEnable,
          reset: reset,
          controlIntf: _clockGateControlInterface,
          name: 'upper_clock_gate');

      final lowerCount = flop(
        lowerClkGate.gatedClk,
        summer.sum.getRange(0, clkGatePartitionIndex),
        reset: reset,
        resetValue: initialValueLogic.getRange(0, clkGatePartitionIndex),
      );

      final upperCount = flop(
        upperClkGate.gatedClk,
        summer.sum.getRange(clkGatePartitionIndex),
        reset: reset,
        resetValue: initialValueLogic.getRange(clkGatePartitionIndex),
      );

      lowerGatedClock = lowerClkGate.gatedClk;
      upperGatedClock = upperClkGate.gatedClk;

      count <= [upperCount, lowerCount].swizzle();
    }
  }
}
