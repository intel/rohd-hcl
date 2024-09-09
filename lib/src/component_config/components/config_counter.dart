// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_counter.dart
// Configurator for a Counter.
//
// 2024 September 6
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';

class SumInterfaceKnob extends GroupOfKnobs {
  ToggleConfigKnob hasEnableKnob = ToggleConfigKnob(value: false);

  ToggleConfigKnob isFixedValueKnob = ToggleConfigKnob(value: false);

  IntOptionalConfigKnob widthKnob = IntOptionalConfigKnob(value: 8);

  SumInterfaceKnob() : super({});

  @override
  Map<String, ConfigKnob<dynamic>> get subKnobs => {
        'Has Enable': hasEnableKnob,
        'Is Fixed Value': isFixedValueKnob,
        'Width': widthKnob,
      };
}

// class CounterConfigurator extends Configurator {}
