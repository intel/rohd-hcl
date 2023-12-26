// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_round_robin_arbiter.dart
// Configurator for a PriorityArbiter.
//
// 2023 December 26
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// The type of round-robin arbiter.
enum RoundRobinImplmentation {
  /// A [MaskRoundRobinArbiter].
  mask,

  /// A [RotateRoundRobinArbiter]
  rotate
}

/// A [Configurator] for [PriorityArbiter].
class RoundRobinArbiterConfigurator extends Configurator {
  /// A knob controlling the number of requests and grants.
  final IntConfigKnob numRequestKnob = IntConfigKnob(value: 8);

  /// A knob controlling the implementation.
  final ChoiceConfigKnob<RoundRobinImplmentation> implementationKnob =
      ChoiceConfigKnob(RoundRobinImplmentation.values,
          value: RoundRobinImplmentation.mask);

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
    switch (implementationKnob.value) {
      case RoundRobinImplmentation.mask:
        return MaskRoundRobinArbiter(reqs, clk: Logic(), reset: Logic());
      case RoundRobinImplmentation.rotate:
        return RotateRoundRobinArbiter(reqs, clk: Logic(), reset: Logic());
    }
  }
}
