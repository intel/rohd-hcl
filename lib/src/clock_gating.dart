// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// clock_gating.dart
// Clock gating.
//
// 2024 September 18
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
// ignore: implementation_imports
import 'package:rohd/src/utilities/uniquifier.dart';

/// An [Interface] for controlling [ClockGate]s.
class ClockGateControlInterface extends PairInterface {
  /// Whether an [enableOverride] is present on this interface.
  final bool hasEnableOverride;

  /// If asserted, then clocks will be enabled regardless of the `enable`
  /// signal.
  ///
  /// Presence is controlled by [hasEnableOverride].
  Logic? get enableOverride => tryPort('en_override');

  /// Indicates whether clock gating logic [isPresent] or not. If it is not,
  /// then no clock gating will occur and no clock gating logic will be
  /// generated.
  final bool isPresent;

  /// Capture the additional ports that are part of this interface, if any.
  late final List<Logic>? additionalPorts;

  /// A default implementation for clock gating, effectively just an AND of the
  /// clock and the enable signal, with an optional [enableOverride].
  static Logic defaultGenerateGatedClock(
    ClockGateControlInterface intf,
    Logic clk,
    Logic enable,
  ) =>
      clk &
      flop(
          ~clk,
          [
            enable,
            if (intf.hasEnableOverride) intf.enableOverride!,
          ].swizzle().or());

  /// A function that generates the gated clock signal based on the provided
  /// `intf`, `clk`, and `enable` signals.
  final Logic Function(
    ClockGateControlInterface intf,
    Logic clk,
    Logic enable,
  ) gatedClockGenerator;

  /// Constructs a [ClockGateControlInterface] with the provided arguments.
  ///
  /// If [isPresent] is `false`, then no clock gating will occur and no clock
  /// gating logic will be generated.
  ///
  /// If [hasEnableOverride] is `true`, then an additional [enableOverride] port
  /// will be generated.
  ///
  /// [additionalPorts] can optionally be added to this interface, which can be
  /// useful in conjunction with a custom [gatedClockGenerator]. As the
  /// interface is punched through hierarchies, any modules using this interface
  /// will automatically include the [additionalPorts] and use the custom
  /// [gatedClockGenerator] for clock gating logic.
  ClockGateControlInterface({
    this.isPresent = true,
    this.hasEnableOverride = false,
    this.additionalPorts,
    this.gatedClockGenerator = defaultGenerateGatedClock,
  }) : super(portsFromProvider: [
          if (hasEnableOverride) Logic.port('en_override'),
          ...?additionalPorts,
        ]);

  /// Creates a clone of [otherInterface] with the same configuration,
  /// including
  /// any `additionalPorts` and `gatedClockGenerator` function. This should be
  /// used to replicate interface configuration through hierarchies to carry
  /// configuration information.
  ///
  /// If [isPresent] is provided, then it will override the [isPresent] value
  /// from [otherInterface].
  ///
  /// If a [gatedClockGenerator] is provided, then it will override the
  /// [gatedClockGenerator] function from [otherInterface].
  @Deprecated('Use Instance-based `clone()` instead.')
  ClockGateControlInterface.clone(
    ClockGateControlInterface super.otherInterface, {
    bool? isPresent,
    Logic Function(
      ClockGateControlInterface intf,
      Logic clk,
      Logic enable,
    )? gatedClockGenerator,
  })  : hasEnableOverride = otherInterface.hasEnableOverride,
        isPresent = isPresent ?? otherInterface.isPresent,
        gatedClockGenerator =
            gatedClockGenerator ?? otherInterface.gatedClockGenerator,
        super.clone();

  /// Creates a clone of with the same configuration, including any
  /// `additionalPorts` and `gatedClockGenerator` function. This should be used
  /// to replicate interface configuration through hierarchies to carry
  /// configuration information.
  @override
  ClockGateControlInterface clone() => ClockGateControlInterface(
      isPresent: isPresent,
      hasEnableOverride: hasEnableOverride,
      additionalPorts: (additionalPorts != null)
          ? [for (final p in additionalPorts!) p.clone(name: p.name)]
          : null,
      gatedClockGenerator: gatedClockGenerator);
}

/// A generic and configurable clock gating block.
class ClockGate extends Module {
  /// An internal cache for controlled signals to avoid duplicating them.
  final Map<Logic, Logic> _controlledCache = {};

