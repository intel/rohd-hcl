// Copyright (C) 2024 Intel Corporation
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
import 'package:rohd_hcl/rohd_hcl.dart';

class ClockGateControlInterface extends PairInterface {
  final bool hasEnableOverride;
  Logic? get enableOverride => tryPort('en_override');

  final bool isPresent;

  static Logic defaultGenerateGatedClock(
    ClockGateControlInterface intf,
    Logic clk,
    Logic enable,
  ) =>
      clk &
      ([
        enable,
        if (intf.hasEnableOverride) intf.enableOverride!,
      ].swizzle().or());

  final Logic Function(
    ClockGateControlInterface intf,
    Logic clk,
    Logic enable,
  ) gatedClockGenerator;

  ClockGateControlInterface({
    this.isPresent = true,
    this.hasEnableOverride = false,
    List<Port>? additionalPorts,
    this.gatedClockGenerator = defaultGenerateGatedClock,
  }) : super(portsFromProvider: [
          if (hasEnableOverride) Port('en_override'),
          ...?additionalPorts,
        ]);

  ClockGateControlInterface.clone(ClockGateControlInterface otherInterface,
      {bool? isPresent})
      : isPresent = isPresent ?? otherInterface.isPresent,
        hasEnableOverride = otherInterface.hasEnableOverride,
        gatedClockGenerator = otherInterface.gatedClockGenerator,
        super.clone(otherInterface);
}

/// A generic and configurable clock gating block.
class ClockGate extends Module {
  /// An internal cache for controlled signals to avoid duplicating them.
  final Map<Logic, Logic> _controlledCache = {};

  /// Returns a (potentially) delayed (by one cycle) version of [original] if
  /// [delayControlledSignals] is true and the clock gating [isPresent]. This is
  /// the signal that should be used as inputs to logic depending on the
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
  Logic addInput(String name, Logic x, {int width = 1}) {
    _uniquifier.getUniqueName(initialName: name, reserved: true);
    return super.addInput(name, x, width: width);
  }

  @override
  Logic addOutput(String name, {int width = 1}) {
    _uniquifier.getUniqueName(initialName: name, reserved: true);
    return super.addOutput(name, width: width);
  }

  /// The gated clock output.
  late final Logic gatedClk;

  /// Reset for all internal logic.
  late final Logic _reset;

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
      // `isPresent` as true, so if this is null then there is no clock gating
      false;

  /// Indicates whether the controlled signals are delayed by 1 cycle. If this
  /// is false, or clock gating is not [isPresent], then the [controlled]
  /// signals are not delayed.
  final bool delayControlledSignals;

  /// Constructs a clock gating block where [enable] controls whether the
  /// [gatedClk] is connected directly to the [freeClk] or is gated off.
  ///
  /// If [controlIntf] is provided, then the clock gating can be controlled
  /// externally (for example whether the clock gating [isPresent] or
  /// using an override signal to force clocks enabled). If [controlIntf] is not
  /// provided, then the clock gating is always present.
  ///
  /// If [delayControlledSignals] is true, then any signals that are
  /// [controlled] by the clock gating will be delayed by 1 cycle. This can be
  /// helpful for timing purposes to avoid ungating the clock on the same cycle
  /// as the signal is used.
  ///
  /// The [gatedClk] is automatically enabled during [reset] so that synchronous
  /// resets work properly, and the [enable] is extended for an appropriate
  /// duration to ensure proper capture of data.
  ClockGate(
    Logic freeClk, {
    required Logic enable,
    required Logic reset,
    ClockGateControlInterface? controlIntf,
    this.delayControlledSignals = true,
    super.name = 'clock_gate',
  }) {
    // if this clock gating is not intended to be present, then just do nothing
    if (!(controlIntf?.isPresent ?? true)) {
      _controlIntf = null;
      gatedClk = freeClk;
      return;
    }

    _freeClk = addInput('freeClk', freeClk);
    _enable = addInput('enable', enable);
    _reset = addInput('reset', reset);

    if (controlIntf == null) {
      // if we are not provided an interface, make our own to use with default
      // configuration
      _controlIntf = ClockGateControlInterface();
    } else {
      _controlIntf = ClockGateControlInterface.clone(controlIntf)
        ..pairConnectIO(this, controlIntf, PairRole.consumer);
    }

    gatedClk = addOutput('gatedClk');

    _buildLogic();
  }

  /// Build the internal logic for handling enabling the gated clock.
  void _buildLogic() {
    final internalEnable = _enable |

        // we want to enable the clock during reset so that synchronous resets
        // work properly
        _reset |
        ShiftRegister(
          _enable,
          clk: _freeClk,
          reset: _reset,

          resetValue: 1, // during reset, keep the clock enabled

          // always at least 1 cycle so we can caputure the last one, but also
          // an extra if there's a delay on the inputs relative to the enable
          depth: delayControlledSignals ? 2 : 1,
        ).stages.swizzle().or();

    gatedClk <=
        _controlIntf!
            .gatedClockGenerator(_controlIntf!, _freeClk, internalEnable);
  }
}
