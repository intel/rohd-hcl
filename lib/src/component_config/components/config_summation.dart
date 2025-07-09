// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_summation.dart
// Configurators for summation.
//
// 2024 September 6
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/summation/summation_base.dart';

/// A knob for a single sum interface.
class SumInterfaceKnob extends GroupOfKnobs {
  /// Whether the sum interface has an enable signal.
  ToggleConfigKnob hasEnableKnob = ToggleConfigKnob(value: false);

  /// Whether the sum interface has a fixed value.
  ToggleConfigKnob isFixedValueKnob = ToggleConfigKnob(value: false);

  /// The fixed value of the sum interface, only present when [isFixedValueKnob]
  /// is `true`.
  IntConfigKnob fixedValueKnob = IntConfigKnob(value: 1);

  /// The width of the sum interface.
  IntOptionalConfigKnob widthKnob = IntOptionalConfigKnob(value: 8);

  /// Whether the sum interface increments (vs. decrements).
  ToggleConfigKnob incrementsKnob = ToggleConfigKnob(value: true);

  /// Creates a new sum interface knob.
  SumInterfaceKnob() : super({}, name: 'Sum Interface');

  @override
  Map<String, ConfigKnob<dynamic>> get subKnobs => {
        'Has Enable': hasEnableKnob,
        'Is Fixed Value': isFixedValueKnob,
        if (isFixedValueKnob.value) 'Fixed Value': fixedValueKnob,
        'Width': widthKnob,
        'Increments': incrementsKnob,
      };
}

/// A configurator for a module like [SummationBase].
abstract class SummationConfigurator extends Configurator {
  /// The interface knobs.
  final ListOfKnobsKnob sumInterfaceKnobs = ListOfKnobsKnob(
    count: 1,
    generateKnob: (i) => SumInterfaceKnob(),
    name: 'Sum Interfaces',
  );

  /// The width.
  final IntOptionalConfigKnob widthKnob = IntOptionalConfigKnob(value: null);

  /// The minimum value.
  final IntOptionalConfigKnob minValueKnob = IntOptionalConfigKnob(value: 0);

  /// The maximum value.
  final IntOptionalConfigKnob maxValueKnob = IntOptionalConfigKnob(value: null);

  /// Whether the output saturates (vs. rolling over/under).
  final ToggleConfigKnob saturatesKnob = ToggleConfigKnob(value: false);

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Sum Interfaces': sumInterfaceKnobs,
        'Width': widthKnob,
        'Minimum Value': minValueKnob,
        'Maximum Value': maxValueKnob,
        'Saturates': saturatesKnob,
      };
}

/// A configurator for [Sum].
class SumConfigurator extends SummationConfigurator {
  /// The initial value.
  final IntConfigKnob initialValueKnob = IntConfigKnob(value: 0);

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        ...super.knobs,
        'Initial Value': initialValueKnob,
      };

  @override
  Module createModule() => Sum(
        sumInterfaceKnobs.knobs
            .map((e) => e as SumInterfaceKnob)
            .map((e) => SumInterface(
                  hasEnable: e.hasEnableKnob.value,
                  fixedAmount:
                      e.isFixedValueKnob.value ? e.fixedValueKnob.value : null,
                  width: e.widthKnob.value,
                  increments: e.incrementsKnob.value,
                ))
            .toList(),
        initialValue: initialValueKnob.value,
        width: widthKnob.value,
        minValue: minValueKnob.value,
        maxValue: maxValueKnob.value,
        saturates: saturatesKnob.value,
      );

  @override
  String get name => 'Sum';
}

/// A configurator for [Counter].
class CounterConfigurator extends SummationConfigurator {
  /// The reset value.
  final IntConfigKnob resetValueKnob = IntConfigKnob(value: 0);

  /// Whether to instantiate a [GatedCounter].
  final ToggleConfigKnob clockGatingKnob = ToggleConfigKnob(value: false);

  /// The clock gating partition index.
  final IntOptionalConfigKnob clockGatingPartitionIndexKnob =
      IntOptionalConfigKnob(value: null);

  /// The gate toggles knob.
  final ToggleConfigKnob gateTogglesKnob = ToggleConfigKnob(value: false);

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        ...super.knobs,
        'Reset Value': resetValueKnob,
        'Clock Gating': clockGatingKnob,
        if (clockGatingKnob.value) ...{
          'Clock Gating Partition Index': clockGatingPartitionIndexKnob,
          'Gate Toggles': gateTogglesKnob,
        },
      };

  @override
  Module createModule() {
    final sumIntfs = sumInterfaceKnobs.knobs
        .map((e) => e as SumInterfaceKnob)
        .map((e) => SumInterface(
              hasEnable: e.hasEnableKnob.value,
              fixedAmount:
                  e.isFixedValueKnob.value ? e.fixedValueKnob.value : null,
              width: e.widthKnob.value,
              increments: e.incrementsKnob.value,
            ))
        .toList();

    if (clockGatingKnob.value) {
      return GatedCounter(
        sumIntfs,
        resetValue: resetValueKnob.value,
        width: widthKnob.value,
        minValue: minValueKnob.value,
        maxValue: maxValueKnob.value,
        saturates: saturatesKnob.value,
        clk: Logic(),
        reset: Logic(),
        clkGatePartitionIndex: clockGatingPartitionIndexKnob.value,
        gateToggles: gateTogglesKnob.value,
      );
    } else {
      return Counter(
        sumIntfs,
        resetValue: resetValueKnob.value,
        width: widthKnob.value,
        minValue: minValueKnob.value,
        maxValue: maxValueKnob.value,
        saturates: saturatesKnob.value,
        clk: Logic(),
        reset: Logic(),
      );
    }
  }

  @override
  String get name => 'Counter';
}
