// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_round_robin_arbiter.dart
// Configurator for a round-robin arbiter.
//
// 2023 December 26
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [PriorityArbiter].
class RoundRobinArbiterConfigurator extends Configurator {
  /// A knob controlling the number of requests and grants.
  final IntConfigKnob numRequestKnob = IntConfigKnob(value: 4);

  /// A knob controlling the implementation.
  final ChoiceConfigKnob<Type> implementationKnob = ChoiceConfigKnob(
      [MaskRoundRobinArbiter, RotateRoundRobinArbiter],
      value: MaskRoundRobinArbiter);

  @override
  final String name = 'Round Robin Arbiter';

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Number of Requestors': numRequestKnob,
    'Implementation': implementationKnob,
  });

  @override
  Module createModule() {
    final reqs = List.generate(numRequestKnob.value, (i) => Logic());

    if (implementationKnob.value == MaskRoundRobinArbiter) {
      return MaskRoundRobinArbiter(reqs,
          clk: Logic(),
          reset: Logic(),
          definitionName: 'MaskRoundRobinArbiter');
    } else if (implementationKnob.value == RotateRoundRobinArbiter) {
      return RotateRoundRobinArbiter(reqs,
          clk: Logic(),
          reset: Logic(),
          definitionName: 'RotateRoundRobinArbiter');
    }

    throw RohdHclException('Unknown round robin type.');
  }
}
