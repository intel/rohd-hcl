// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_priority_arbiter.dart
// Configurator for a PriorityArbiter.
//
// 2023 December 5

import 'package:rohd/rohd.dart';
// ignore: implementation_imports
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [PriorityArbiter].
class PriorityArbiterConfigurator extends Configurator {
  /// A knob controlling the number of requests and grants.
  final IntConfigKnob numRequestKnob = IntConfigKnob(value: 4);

  @override
  final name = 'Priority Arbiter';

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = {
    'Number of Requestors': numRequestKnob,
  };

  @override
  Module createModule() {
    final reqs = List.generate(numRequestKnob.value, (i) => Logic());
    return PriorityArbiter(reqs);
  }

  @override
  // TODO: implement exampleTestVectors
  List<Vector> get exampleTestVectors => throw UnimplementedError();
}