  /// Returns a (potentially) delayed (by one cycle) version of [original] if
  /// [delayControlledSignals] is `true` and the clock gating [isPresent]. This
  /// is the signal that should be used as inputs to logic depending on the
  /// [gatedClk].
  ///
  /// If a [resetValue] is provided, then the signal will be reset to that value
  /// when the clock gating is reset.
  Logic controlled(Logic original, {dynamic resetValue}) {
    if (!isPresent || !delayControlledSignals) {
      return original;
    }

    if (_controlledCache.containsKey(original)) {
      return _controlledCache[original]!;
    } else {
      final o = super.addOutput(
          _uniquifier.getUniqueName(initialName: '${original.name}_delayed'));

      _controlledCache[original] = o;

      o <=
          flop(
            _freeClk,
            reset: _reset,
            resetValue: resetValue,
            super.addInput(
              _uniquifier.getUniqueName(initialName: original.name),
              original,
              width: original.width,
            ),
          );

      return o;
    }
  }

  /// A uniquifier for ports to ensure that they are unique as they punch via
  /// [controlled].
  final _uniquifier = Uniquifier();

  // override the addInput and addOutput functions for uniquification purposes

  @override
  Logic addInput(String name, Logic source, {int width = 1}) {
    _uniquifier.getUniqueName(initialName: name, reserved: true);
    return super.addInput(name, source, width: width);
  }

  @override
  Logic addOutput(String name, {int width = 1}) {
    _uniquifier.getUniqueName(initialName: name, reserved: true);
    return super.addOutput(name, width: width);
  }

  /// The gated clock output.
  late final Logic gatedClk;

  /// Reset for all internal logic.
  late final Logic? _reset;

  /// The enable signal provided as an input.
  late final Logic _enable;

  /// The free clock signal provided as an input.
  late final Logic _freeClk;

  /// The control interface for the clock gating, if provided.
  late final ClockGateControlInterface? _controlIntf;

  /// Indicates whether the clock gating is present. If it is not present, then
  /// the [gatedClk] is directly connected to the free clock and the
  /// [controlled] signals are not delayed.
  bool get isPresent =>
      _controlIntf?.isPresent ??
      // if no interface is provided, then _controlInterface is initialized with
      // `isPresent` as `true`, so if this is null then there is no clock
      // gating.
      false;

  /// Indicates whether the controlled signals are delayed by 1 cycle. If this
  /// is `false`, or clock gating is not [isPresent], then the [controlled]
  /// signals are not delayed.
  final bool delayControlledSignals;

  /// Constructs a clock gating block where [enable] controls whether the
  /// [gatedClk] is connected directly to the [freeClk] or is gated off.
  ///
  /// If [controlIntf] is provided, then the clock gating can be controlled
  /// externally (for example whether the clock gating [isPresent] or using an
  /// override signal to force clocks enabled). If [controlIntf] is not
  /// provided, then the clock gating is always present.
  ///
  /// If [delayControlledSignals] is `true`, then any signals that are
  /// [controlled] by the clock gating will be delayed by 1 cycle. This can be
  /// helpful for timing purposes to avoid ungating the clock on the same cycle
  /// as the signal is used. Using the [controlled] signals helps turn on or off
  /// the delay across all applicable signals via a single switch:
  /// [delayControlledSignals].
  ///
  /// The [gatedClk] is automatically enabled during [reset] (if provided) so
  /// that synchronous resets work properly, and the [enable] is extended for an
  /// appropriate duration (if [delayControlledSignals]) to ensure proper
  /// capture of data.
  ClockGate(Logic freeClk,
      {required Logic enable,
      Logic? reset,
      ClockGateControlInterface? controlIntf,
      this.delayControlledSignals = false,
      super.name = 'clock_gate',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(definitionName: definitionName ?? 'ClockGate') {
    // if this clock gating is not intended to be present, then just do nothing
    if (!(controlIntf?.isPresent ?? true)) {
      _controlIntf = null;
      gatedClk = freeClk;
      return;
    }

    _freeClk = addInput('freeClk', freeClk);
    _enable = addInput('enable', enable);

    if (reset != null) {
      _reset = addInput('reset', reset);
    } else {
      _reset = null;
    }

    if (controlIntf == null) {
      // if we are not provided an interface, make our own to use with default
      // configuration
      _controlIntf = ClockGateControlInterface();
    } else {
      _controlIntf = controlIntf.clone()
        ..pairConnectIO(this, controlIntf, PairRole.consumer);
    }

    gatedClk = addOutput('gatedClk');

    _buildLogic();
  }

  /// Build the internal logic for handling enabling the gated clock.
  void _buildLogic() {
    var internalEnable = _enable;

    if (_reset != null) {
      // we want to enable the clock during reset so that synchronous resets
      // work properly
      internalEnable |= _reset!;
    }

    if (delayControlledSignals) {
      // extra if there's a delay on the inputs relative to the enable
      internalEnable |= flop(
        _freeClk,
        _enable,
        reset: _reset,
        resetValue: 1, // during reset, keep the clock enabled
      );
    }

    gatedClk <=
        _controlIntf!
            .gatedClockGenerator(_controlIntf!, _freeClk, internalEnable);
  }
}
