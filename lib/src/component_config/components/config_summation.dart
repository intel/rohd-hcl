// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_counter.dart
// Configurator for a Counter.
//
// 2024 September 6
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/module.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/component_config/component_config.dart';

class SumInterfaceKnob extends GroupOfKnobs {
  ToggleConfigKnob hasEnableKnob = ToggleConfigKnob(value: false);

  ToggleConfigKnob isFixedValueKnob = ToggleConfigKnob(value: false);
  IntConfigKnob fixedValueKnob = IntConfigKnob(value: 1);

  IntOptionalConfigKnob widthKnob = IntOptionalConfigKnob(value: 8);

  ToggleConfigKnob incrementsKnob = ToggleConfigKnob(value: true);

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

abstract class SummationConfigurator extends Configurator {
  final ListOfKnobsKnob sumInterfaceKnobs = ListOfKnobsKnob(
    count: 1,
    generateKnob: (i) => SumInterfaceKnob(),
    name: 'Sum Interfaces',
  );

  final IntOptionalConfigKnob widthKnob = IntOptionalConfigKnob(value: null);
  final IntOptionalConfigKnob minValueKnob = IntOptionalConfigKnob(value: 0);
  final IntOptionalConfigKnob maxValueKnob = IntOptionalConfigKnob(value: null);
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

class SumConfigurator extends SummationConfigurator {
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

class CounterConfigurator extends SummationConfigurator {
  final IntConfigKnob resetValueKnob = IntConfigKnob(value: 0);

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        ...super.knobs,
        'Reset Value': resetValueKnob,
      };

  @override
  Module createModule() => Counter(
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
        resetValue: resetValueKnob.value,
        width: widthKnob.value,
        minValue: minValueKnob.value,
        maxValue: maxValueKnob.value,
        saturates: saturatesKnob.value,
        clk: Logic(),
        reset: Logic(),
      );

  @override
  String get name => 'Counter';
}
