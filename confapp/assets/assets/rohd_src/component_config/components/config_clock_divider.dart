// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_clock_divider.dart
// Configurator for divided-rate clock enables.
//
// 2026 November 8
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Configures a clock-enable generator.
class ClockDividerConfigurator extends Configurator {
  /// Number of input-clock cycles per enable.
  final IntConfigKnob divisorKnob = PositiveIntConfigKnob(value: 2);

  @override
  ComponentCategory get category => ComponentCategory.clocking;

  @override
  String get subcategory => 'generation';

  @override
  String get name => 'Clock Enable Divider';

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {'Divisor': divisorKnob};

  @override
  Module createModule() => ClockDivider(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        divisor: divisorKnob.value,
      );
}
