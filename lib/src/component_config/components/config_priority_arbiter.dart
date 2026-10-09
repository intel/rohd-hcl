// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_priority_arbiter.dart
// Configurator for a PriorityArbiter.
//
// 2023 December 5

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [PriorityArbiter].
class PriorityArbiterConfigurator extends Configurator {
  @override
  ComponentCategory get category => ComponentCategory.flowControl;

  @override
  String get subcategory => 'arbitration';

  /// A knob controlling the number of requests and grants.
  final IntConfigKnob numRequestKnob = IntConfigKnob(value: 8);

  @override
  final String name = 'Priority Arbiter';

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Number of Requestors': numRequestKnob,
  });

  @override
  Module createModule() {
    final reqs = List.generate(numRequestKnob.value, (i) => Logic());
    return PriorityArbiter(reqs, definitionName: 'PriorityArbiter');
  }
}
